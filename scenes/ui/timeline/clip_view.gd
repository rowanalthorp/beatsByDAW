class_name ClipView
extends Panel
## draws one ClipData as a block in a track's lane

var clip: ClipData

const EDGE_GRAB := 6.0 # px in from each edge that grabs the edge (trim) instead of the middle (move)

enum DragMode { NONE, MOVE, TRIM_LEFT, TRIM_RIGHT }

var _drag_mode := DragMode.NONE
var _grab_x := 0.0 # px from the thing being dragged (clip's left edge for move, the edge itself for trims) to the mouse

func setup(new_clip: ClipData) -> void:
	clip = new_clip
	clip.changed.connect(_refresh)  # redraw when start/length/name change
	Session.view_changed.connect(_refresh) # zoom or scroll changed, so move/resize the block
	_refresh()
	Session.selection_changed.connect(queue_redraw) # outline on/off

func _refresh() -> void:
	%ClipName.text = clip.name
	# Only touch the left/right edges. Top/bottom stay anchored 4 px inside the lane.
	# minus the scroll so clips slide left as you scroll right
	offset_left = (clip.start - Session.scroll_seconds) * Session.pixels_per_second
	offset_right = offset_left + clip.length * Session.pixels_per_second


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion:
		_on_mouse_moved(motion)
		return
	var click := event as InputEventMouseButton
	if not click or click.button_index != MOUSE_BUTTON_LEFT:
		return
	# eat the click so the lane behind the clip doesnt also get it and deselect
	accept_event()
	if not click.pressed:
		if _drag_mode != DragMode.NONE:
			Session.report_clip_moved() # moving or trimming the last clip changes the song length
		_drag_mode = DragMode.NONE # let go, drag's done
		return
	# double_click is godot's own flag for a quick second click, so we dont have to time clicks ourselves
	if click.double_click:
		Session.request_open_clip(clip)
		return
	Session.selected_clip = clip
	_drag_mode = _mode_at(click.position.x)
	# remember where on the dragged thing we grabbed, so it doesnt jump to line up with the mouse
	_grab_x = click.position.x - (size.x if _drag_mode == DragMode.TRIM_RIGHT else 0.0)


func _on_mouse_moved(motion: InputEventMouseMotion) -> void:
	if _drag_mode == DragMode.NONE:
		# just hovering. resize arrows over the edges so you can tell they trim
		mouse_default_cursor_shape = CURSOR_ARROW if _mode_at(motion.position.x) == DragMode.MOVE else CURSOR_HSIZE
		return
	# song time the dragged thing should be at. motion.position is from the clip's left edge, so add start
	var target := Session.snap(clip.start + (motion.position.x - _grab_x) / Session.pixels_per_second)
	match _drag_mode:
		DragMode.MOVE:
			clip.start = target
		DragMode.TRIM_LEFT:
			clip.trim_start_to(target)
		DragMode.TRIM_RIGHT:
			clip.length = target - clip.start # (length setter keeps it from going to 0 or negative)
	accept_event()


## which part of the clip is under x (px from its left edge): edges trim, the middle moves.
## zoomed way out a clip can be only a few px wide, so each edge zone is at most a third of it
func _mode_at(x: float) -> DragMode:
	var edge := minf(EDGE_GRAB, size.x / 3.0)
	if x < edge:
		return DragMode.TRIM_LEFT
	if x > size.x - edge:
		return DragMode.TRIM_RIGHT
	return DragMode.MOVE



## selected clip gets an outline. uses the label text colour so it flips with light/dark mode
## (white got lost against the white lanes in light mode)
func _draw() -> void:
	if Session.selected_clip == clip:
		var outline_colour := get_theme_color(&"font_color", &"Label")
		# a dark outline (light mode) blends into the blue clip, so it needs to be thicker to look
		# the same as the white one. .v is brightness, so a dark colour means we're in light mode
		var width := 4.0 if outline_colour.v < 0.5 else 2.0
		# the line is centered on the rect edge, so pull it in half the width or half of it gets clipped off
		draw_rect(Rect2(Vector2.ONE * width / 2.0, size - Vector2.ONE * width), outline_colour, false, width)
