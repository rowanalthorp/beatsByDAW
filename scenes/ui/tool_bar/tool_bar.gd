extends HBoxContainer
## toolbar buttons. they call into Session, the toolbar keeps no state itself

func _ready() -> void:
	var add_track_menu: PopupMenu = %AddTrack.get_popup()
	add_track_menu.id_pressed.connect(_on_add_track_id_pressed)

## item ids match TrackData.Kind: 0 = audio, 1 = instrument.
func _on_add_track_id_pressed(id: int) -> void:
	Session.add_new_track(id as TrackData.Kind)
