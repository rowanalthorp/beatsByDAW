class_name PianoRollWindow
extends Window
## Popup window with the piano roll editor and piano instrument.
## Play/stop transport and schedules notes on the synth.

var _stream_player: AudioStreamPlayer

var _playing := false
var _playhead := 0.0
var _clip: NoteClipData

# render and cache preview pitches instead of synthesizing live
var _pitch_cache: Dictionary = {}
var _preview_players: Dictionary = {}
const PREVIEW_SECONDS := 4.0

# the song's real project instead of a private one, 
# so the tempo matches the main window
var _project: ProjectData:
	get:
		return Session.project

@onready var _roll: PianoRoll = $VBox/Scroll/PianoRoll
@onready var _play_button: Button = $VBox/Toolbar/PlayButton
@onready var _bpm_spin: SpinBox = $VBox/Toolbar/BpmSpin
@onready var _clear_button: Button = $VBox/Toolbar/ClearButton
@onready var _instrument_picker: OptionButton = $VBox/Toolbar/InstrumentPicker
@onready var _transpose_spin: SpinBox = $VBox/TuneBar/TransposeSpin
@onready var _ref_pitch_spin: SpinBox = $VBox/TuneBar/RefPitchSpin
@onready var _key_picker: OptionButton = $VBox/TuneBar/KeyPicker
@onready var _scale_picker: OptionButton = $VBox/TuneBar/ScalePicker

func _mark_clip_dirty() -> void:
	if _clip != null:
		_clip.notes_dirty = true

func _ready() -> void:
	close_requested.connect(_on_close_requested)

	_roll.notes_changed.connect(_mark_clip_dirty)

	_instrument_picker.add_item("Piano")
	_instrument_picker.add_item("Guitar")
	_instrument_picker.add_item("Drums")
	_instrument_picker.item_selected.connect(_on_instrument_selected)
	_transpose_spin.value_changed.connect(_on_tuning_changed)
	_ref_pitch_spin.value_changed.connect(_on_tuning_changed)

	for key_name in ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]:
		_key_picker.add_item(key_name)
	_key_picker.item_selected.connect(_on_key_selected)
	_scale_picker.add_item("None")
	_scale_picker.add_item("Major")
	_scale_picker.add_item("Minor")
	_scale_picker.item_selected.connect(_on_scale_selected)

	# Rendered playback
	_stream_player = AudioStreamPlayer.new()
	add_child(_stream_player)


	_roll.preview_note_on.connect(_preview_note_on)
	_roll.preview_note_off.connect(_preview_note_off)
	_play_button.pressed.connect(_toggle_play)
	_clear_button.pressed.connect(_roll.clear_notes)

	_roll.beats_per_bar = _project.beats_per_bar
	_bpm_spin.value = _project.bpm
	_bpm_spin.value_changed.connect(_on_bpm_changed)


## tempo changes how many beats the clip's seconds cover, so the usable region moves with it
func _on_bpm_changed(v: float) -> void:
	_project.bpm = v
	if _clip != null:
		_roll.usable_beats = _clip.length / (60.0 / v)
		_roll.bars = maxi(1, ceili(_roll.usable_beats / _roll.beats_per_bar))
		_roll.queue_redraw()


func _toggle_play() -> void:
	_playing = not _playing
	_play_button.text = "Stop" if _playing else "Play"
	if _playing:
		var pattern_beats := float(_roll.bars * _roll.beats_per_bar)
		var seconds_per_beat := 60.0 / _project.bpm
		var instrument := _clip.instrument if _clip != null else "piano"
		var transpose: int = _clip.transpose if _clip != null else 0
		var ref_pitch: float = _clip.ref_pitch if _clip != null else 440.0
		var wav := NoteRenderer.render_pattern(_roll.notes, pattern_beats, _project.bpm, instrument, transpose, ref_pitch)
		
		if _clip != null and _clip.notes_dirty:
			DirAccess.make_dir_recursive_absolute("user://renders")
			var path := "user://renders/%d.wav" % _clip.get_instance_id()
			if wav.save_to_wav(path) == OK:
				_clip.wav_path = ProjectSettings.globalize_path(path)
				_clip.notes_dirty = false
		
		# only loop the pattern end not the buffer, 
		# so release doesn't add a gap to each repetition
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = roundi(pattern_beats * seconds_per_beat * wav.mix_rate)
		_stream_player.stream = wav
		_stream_player.play()
	else:
		_stream_player.stop()
	_playhead = 0.0
	_roll.show_playhead = _playing
	_roll.queue_redraw()

func _on_close_requested() -> void:
	if _playing:
		_toggle_play()
	for player in _preview_players.values():
		player.stop()
	hide()


func _process(_delta: float) -> void:
	if not _playing:
		return
	_playhead = _stream_player.get_playback_position() / (60.0 / _project.bpm)
	_roll.playhead_beat = _playhead
	_roll.queue_redraw()


