extends Node
## editor state which is shared by the whole ui. for now: the open project

signal project_changed(project: ProjectData)
## something about how the timeline is shown changed (ruler mode, zoom or scroll)
signal view_changed
## a clip was double-clicked and wants its editor opened (piano roll for instrument clips)
signal open_clip_requested(clip: ClipData)

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


func open_project(new_project: ProjectData) -> void:
	project = new_project
	project_changed.emit(project)


## multiply instead of add so every press feels the same size,
## +10 px/s would be huge at 20 px/s but do basically nothing at 800
func zoom_in() -> void:
	pixels_per_second *= ZOOM_STEP


func zoom_out() -> void:
	pixels_per_second /= ZOOM_STEP


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
