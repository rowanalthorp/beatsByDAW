extends HBoxContainer
## toolbar buttons. they call into Session, the toolbar keeps no state itself

const PLAY_ICON := preload("res://assets/icons/tool_bar/play.svg")
const PAUSE_ICON := preload("res://assets/icons/tool_bar/pause.svg")


func _ready() -> void:
	
	var add_track_menu: PopupMenu = %AddTrack.get_popup()
	add_track_menu.id_pressed.connect(_on_add_track_id_pressed)
	%PlayPause.pressed.connect(Transport.toggle_play)
	%Stop.pressed.connect(Transport.stop)
	# seek.bind(0.0) just passess 0.0 to seek, so we dont need a new func just for it
	%ToStart.pressed.connect(Transport.seek.bind(0.0))
	%ToEnd.pressed.connect(_on_to_end_pressed)
	Transport.playing_changed.connect(_on_playing_changed)
	%ZoomIn.pressed.connect(Session.zoom_in)
	%ZoomOut.pressed.connect(Session.zoom_out)
	%ZoomFit.pressed.connect(Session.zoom_to_fit)


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
