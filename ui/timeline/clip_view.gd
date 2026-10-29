class_name ClipView
extends Panel
## draws one ClipData as a block in a track's lane

var clip: ClipData

func setup(new_clip: ClipData) -> void:
	clip = new_clip
	clip.changed.connect(_refresh)  # redraw when start/length/name change
	_refresh()

func _refresh() -> void:
	%ClipName.text = clip.name
	# Only touch the left/right edges. Top/bottom stay anchored 4 px inside the lane.
	offset_left = clip.start * Session.pixels_per_second
	offset_right = offset_left + clip.length * Session.pixels_per_second
