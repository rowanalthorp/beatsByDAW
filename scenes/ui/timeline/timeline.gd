extends VBoxContainer
## the track list: one TrackRow per track in the open project

const TRACK_ROW_SCENE := preload("res://scenes/ui/timeline/track_row.tscn")
const HEADER_WIDTH := 200.0 # track header / HeaderSpacer width, lanes start after it

var _project: ProjectData # the project whose signals were connected to
var _lane_start: float # x where the lanes begin: header width + the HBox gap after it


func _ready() -> void:
	# rows are HBoxContainers, so the theme puts a gap between the header and the lane
	# it's a gap of 4 while writing this, but in case anything changes I just get the number from the theme instead of hardcoding
	_lane_start = HEADER_WIDTH + get_theme_constant(&"separation", &"HBoxContainer")
	Session.project_changed.connect(_on_project_changed)
	_on_project_changed(Session.project)
	Transport.position_changed.connect(_on_position_changed)
	%Ruler.gui_input.connect(_on_ruler_gui_input)
	_on_position_changed(Transport.position)  # put the line at 0 on startup, not where it sits in the editor


## rebuilds every row and listens to the new projects track signals
func _on_project_changed(project: ProjectData) -> void:
	# if a project is "loaded" then session is listening to THAT ProjectData signals.
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


## slides the playhead line to the current time
func _on_position_changed(seconds: float) -> void:
	var x := _lane_start + seconds * Session.pixels_per_second
	# center the 2px line on the time (1px each side), same as the ruler's lines,
	# otherwise its left edge sits on the time and it looks shifted right
	%Playhead.offset_left = x - 1.0
	%Playhead.offset_right = x + 1.0


## clicking the ruler jumps the clock there
func _on_ruler_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		# gui_input positions are local to the Ruler, so x=0 is the start of the song
		Transport.seek(click.position.x / Session.pixels_per_second)