## opens the window editing this clip's notes. the roll gets the clip's own notes array (same array, not a copy),
## so every note placed, moved or deleted is saved straight into the clip
func open_clip(clip: NoteClipData) -> void:
	_clip = clip
	_roll.drum_mode = clip.instrument == "drums"
	_instrument_picker.select(["piano", "guitar", "drums"].find(clip.instrument))
	_transpose_spin.set_value_no_signal(clip.transpose)
	_ref_pitch_spin.set_value_no_signal(clip.ref_pitch)
	_key_picker.select(clampi(clip.scale_root, 0, 11))
	_scale_picker.select({"none": 0, "major": 1, "minor": 2}.get(clip.scale_type, 0))
	_roll.scale_root = clip.scale_root
	_roll.scale_type = clip.scale_type
	_update_tuning_enabled()
	if _playing:
		_toggle_play()
	title = "Piano Roll - " + clip.name
	_roll.notes = clip.notes
	_roll.beats_per_bar = _project.beats_per_bar
	# enough bars to cover the whole clip. seconds per bar = 60 / bpm * beats per bar
	var bar_seconds := 60.0 / _project.bpm * _project.beats_per_bar
	_roll.bars = ceili(clip.length / bar_seconds)
	# the grid fills whatever space it gets, so the clip's real length is what bounds notes
	_roll.usable_beats = clip.length / (60.0 / _project.bpm)
	_bpm_spin.set_value_no_signal(_project.bpm) # tempo may have changed in the bottom bar since last open
	_roll.queue_redraw()
	# size the window to fit the toolbars and the roll's actual size, so theres no empty
	# grey past the last bar or below the grid
	var toolbar_width: float = maxf(
		$VBox/Toolbar.get_combined_minimum_size().x,
		$VBox/TuneBar.get_combined_minimum_size().x)
	var chrome_h: float = ($VBox/Toolbar.get_combined_minimum_size().y
		+ $VBox/TuneBar.get_combined_minimum_size().y + 8.0)
	var roll_width := _roll.custom_minimum_size.x + 16.0 # + room for the vertical scroll bar
	var roll_height := _roll.custom_minimum_size.y + 16.0 # + room for the horizontal scroll bar
	var wanted := Vector2i(int(maxf(toolbar_width, roll_width)), int(minf(chrome_h + roll_height, 660.0)))
	# clamped version shrinks it to at most 85% of the main window if it doesnt fit,
	# so the title bar stays on screen instead of popping out the top
	popup_centered_clamped(wanted, 0.85)

func _preview_note_on(pitch: int, velocity: float = 1.0) -> void:
	var instrument: String = _clip.instrument if _clip != null else "piano"
	var transpose: int = _clip.transpose if _clip != null else 0
	var ref_pitch: float = _clip.ref_pitch if _clip != null else 440.0
	var cache_key := "%s:%d" % [instrument, pitch]
	if not _pitch_cache.has(cache_key):
		_pitch_cache[cache_key] = NoteRenderer.render_note(pitch, 1.0, PREVIEW_SECONDS, instrument, transpose, ref_pitch)
	if not _preview_players.has(pitch):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_preview_players[pitch] = player
	var player: AudioStreamPlayer = _preview_players[pitch]
	player.stream = _pitch_cache[cache_key]
	player.volume_db = linear_to_db(clampf(velocity, 0.0001, 1.0))
	player.play()

func _preview_note_off(pitch: int) -> void:
	if _preview_players.has(pitch):
		_preview_players[pitch].stop()

func _on_instrument_selected(index: int) -> void:
	if _clip == null:
		return
	if _playing:
		_toggle_play()
	for player in _preview_players.values():
		player.stop()
	_clip.instrument = ["piano", "guitar", "drums"][index]
	_roll.drum_mode = _clip.instrument == "drums"
	_update_tuning_enabled()
	_mark_clip_dirty()

## drums pick voices by pitch, not frequency
func _update_tuning_enabled() -> void:
	var pitched := _clip != null and _clip.instrument != "drums"
	_transpose_spin.editable = pitched
	_ref_pitch_spin.editable = pitched
	_key_picker.disabled = not pitched
	_scale_picker.disabled = not pitched

## edit-time only. the scale constrains placement, it doesn't change the stored notes
func _on_key_selected(index: int) -> void:
	if _clip == null:
		return
	_clip.scale_root = index
	_roll.scale_root = index
	_roll.queue_redraw()

func _on_scale_selected(index: int) -> void:
	if _clip == null:
		return
	_clip.scale_type = ["none", "major", "minor"][index]
	_roll.scale_type = _clip.scale_type

## tuning changed, cached previews and the exported wav are stale now
func _on_tuning_changed(_value: float) -> void:
	if _clip == null:
		return
	if _playing:
		_toggle_play()
	for player in _preview_players.values():
		player.stop()
	_pitch_cache.clear()
	_clip.transpose = int(_transpose_spin.value)
	_clip.ref_pitch = _ref_pitch_spin.value
	_mark_clip_dirty()
