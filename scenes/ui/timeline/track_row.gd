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
	# make sure the values are changeging succesfully
	#track.changed.connect(func() -> void: print(track.name, " | mute ", track.muted, " solo ", track.solo, " vol ", track.volume_db, " pan ", track.pan))

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
