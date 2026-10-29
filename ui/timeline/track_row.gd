class_name TrackRow
extends HBoxContainer
## one track: header controls on the left, its clips in the lane on the right

const CLIP_VIEW_SCENE := preload("res://ui/timeline/clip_view.tscn")

var track: TrackData

func setup(new_track: TrackData) -> void:
	track = new_track
	%NameEdit.text = track.name
	for clip: ClipData in track.clips:
		_add_clip_view(clip)

func _add_clip_view(clip: ClipData) -> void:
	var view := CLIP_VIEW_SCENE.instantiate() as ClipView
	%Lane.add_child(view)
	view.setup(clip)
