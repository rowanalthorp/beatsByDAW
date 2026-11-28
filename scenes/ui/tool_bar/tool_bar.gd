extends HBoxContainer
## toolbar buttons. tthey call into Session and Transport, the toolbar

const PLAY_ICON := preload("res://assets/icons/tool_bar/play.svg")
const PAUSE_ICON := preload("res://assets/icons/tool_bar/pause.svg")


func _ready() -> void:
	%PlayPause.pressed.connect(Transport.toggle_play)
	%Stop.pressed.connect(Transport.stop)
	# seek.bind(0.0) just passes 0.0 to seek, so we dont need a new func just for it
	%ToStart.pressed.connect(Transport.seek.bind(0.0))
	%ToEnd.pressed.connect(_on_to_end_pressed)
	Transport.playing_changed.connect(_on_playing_changed) # swaps the play/pause icon

	%Split.pressed.connect(Session.split_selected)
	%Cut.pressed.connect(Session.cut_selected)
	%Copy.pressed.connect(Session.copy_selected)
	%Paste.pressed.connect(Session.paste)

	%Undo.pressed.connect(Session.undo)
	%Redo.pressed.connect(Session.redo)
	Session.history.version_changed.connect(_update_undo_buttons)

	%ZoomIn.pressed.connect(Session.zoom_in)
	%ZoomOut.pressed.connect(Session.zoom_out)
	%ZoomFit.pressed.connect(Session.zoom_to_fit)

	%ImportAudio.pressed.connect(Session.request_import)
	%AddTrack.get_popup().id_pressed.connect(_on_add_track_id_pressed)

	_update_undo_buttons()


## same idea as the Edit menu in main.gd: greyed out when there's nothing to undo/redo
func _update_undo_buttons() -> void:
	var history := Session.history
	%Undo.disabled = not history.has_undo()
	%Redo.disabled = not history.has_redo()
	%Undo.tooltip_text = "Undo " + history.get_current_action_name() if history.has_undo() else "Undo"
	%Redo.tooltip_text = "Redo " + history.get_action_name(history.get_current_action() + 1) if history.has_redo() else "Redo"


## item ids match TrackData.Kind: 0 = audio, 1 = instrument
func _on_add_track_id_pressed(id: int) -> void:
	Session.add_new_track(id as TrackData.Kind)


## jumps to the end of the last clip
func _on_to_end_pressed() -> void:
	Transport.seek(Session.project.get_length())


## one button for both: it shows what clicking it will do next
func _on_playing_changed(playing: bool) -> void:
	%PlayPause.icon = PAUSE_ICON if playing else PLAY_ICON
	%PlayPause.tooltip_text = "Pause" if playing else "Play"
