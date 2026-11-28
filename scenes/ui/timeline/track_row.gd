class_name TrackRow
extends HBoxContainer
## one track: header controls on the left, its clips in the lane on the right

const CLIP_VIEW_SCENE := preload("res://scenes/ui/timeline/clip_view.tscn")

var track: TrackData
var _before_rename: Dictionary # song from when the name box got clicked, so a whole rename is one undo step


func _ready() -> void:
	# header controls write straight into the track
	%NameEdit.text_changed.connect(_on_name_changed)
	%NameEdit.text_submitted.connect(_on_name_submitted)
	%NameEdit.focus_entered.connect(_on_name_focus_entered)
	%NameEdit.focus_exited.connect(_on_name_focus_exited)
	%MuteButton.toggled.connect(_on_mute_toggled)
	%SoloButton.toggled.connect(_on_solo_toggled)
	%VolumeSlider.value_changed.connect(_on_volume_changed)
	%PanSlider.value_changed.connect(_on_pan_changed)
	%EffectsButton.pressed.connect(_on_effects_pressed)
	%DeleteButton.pressed.connect(_on_delete_pressed)
	%Lane.gui_input.connect(_on_lane_gui_input)

	# the selected track bar
	Session.selection_changed.connect(%Header.queue_redraw) # bar on/off
	%Header.draw.connect(_draw_selected_bar)


func setup(new_track: TrackData) -> void:
	track = new_track
	_show_settings()
	track.changed.connect(_show_settings) # undo can change these behind the controls' backs
	for clip: ClipData in track.clips:
		_add_clip_view(clip)
	track.clip_removed.connect(_on_clip_removed)
	track.clip_added.connect(_add_clip_view) # split, paste and duplicate (and later import) add clips to this track


func _add_clip_view(clip: ClipData) -> void:
	var view := CLIP_VIEW_SCENE.instantiate() as ClipView
	%Lane.add_child(view)
	view.setup(clip)


func _show_settings() -> void:
	# only when different, setting text moves the cursor to the start while typing
	if %NameEdit.text != track.name:
		%NameEdit.text = track.name
	# *_no_signal: show the value without firing the signal, so it isn't written straight back
	%MuteButton.set_pressed_no_signal(track.muted)
	%SoloButton.set_pressed_no_signal(track.solo)
	# the slider shows plain volume (1 = unchanged), the track keeps dB
	%VolumeSlider.set_value_no_signal(db_to_linear(track.volume_db))
	%PanSlider.set_value_no_signal(track.pan)


func _on_name_focus_entered() -> void:
	_before_rename = Session.snapshot()


func _on_name_focus_exited() -> void:
	Session.save_undo_step("Rename Track", _before_rename)
func _on_name_changed(new_text: String) -> void:
	track.name = new_text


## enter finishes renaming. dropping focus also turns the keyboard shortcuts back on
func _on_name_submitted(_text: String) -> void:
	%NameEdit.release_focus()


func _on_mute_toggled(on: bool) -> void:
	var before := Session.snapshot()
	track.muted = on
	Session.save_undo_step("Mute Track", before)


func _on_solo_toggled(on: bool) -> void:
	var before := Session.snapshot()
	track.solo = on
	Session.save_undo_step("Solo Track", before)


## the slider goes by plain volume instead of dB, since a dB slider spends most of its length on
## "barely audible". 1 is unchanged, 2 is about +6 dB, and 0 would be -inf dB so it stops at -60
## (the lowest TrackData allows)
func _on_volume_changed(value: float) -> void:
	var before := Session.snapshot()
	track.volume_db = maxf(linear_to_db(value), -60.0)
	Session.save_undo_step("Change Volume", before, true) # true = one step per slider drag


func _on_pan_changed(value: float) -> void:
	var before := Session.snapshot()
	track.pan = value
	Session.save_undo_step("Change Pan", before, true)


func _on_delete_pressed() -> void:
	Session.remove_track(track)


## clicking empty lane space deselects the clip, selects this track and moves the playhead there
## (clicks on a clip never get here, the clip eats them)
func _on_lane_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		# song time where you clicked. same math as clicking the ruler
		var at := Session.snap(Session.scroll_seconds + click.position.x / Session.pixels_per_second)
		# double-click on an instrument track makes an empty clip there, kinda like ableton
		if click.double_click and track.kind == TrackData.Kind.INSTRUMENT:
			Session.add_note_clip(track, at)
			return
		Session.selected_clip = null
		Session.selected_track = track
		Transport.seek(at) # move the playhead there, so paste knows where to go


## a clip was deleted off this track, so get rid of its block too
func _on_clip_removed(clip: ClipData) -> void:
	for view: ClipView in %Lane.get_children():
		if view.clip == clip:
			view.queue_free()
			return


func _on_effects_pressed() -> void:
	Session.request_effects(track)


## selected track gets a bar down the left of its header. Header's draw signal fires after it draws
## its panel, so this lands on top. same blue as the clips since that colour doesnt flip with the theme
func _draw_selected_bar() -> void:
	if Session.selected_track != track:
		return
	var accent: Color = (get_theme_stylebox(&"panel", &"ClipPanel") as StyleBoxFlat).bg_color
	%Header.draw_rect(Rect2(0, 0, 4, %Header.size.y), accent)
