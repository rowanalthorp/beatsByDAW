extends VBoxContainer
## the track list: one TrackRow per track in the open project

const TRACK_ROW_SCENE := preload("res://ui/timeline/track_row.tscn")

var _project: ProjectData  # the project whose signals were connected to

func _ready() -> void:
	Session.project_changed.connect(_on_project_changed)
	_on_project_changed(Session.project)

## rebuilds every row and listens to the new projects track signals
func _on_project_changed(project: ProjectData) -> void:
	# if a project is "loaded" then, session is listening to THAT ProjectData signals.
	# what we do here is stop listening to the "old" project, so we arent accidentally
	# pinging that projects signals, and accidentally overwritting another project's
	# data when making changing in the "new" project
	if _project:
		_project.track_added.disconnect(_on_track_added)
		_project.track_removed.disconnect(_on_track_removed)
	# after we disconnect, we swap over to the new project and watch the new project's signals
	_project = project
	_project.track_added.connect(_on_track_added)
	_project.track_removed.connect(_on_track_removed)
	for row: Node in %TrackList.get_children():
		%TrackList.remove_child(row)  # out of the list now, so new rows get the right index
		row.queue_free()
	for i in project.tracks.size():
		_on_track_added(project.tracks[i], i)

func _on_track_added(track: TrackData, index: int) -> void:
	var row := TRACK_ROW_SCENE.instantiate() as TrackRow
	%TrackList.add_child(row)
	%TrackList.move_child(row, index)
	row.setup(track)

func _on_track_removed(track: TrackData) -> void:
	for row: TrackRow in %TrackList.get_children():
		if row.track == track:
			row.queue_free()
			return
