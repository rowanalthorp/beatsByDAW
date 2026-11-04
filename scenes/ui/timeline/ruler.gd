extends Panel
## the time ruler above the lanes: a numbered line at every bar, a small tick at every beat

const MIN_BEAT_SPACING := 6.0 # px; any closer and the beat ticks blur into a solid block

var _project: ProjectData # the project whose changed signal is connected


func _ready() -> void:
	Session.project_changed.connect(_on_project_changed)
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
	# how wide one beat and one bar are on screen right now.
	# 60 / bpm = seconds per beat, times px per second = px per beat.
	# at 120 bpm and 40 px/s thats 0.5s * 40 = 20px a beat, 80px a bar
	var beat_px := 60.0 / _project.bpm * Session.pixels_per_second
	var bar_px := beat_px * _project.beats_per_bar
	 
	# pull the text color + font from the theme instead of hardcoding white,
	# otherwise light mode would leave white lines on a white ruler
	# (thank god I decided to implement light moe before I did all the actual functionality lol)
	var color := get_theme_color(&"font_color", &"Label")
	var faded := Color(color, 0.5) # beat ticks are half see-through so the bar lines stand out
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	
	# walk bar by bar from the left edge and stop once we go past the ruler's width,
	# no point drawing lines nobody can see
	var bar := 0
	while bar * bar_px <= size.x:
		var bar_x := bar * bar_px
		
		# full height line marks the start of each bar
		draw_line(Vector2(bar_x, 0), Vector2(bar_x, size.y), color)
		
		# bar number just right of the line. bars are counted from 1 like musicians do,
		# so bar index 0 shows "1". draw_string puts the text's baseline (bottom of the letters)
		# at the y we give it, so we push it down by the font's ascent or it'd get cut off the top
		draw_string(font, Vector2(bar_x + 4, font.get_ascent(font_size)), str(bar + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		
		# small ticks for the beats inside the bar (beat 0 is the bar line itself, so start at 1).
		# when zoomed way out the beats get squished together into a solid block,
		# so skip them once theyre closer than MIN_BEAT_SPACING
		if beat_px >= MIN_BEAT_SPACING:
			for beat in range(1, _project.beats_per_bar):
				var beat_x := bar_x + beat * beat_px
				# only the bottom 40% of the ruler, so they read as smaller than bar lines
				draw_line(Vector2(beat_x, size.y * 0.6), Vector2(beat_x, size.y), faded)
		
		bar += 1
