extends VBoxContainer
## the track list: one TrackRow per track in the open project

const TRACK_ROW_SCENE := preload("res://ui/timeline/track_row.tscn")

func _ready() -> void:
	Session.project_changed.connect(_on_project_changed)
	_on_project_changed(Session.project)

## rebuilds every row. runs when a project is opened (File > New/Open later)
func _on_project_changed(project: ProjectData) -> void:
	for row: Node in %TrackList.get_children():
		row.queue_free()
	for track: TrackData in project.tracks:
		var row := TRACK_ROW_SCENE.instantiate() as TrackRow
		%TrackList.add_child(row)
		row.setup(track)
