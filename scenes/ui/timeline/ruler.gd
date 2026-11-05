extends Panel
## the time ruler above the lanes. two modes, switched from View > Ruler in Seconds:
## bars (numbered line every bar, tick every beat) or seconds (m:ss lines, tick in between).
## both modes work out spacing in seconds first, then one loop draws either one

const MIN_TICK_SPACING := 6.0 # px; any closer and the small ticks (beats or seconds) blur into a solid block
const MIN_LABEL_SPACING := 60.0 # px; seconds labels like "0:10" need about this much room to not overlap
# "nice" gaps between labels in seconds mode. we use the smallest one that fits,
# so zooming in shows every second and zooming out jumps to 5s, 10s, a minute...
const SECOND_STEPS: Array[float] = [1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0, 120.0, 300.0]

var _project: ProjectData # the project whose changed signal is connected


func _ready() -> void:
	Session.project_changed.connect(_on_project_changed)
	Session.view_changed.connect(queue_redraw) # mode switch (and zoom later) means redraw
	_on_project_changed(Session.project)


## same swap as timeline.gd: stop listening to the old project, listen to the new one
func _on_project_changed(project: ProjectData) -> void:
	if _project:
		_project.changed.disconnect(queue_redraw)
	_project = project
	_project.changed.connect(queue_redraw) # the bpm setter emits changed, so a tempo change redraws
	queue_redraw()


## godot calls this whenever the ruler needs repainting (queue_redraw, resize, first frame).
## everything drawn here is in the ruler's own coords, so x=0 is the start of the song
## (the ruler already sits after the 200px header + gap, same as the lanes)
func _draw() -> void:
	# pull the text color + font from the theme instead of hardcoding white,
	# otherwise light mode would leave white lines on a white ruler
	# (thank god I decided to implement light moe before I did all the actual functionality lol)
	var color := get_theme_color(&"font_color", &"Label")
	var faded := Color(color, 0.5) # beat ticks are half see-through so the bar lines stand out
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var pps := Session.pixels_per_second # gets used enough it's cleaner with a shorthand var
	
	# how far apart the numbered lines and the small ticks are, in seconds.
	# bars mode: a numbered line every bar, a tick every beat.
	#   60 / bpm = seconds per beat, so at 120 bpm thats 0.5s a beat and 2s a bar
	# seconds mode: a numbered line every "nice" step that fits, one tick halfway between
	var label_step: float
	var tick_step: float
	if Session.show_seconds:
		label_step = _seconds_step()
		tick_step = label_step / 2.0
	else:
		tick_step = 60.0 / _project.bpm
		label_step = tick_step * _project.beats_per_bar
	
	# how wide those are on screen right now (seconds * px per second).
	# at 120 bpm and 40 px/s thats 0.5s * 40 = 20px a beat, 80px a bar
	var tick_px := tick_step * pps
	var label_px := label_step * pps
	
	# walk label by label from the left edge and stop once we go past the ruler's width, 
	# no point drawing lines nobody can see
	var i := 0
	while i * label_px <= size.x:
		var x := i * label_px
		
		# full height line marks the start of each bar/labelled time
		draw_line(Vector2(x, 0), Vector2(x, size.y), color)
		
		# label just right of the line. bars are counted from 1 like musicians do,
		# so bar index 0 shows "1", but seconds start at 0:00 like a clock.
		# draw_string puts the text's baseline (bottom of the letters) at the y we give it,
		# so we push it down by the font's ascent or it'd get cut off the top
		var text := _format_seconds(i * label_step) if Session.show_seconds else str(i + 1)
		draw_string(font, Vector2(x + 4, font.get_ascent(font_size)), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		
		# small ticks between labels: the beats inside a bar, or the halfway mark in seconds mode
		# (tick 0 is the labelled line itself, so start at 1).
		# when zoomed way out the ticks get squished together into a solid block,
		# so skip them once theyre closer than MIN_TICK_SPACING
		if tick_px >= MIN_TICK_SPACING:
			var ticks := roundi(label_step / tick_step) # beats per bar, or 2 in seconds mode
			for t in range(1, ticks):
				var tick_x := x + t * tick_px
				# only the bottom 40% of the ruler, so they read as smaller than the numbered lines
				draw_line(Vector2(tick_x, size.y * 0.6), Vector2(tick_x, size.y), faded)

		i += 1


## seconds mode: picks how many seconds apart the labels go (0:00, 0:02, 0:04...).
## takes the smallest step from SECOND_STEPS that's wide enough on screen for the text to not overlap
func _seconds_step() -> float:
	for step: float in SECOND_STEPS:
		if step * Session.pixels_per_second >= MIN_LABEL_SPACING:
			return step
	return SECOND_STEPS[-1] # zoomed out past everything, just use the biggest


## 65 seconds -> "1:05"
func _format_seconds(seconds: float) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), floori(fmod(seconds, 60.0))]
