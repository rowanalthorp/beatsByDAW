extends Button
## the toolbar's Record button: records the microphone onto the selected audio track, press again to stop

var cache_folder := "user://recordings/" # user:// since res:// is read-only once the project is exported, same spot the instrument renders go
var active := false

var record_effect: AudioEffectRecord
var mic_player: AudioStreamPlayer
var recording_track: TrackData
var recording_clip: AudioClipData
var recording_started_at_usec := 0
var before_record: Dictionary # song before recording, so the take is one undo step
var message_dialog: AcceptDialog
var default_modulate: Color


func _ready() -> void:
	default_modulate = self_modulate
	tooltip_text = "Record microphone"
	message_dialog = AcceptDialog.new()
	message_dialog.title = "Cannot Record"
	add_child(message_dialog)

	pressed.connect(_on_pressed)
	Transport.playing_changed.connect(_on_transport_playing_changed)

	var bus_idx := AudioServer.get_bus_index("Record")
	if bus_idx == -1:
		bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, "Record")
	AudioServer.set_bus_mute(bus_idx, true)

	for effect_index in AudioServer.get_bus_effect_count(bus_idx):
		record_effect = AudioServer.get_bus_effect(bus_idx, effect_index) as AudioEffectRecord
		if record_effect != null:
			break
	if record_effect == null:
		record_effect = AudioEffectRecord.new()
		AudioServer.add_bus_effect(bus_idx, record_effect)
	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "Record"
	add_child(mic_player)
	mic_player.play()


func _process(_delta: float) -> void:
	if active and recording_clip != null:
		recording_clip.length = maxf(
			float(Time.get_ticks_usec() - recording_started_at_usec) / 1_000_000.0,
			0.01
		) # yeah this math thank lord for AI here yo


func _on_pressed() -> void:
	if active:
		_stop_recording()
		return

	before_record = Session.snapshot()
	var track: TrackData = Session.selected_track
	if track == null:
		# make_track so the new track and the take are one undo step
		track = Session.make_track(TrackData.Kind.AUDIO)
		Session.project.add_track(track)
		Session.selected_track = track
	if track.kind != TrackData.Kind.AUDIO:
		message_dialog.dialog_text = "Yo, just a heads up! Select an audio track to record microphone audio. Ty"
		message_dialog.popup_centered()
		return

	recording_track = track
	recording_clip = AudioClipData.new()
	recording_clip.name = "Recording"
	recording_clip.start = Transport.position
	recording_clip.length = 0.01
	recording_started_at_usec = Time.get_ticks_usec()
	recording_track.add_clip(recording_clip)
	Session.selected_clip = recording_clip
	record_effect.set_recording_active(true)
	if not record_effect.is_recording_active():
		_discard_recording_clip()
		push_error("Could not start microphone recording.")
		return

	active = true
	Transport.play()
	self_modulate = Color(1.0, 0.3, 0.3)
	tooltip_text = "Stop Recording"


func _on_transport_playing_changed(playing: bool) -> void:
	if not playing and active:
		_stop_recording()


func _stop_recording() -> void:
	active = false
	self_modulate = default_modulate
	tooltip_text = "Record microphone"
	Transport.pause()
	record_effect.set_recording_active(false)
	var recording := record_effect.get_recording()
	if recording == null:
		_discard_recording_clip()
		print("did not return a microphone recording.")
		return

	var directory_result := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(cache_folder)
	)
	if directory_result != OK:
		_discard_recording_clip()
		print("Could not create/get the microphone recording directory.")
		return

	var recording_path := cache_folder.path_join("take_%d_%d.wav" % [
		Time.get_unix_time_from_system(),
		recording_started_at_usec
	])
	var save_result := recording.save_to_wav(recording_path)
	if save_result != OK:
		_discard_recording_clip()
		print("Could not save microphone recording: %s" % error_string(save_result))
		return

	recording_clip.file_path = ProjectSettings.globalize_path(recording_path)
	recording_clip.name = "Microphone Recording"
	recording_clip.length = maxf(recording.get_length(), 0.01)
	Session.clear_under(recording_clip) # the take wins over whatever's under it, same as import
	Session.song_length_changed.emit()
	Session.save_undo_step("Record Audio", before_record)
	recording_clip = null
	recording_track = null


func _discard_recording_clip() -> void:
	if recording_track != null and recording_clip != null:
		recording_track.remove_clip(recording_clip)
	if Session.selected_clip == recording_clip:
		Session.selected_clip = null
	recording_clip = null
	recording_track = null
	# a failed take can still leave a new track behind, so save that as a step
	Session.save_undo_step("Record Audio", before_record)
