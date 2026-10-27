class_name PianoRoll
extends Control
## Piano roll mock-up

const KEY_WIDTH := 80.0
const ROW_HEIGHT := 40.0
const BEAT_WIDTH := 48.0
const BEATS_PER_BAR := 4
const BARS := 8
const PITCH_LOW := 60 ## C4
const PITCH_HIGH := 71 ## B4
const BLACK_PITCHES := [1, 3, 6, 8, 10]


func _ready() -> void:
	custom_minimum_size = Vector2(
		KEY_WIDTH + BARS * BEATS_PER_BAR * BEAT_WIDTH,
		(PITCH_HIGH - PITCH_LOW + 1) * ROW_HEIGHT
	)


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

	# Beat and bar lines + bar numbers
	for b in range(BARS * BEATS_PER_BAR + 1):
		var x := KEY_WIDTH + b * BEAT_WIDTH
		var is_bar := b % BEATS_PER_BAR == 0
		draw_line(
			Vector2(x, 0), Vector2(x, h),
			Color(1, 1, 1, 0.3 if is_bar else 0.12))
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
					font, Vector2(6, y + ROW_HEIGHT - 4.0), "C%d" % (pitch / 12 - 1),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.25, 0.25, 0.3))
		draw_line(
			Vector2(0, y + ROW_HEIGHT), Vector2(KEY_WIDTH, y + ROW_HEIGHT),
			Color(0, 0, 0, 0.35))
	draw_line(Vector2(KEY_WIDTH, 0), Vector2(KEY_WIDTH, h), Color(0, 0, 0, 0.6))


func _is_black(pitch: int) -> bool:
	return pitch % 12 in BLACK_PITCHES


func _y_of(pitch: int) -> float:
	return (PITCH_HIGH - pitch) * ROW_HEIGHT
