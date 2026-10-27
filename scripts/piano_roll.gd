class_name PianoRoll
extends Control
## Piano roll, LMB places a note and RMB deletes it.
## Clicking the keyboard previews the pitch through the instrument.
## Notes are stored as { pitch, start, length, velocity } in beats.

signal preview_note_on(pitch: int)
signal preview_note_off(pitch: int)

const KEY_WIDTH := 56.0
const ROW_HEIGHT := 14.0
const BEAT_WIDTH := 48.0
const BEATS_PER_BAR := 4
const BARS := 8
const SNAP := 0.5
const RESIZE_MARGIN := 7.0
const PITCH_LOW := 36 ## C2
const PITCH_HIGH := 96 ## C7
const BLACK_PITCHES := [1, 3, 6, 8, 10]

var notes: Array[Dictionary] = []
var show_playhead := false
var playhead_beat := 0.0

var _preview_pitch := -1
var _resize_note := -1
var _move_note := -1
var _grab_beat_offset := 0.0
var _grab_pitch_offset := 0


func _ready() -> void:
	custom_minimum_size = Vector2(
		KEY_WIDTH + BARS * BEATS_PER_BAR * BEAT_WIDTH,
		(PITCH_HIGH - PITCH_LOW + 1) * ROW_HEIGHT
	)


func clear_notes() -> void:
	notes.clear()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb:
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			accept_event()
			var pos := mb.position
			if pos.x < KEY_WIDTH:
				_preview_pitch = _pitch_at(pos.y)
				preview_note_on.emit(_preview_pitch)
				return
			var idx := _note_at(pos)
			if idx == -1:
				idx = _add_note(_beat_at(pos.x), _pitch_at(pos.y))
				_move_note = idx
				_grab_beat_offset = _beat_at(pos.x) - notes[idx].start
				_grab_pitch_offset = 0
				queue_redraw()
			elif _near_right_edge(notes[idx], pos.x):
				_resize_note = idx
			else:
				_move_note = idx
				_grab_beat_offset = _beat_at(pos.x) - notes[idx].start
				_grab_pitch_offset = notes[idx].pitch - _pitch_at(pos.y)
			preview_note_on.emit(notes[idx].pitch)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			accept_event()
			var idx := _note_at(mb.position)
			if idx != -1:
				notes.remove_at(idx)
				queue_redraw()
	elif event is InputEventMouseMotion:
		# Cursor hints, resize on the right edge and move on the body
		var idx := _note_at(event.position)
		if idx == -1:
			mouse_default_cursor_shape = CURSOR_ARROW
		elif _near_right_edge(notes[idx], event.position.x):
			mouse_default_cursor_shape = CURSOR_HSIZE
		else:
			mouse_default_cursor_shape = CURSOR_MOVE


# Drag and release handled here instead of _gui_input so they still work
# when the cursor leaves the control.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		if _preview_pitch != -1:
			preview_note_off.emit(_preview_pitch)
			_preview_pitch = -1
		_resize_note = -1
		_move_note = -1
		return
	if event is InputEventMouseMotion:
		var pos := get_local_mouse_position()
		if _resize_note != -1:
			if _resize_note >= notes.size():
				_resize_note = -1
				return
			var n := notes[_resize_note]
			var end := clampf(
				snappedf(_beat_at(pos.x), SNAP), 0.0, float(BARS * BEATS_PER_BAR))
			n.length = clampf(end - n.start, SNAP, BARS * BEATS_PER_BAR - n.start)
			queue_redraw()
		elif _move_note != -1:
			if _move_note >= notes.size():
				_move_note = -1
				return
			var n := notes[_move_note]
			n.start = _snap_floor(_beat_at(pos.x) - _grab_beat_offset)
			n.start = minf(n.start, BARS * BEATS_PER_BAR - n.length)
			n.pitch = clampi(
				_pitch_at(pos.y) + _grab_pitch_offset, PITCH_LOW, PITCH_HIGH)
			queue_redraw()
		elif _preview_pitch != -1 and pos.x < KEY_WIDTH:
			var p := _pitch_at(pos.y)
			if p != _preview_pitch:
				preview_note_off.emit(_preview_pitch)
				_preview_pitch = p
				preview_note_on.emit(p)


