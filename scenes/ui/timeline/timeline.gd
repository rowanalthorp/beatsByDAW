extends VBoxContainer
## the track list: one TrackRow per track in the open project

const TRACK_ROW_SCENE := preload("res://scenes/ui/timeline/track_row.tscn")
const HEADER_WIDTH := 200.0 # track header / HeaderSpacer width, lanes start after it
const SCROLL_PADDING := 10.0 # seconds of empty room after the last clip, so theres space to add more

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
	Session.view_changed.connect(_on_view_changed)
	%HScrollBar.value_changed.connect(_on_scroll_changed)
	%Ruler.resized.connect(_update_scrollbar) # window/sidebar size changes how much of the song fits
	Transport.position_changed.connect(_follow_playhead)


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
	_update_scrollbar() # new song, new length, so the scroll bar needs resizing


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
	var x := _lane_start + (seconds - Session.scroll_seconds) * Session.pixels_per_second
	# center the 2px line on the time (1px each side), same as the ruler's lines,
	# otherwise its left edge sits on the time and it looks shifted right
	%Playhead.offset_left = x - 1.0
	%Playhead.offset_right = x + 1.0
	# scrolled past it to the left, hide it or it'd draw over the track headers
	%Playhead.visible = x >= _lane_start

## clicking the ruler jumps the clock there
func _on_ruler_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		# gui_input positions are local to the Ruler, so x=0 is the left edge of what's showing.
		# add the scroll to turn that into song time
		Transport.seek(Session.scroll_seconds + click.position.x / Session.pixels_per_second)


## zoom or scroll changed, so the playhead has to move to where its time is now,
## and zoom changes how much of the song fits, so the scroll bar needs resizing
func _on_view_changed() -> void:
	_on_position_changed(Transport.position)
	_update_scrollbar()


func _on_scroll_changed(value: float) -> void:
	Session.scroll_seconds = value


## sizes the scroll bar to the song: the whole bar is the song (plus padding),
## the draggable part (page) is how much of it fits on screen right now
func _update_scrollbar() -> void:
	Session.lane_width = %Ruler.size.x # the ruler is exactly as wide as the visible lanes
	# typed float, not := because %Ruler is just a Node to the type checker so .size cant be inferred
	var visible_seconds: float = %Ruler.size.x / Session.pixels_per_second
	%HScrollBar.max_value = maxf(Session.project.get_length() + SCROLL_PADDING, visible_seconds)
	%HScrollBar.page = visible_seconds
	%HScrollBar.set_value_no_signal(Session.scroll_seconds)
	# zooming out can leave us scrolled past the end, so pull back to the furthest valid spot
	var max_scroll: float = maxf(%HScrollBar.max_value - visible_seconds, 0.0)
	if Session.scroll_seconds > max_scroll:
		Session.scroll_seconds = max_scroll


## while playing, once the playhead goes off the right edge, flip the view forward
## so it starts back at the left, kinda like how ableton and audacity do it
func _follow_playhead(seconds: float) -> void:
	if not Transport.playing:
		return # seeking while paused (ruler click, to start/end) shouldnt drag the view around
	var visible_seconds: float = %Ruler.size.x / Session.pixels_per_second
	var max_scroll: float = maxf(%HScrollBar.max_value - visible_seconds, 0.0)
	# the fake clock keeps counting after the song ends, so once we're scrolled as far as we
	# can go, stop trying or it'd set the scroll (and redraw everything) every frame for nothing
	if seconds >= Session.scroll_seconds + visible_seconds and Session.scroll_seconds < max_scroll:
		Session.scroll_seconds = minf(seconds, max_scroll)
