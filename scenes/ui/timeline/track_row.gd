class_name TrackRow
extends HBoxContainer
## one track: header controls on the left, its clips in the lane on the right

const CLIP_VIEW_SCENE := preload("res://scenes/ui/timeline/clip_view.tscn")

var track: TrackData


func _ready() -> void:
	%NameEdit.text_changed.connect(_on_name_changed)
	%NameEdit.text_submitted.connect(_on_name_submitted)
	%MuteButton.toggled.connect(_on_mute_toggled)
	%SoloButton.toggled.connect(_on_solo_toggled)
	%VolumeSlider.value_changed.connect(_on_volume_changed)
	%PanSlider.value_changed.connect(_on_pan_changed)
	%DeleteButton.pressed.connect(_on_delete_pressed)
	%Lane.gui_input.connect(_on_lane_gui_input)
	%EffectsButton.pressed.connect(_on_effects_pressed)
	Session.selection_changed.connect(%Header.queue_redraw) # bar on/off
	%Header.draw.connect(_draw_selected_bar)


func setup(new_track: TrackData) -> void:
	track = new_track
	%NameEdit.text = track.name
	# *_no_signal: show the value without firing the signal, so it isn't written straight back
	%MuteButton.set_pressed_no_signal(track.muted)
	%SoloButton.set_pressed_no_signal(track.solo)
	%VolumeSlider.set_value_no_signal(track.volume_db)
	%PanSlider.set_value_no_signal(track.pan)
	for clip: ClipData in track.clips:
		_add_clip_view(clip)
	track.clip_removed.connect(_on_clip_removed)
	track.clip_added.connect(_add_clip_view) # split, paste and duplicate (and later import) add clips to this track
	# make sure the values are changeging succesfully
	#track.changed.connect(func() -> void: print(track.name, " | mute ", track.muted, " solo ", track.solo, " vol ", track.volume_db, " pan ", track.pan))
	%RecordButton.visible = track.kind == TrackData.Kind.AUDIO

func _add_clip_view(clip: ClipData) -> void:
	var view := CLIP_VIEW_SCENE.instantiate() as ClipView
	%Lane.add_child(view)
	view.setup(clip)


func _on_name_changed(new_text: String) -> void:
	track.name = new_text


## enter finishes renaming. dropping focus also turns the keyboard shortcuts back on
func _on_name_submitted(_text: String) -> void:
	%NameEdit.release_focus()


func _on_mute_toggled(on: bool) -> void:
	track.muted = on


func _on_solo_toggled(on: bool) -> void:
	track.solo = on


func _on_volume_changed(value: float) -> void:
	track.volume_db = value


func _on_pan_changed(value: float) -> void:
	track.pan = value


func _on_delete_pressed() -> void:
	Session.project.remove_track(track)


## clicking empty lane space deselects the clip, selects this track and moves the playhead there
## (clicks on a clip never get here, the clip eats them)
func _on_lane_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		Session.selected_clip = null
		Session.selected_track = track
		# move the playhead to where you clicked, so paste knows where to go. same math as clicking the ruler
		Transport.seek(Session.snap(Session.scroll_seconds + click.position.x / Session.pixels_per_second))


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
