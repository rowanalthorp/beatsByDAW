class_name ClipView
extends Panel
## draws one ClipData as a block in a track's lane

var clip: ClipData

func setup(new_clip: ClipData) -> void:
	clip = new_clip
	clip.changed.connect(_refresh)  # redraw when start/length/name change
	Session.view_changed.connect(_refresh) # zoom or scroll changed, so move/resize the block
	_refresh()

func _refresh() -> void:
	%ClipName.text = clip.name
	# Only touch the left/right edges. Top/bottom stay anchored 4 px inside the lane.
	# minus the scroll so clips slide left as you scroll right
	offset_left = (clip.start - Session.scroll_seconds) * Session.pixels_per_second
	offset_right = offset_left + clip.length * Session.pixels_per_second