func _draw() -> void:
	var grid_w := BARS * BEATS_PER_BAR * BEAT_WIDTH
	var rows := PITCH_HIGH - PITCH_LOW + 1
	var h := rows * ROW_HEIGHT
	var font := get_theme_default_font()

	# Grid background, black-key rows shaded darker.
	draw_rect(Rect2(0, 0, KEY_WIDTH + grid_w, h), Color(0.13, 0.13, 0.16))
	for pitch in range(PITCH_LOW, PITCH_HIGH + 1):
		if _is_black(pitch):
			draw_rect(
				Rect2(KEY_WIDTH, _y_of(pitch), grid_w, ROW_HEIGHT),
				Color(0.0, 0.0, 0.0, 0.22))

	# Row separators, stronger line at the top of the C row.
	for r in range(rows + 1):
		var y := r * ROW_HEIGHT
		var strong := r > 0 and (PITCH_HIGH - r) % 12 == 0
		draw_line(
			Vector2(0, y), Vector2(KEY_WIDTH + grid_w, y),
			Color(1, 1, 1, 0.22 if strong else 0.07))

	# Beat, half-beat, and bar lines + bar numbers
	for b in range(BARS * BEATS_PER_BAR + 1):
		var x := KEY_WIDTH + b * BEAT_WIDTH
		var is_bar := b % BEATS_PER_BAR == 0
		draw_line(
			Vector2(x, 0), Vector2(x, h),
			Color(1, 1, 1, 0.3 if is_bar else 0.12))
		if b < BARS * BEATS_PER_BAR:
			var xh := x + BEAT_WIDTH * SNAP
			draw_line(Vector2(xh, 0), Vector2(xh, h), Color(1, 1, 1, 0.05))
		if is_bar and b < BARS * BEATS_PER_BAR:
			draw_string(
				font, Vector2(x + 4, 12), "Bar %d" % (b / BEATS_PER_BAR + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.5))

	# Keyboard column
	for pitch in range(PITCH_LOW, PITCH_HIGH + 1):
		var y := _y_of(pitch)
		if _is_black(pitch):
			draw_rect(Rect2(0, y, KEY_WIDTH, ROW_HEIGHT), Color(0.1, 0.1, 0.12))
		else:
			draw_rect(Rect2(0, y, KEY_WIDTH, ROW_HEIGHT), Color(0.85, 0.85, 0.88))
			if pitch % 12 == 0:
				draw_string(
					font, Vector2(6, y + ROW_HEIGHT - 3.0), "C%d" % (pitch / 12 - 1),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.25, 0.25, 0.3))
		draw_line(
			Vector2(0, y + ROW_HEIGHT), Vector2(KEY_WIDTH, y + ROW_HEIGHT),
			Color(0, 0, 0, 0.35))
	draw_line(Vector2(KEY_WIDTH, 0), Vector2(KEY_WIDTH, h), Color(0, 0, 0, 0.6))

	for i in notes.size():
		var rect := _note_rect(notes[i])
		var col := Color(0.35, 0.65, 0.98)
		if i == _resize_note or i == _move_note:
			col = col.lightened(0.25)
		draw_rect(rect, col)
		draw_rect(rect, col.darkened(0.45), false, 1.5)

	if show_playhead:
		var x := KEY_WIDTH + playhead_beat * BEAT_WIDTH
		draw_line(Vector2(x, 0), Vector2(x, h), Color(1.0, 0.35, 0.35), 2.0)


func _is_black(pitch: int) -> bool:
	return pitch % 12 in BLACK_PITCHES


func _y_of(pitch: int) -> float:
	return (PITCH_HIGH - pitch) * ROW_HEIGHT


func _pitch_at(y: float) -> int:
	return clampi(PITCH_HIGH - int(y / ROW_HEIGHT), PITCH_LOW, PITCH_HIGH)


func _beat_at(x: float) -> float:
	return clampf((x - KEY_WIDTH) / BEAT_WIDTH, 0.0, float(BARS * BEATS_PER_BAR))


func _snap_floor(b: float) -> float:
	return clampf(floor(b / SNAP) * SNAP, 0.0, float(BARS * BEATS_PER_BAR))


func _near_right_edge(n: Dictionary, x: float) -> bool:
	var edge: float = KEY_WIDTH + (n.start + n.length) * BEAT_WIDTH
	return edge - x <= RESIZE_MARGIN


func _add_note(beat: float, pitch: int) -> int:
	notes.append({
		"pitch": pitch,
		"start": _snap_floor(beat),
		"length": 1.0,
		"velocity": 1.0,
	})
	return notes.size() - 1


func _note_at(pos: Vector2) -> int:
	for i in range(notes.size() - 1, -1, -1):
		if _note_rect(notes[i]).has_point(pos):
			return i
	return -1


func _note_rect(n: Dictionary) -> Rect2:
	return Rect2(
		KEY_WIDTH + n.start * BEAT_WIDTH,
		_y_of(n.pitch) + 1.0,
		n.length * BEAT_WIDTH - 1.0,
		ROW_HEIGHT - 2.0
	)
