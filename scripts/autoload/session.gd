extends Node
## editor state which is shared by the whole ui. for now: the open project

signal project_changed(project: ProjectData)
## something about how the timeline is shown changed (time format for now, zoom later)
signal view_changed

var project: ProjectData = ProjectData.new()
## zoom: how many pixels wide one second of the project is
var pixels_per_second: float = 40.0
## ruler shows minutes:seconds (like audacity) instead of bars (like ableton)
var show_seconds: bool = false:
	set(value):
		show_seconds = value
		view_changed.emit()

func open_project(new_project: ProjectData) -> void:
	project = new_project
	project_changed.emit(project)

## adds an empty track at the bottom, named like "Audio 3" or something
func add_new_track(kind: TrackData.Kind) -> void:
	var track := TrackData.new()
	track.kind = kind
	var label := "Audio" if kind == TrackData.Kind.AUDIO else "Instrument"
	track.name = "%s %d" % [label, project.tracks.size() + 1]
	project.add_track(track)
