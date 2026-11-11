extends Node
## editor state which is shared by the whole ui. for now: the open project

signal project_changed(project: ProjectData)
## something about how the timeline is shown changed (ruler mode, zoom or scroll)
signal view_changed
## a clip was double-clicked and wants its editor opened (piano roll for instrument clips)
signal open_clip_requested(clip: ClipData)
## a different clip got clicked (or nothing is selected anymore)
signal selection_changed
## a clip was moved or deleted, so the song might be a different length now
signal song_length_changed
## a track's Effects button was pressed and wants the sidebar opened for it
signal effects_requested(track: TrackData)

const MIN_ZOOM := 2.0 # px per second. all the way out, a 5 min song is ~600px wide
const MAX_ZOOM := 1000.0 # px per second. all the way in, one beat at 120 bpm is 500px
const ZOOM_STEP := 1.25 # each zoom press multiplies/divides by this

var project: ProjectData = ProjectData.new()
## zoom: how many pixels wide one second of the project is
var pixels_per_second: float = 40.0:
	set(value):
		# clamp so you cant zoom in or out forever
		pixels_per_second = clampf(value, MIN_ZOOM, MAX_ZOOM)
		view_changed.emit()
## ruler shows minutes:seconds (like audacity) instead of bars (like ableton)
var show_seconds: bool = false:
	set(value):
		show_seconds = value
		view_changed.emit()

## horizontal scroll: the song time (in seconds) at the left edge of the lanes
var scroll_seconds: float = 0.0:
	set(value):
		scroll_seconds = maxf(value, 0.0) # cant scroll to before the song starts
		view_changed.emit()

## how many px wide the visible lane area is. timeline keeps this up to date so zoom to fit knows how much room there is
var lane_width: float = 0.0

## the clip that was clicked last. null means nothing is selected
var selected_clip: ClipData = null:
	set(value):
		selected_clip = value
		selection_changed.emit()

## when on, dragged clips land on the nearest beat. the checkbox in the bottom bar sets this
var snap_to_beat: bool = false

func open_project(new_project: ProjectData) -> void:
	project = new_project
	project_changed.emit(project)


## multiply instead of add so every press feels the same size,
## +10 px/s would be huge at 20 px/s but do basically nothing at 800
func zoom_in() -> void:
	pixels_per_second *= ZOOM_STEP


func zoom_out() -> void:
	pixels_per_second /= ZOOM_STEP


## zoom so the whole song fits on screen, and scroll back to the start
func zoom_to_fit() -> void:
	var length := project.get_length()
	if length <= 0.0 or lane_width <= 0.0:
		return # empty song, or the timeline hasnt been laid out yet. nothing to fit
	scroll_seconds = 0.0
	# 95% of the width so the last clip isnt jammed right against the edge
	pixels_per_second = lane_width * 0.95 / length


## adds an empty track at the bottom, named like "Audio 3" or something
func add_new_track(kind: TrackData.Kind) -> void:
	var track := TrackData.new()
	track.kind = kind
	var label := "Audio" if kind == TrackData.Kind.AUDIO else "Instrument"
	track.name = "%s %d" % [label, project.tracks.size() + 1]
	project.add_track(track)


## godot was giving a warning if I didn't emit the signal this way so
func request_open_clip(clip: ClipData) -> void:
	open_clip_requested.emit(clip)


## clip_view calls this when a drag ends. same warning thing as request_open_clip
func report_clip_moved() -> void:
	song_length_changed.emit()


## same warning thing as request_open_clip
func request_effects(track: TrackData) -> void:
	effects_requested.emit(track)


## takes the selected clip off whatever track its on
func delete_selected() -> void:
	if selected_clip == null:
		return
	for track: TrackData in project.tracks:
		if selected_clip in track.clips:
			track.remove_clip(selected_clip)
			break
	# clear it even if no track had it (its track might have been deleted already)
	selected_clip = null
	song_length_changed.emit()


## rounds a time (seconds) to the nearest beat if snap is on, otherwise gives it back untouched.
## one beat is 60 / bpm seconds, snappedf rounds to the nearest multiple of that
func snap(seconds: float) -> float:
	if not snap_to_beat:
		return seconds
	return snappedf(seconds, 60.0 / project.bpm)
