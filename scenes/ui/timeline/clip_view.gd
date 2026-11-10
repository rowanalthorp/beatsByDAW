class_name ClipView
extends Panel
## draws one ClipData as a block in a track's lane

var clip: ClipData

var _dragging := false
var _grab_x := 0.0 # where on the clip the mouse grabbed it, in px from the clip's left edge

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
	if motion and _dragging:
		# move the clip by however far the mouse is from where it grabbed. the block moves
		# right away (clip.changed -> _refresh), so the grab point stays under the mouse
		clip.start += (motion.position.x - _grab_x) / Session.pixels_per_second
		accept_event()
		return
	var click := event as InputEventMouseButton
	if not click or click.button_index != MOUSE_BUTTON_LEFT:
		return
	# eat the click so the lane behind the clip doesnt also get it and deselect
	accept_event()
	if not click.pressed:
		_dragging = false # let go, drag's done
		return
	# double_click is godot's own flag for a quick second click, so we dont have to time clicks ourselves
	if click.double_click:
		Session.request_open_clip(clip)
	else:
		Session.selected_clip = clip
		_dragging = true
		_grab_x = click.position.x


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
