class_name ProjectData
extends Resource
## the whole song: tempo and the list of tracks

signal track_added(track: TrackData, index: int)
signal track_removed(track: TrackData)

@export var name: String = "Untitled"
@export_range(20.0, 300.0) var bpm: float = 120.0:
	set(value):
		bpm = clampf(value, 20.0, 300.0)
		emit_changed()
@export var beats_per_bar: int = 4
@export var tracks: Array[TrackData] = []


func add_track(track: TrackData, index: int = -1) -> void:
	if index < 0 or index > tracks.size():
		index = tracks.size()
	tracks.insert(index, track)
	track_added.emit(track, index)


func remove_track(track: TrackData) -> void:
	tracks.erase(track)
	track_removed.emit(track)


## end time of the last clip, in seconds. the To End button jumps here
func get_length() -> float:
	var length := 0.0
	for track: TrackData in tracks:
		for clip: ClipData in track.clips:
			length = maxf(length, clip.end)
	return length
