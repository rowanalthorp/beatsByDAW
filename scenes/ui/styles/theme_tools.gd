class_name ThemeTools
# bored so I made light mode/dark mode :)

## returns a light copy of the default dark theme. greys flip. saturated accents unchanged
static func make_light(dark: Theme) -> Theme:
	# start from godots default theme. node types main_theme doesn't set (like labels) use the defaults look, so they need flipping too
	# duplicate() copies a list, but keeps pointers to the same values, while duplicate(true) duplicates the values with new pointers
	var light: Theme = ThemeDB.get_default_theme().duplicate(true) 
	light.merge_with(dark.duplicate(true))
	var flipped: Dictionary = {}  # one stylebox can be shared by several types (flip it once or things get screwy)
	for type: String in light.get_type_list():
		for colour_name: String in light.get_color_list(type):
			# they looked super ugly flipped
			if colour_name in ["button_checked_color", "button_unchecked_color"]:
				continue
			light.set_color(colour_name, type, flip(light.get_color(colour_name, type)))
		for box_name: String in light.get_stylebox_list(type):
			var box: StyleBox = light.get_stylebox(box_name, type)
			if flipped.has(box):
				continue
			flipped[box] = true
			
			# attempt to store box as a StyleBoxFlat, and if returns null, we know box is not a StyleBoxFlat and can ignore it
			var flat := box as StyleBoxFlat
			if flat:
				# simply just flip the important bits
				# border colour and shadow colour arent really important, but gotta cover your bases since we using godot default as base
				flat.bg_color = flip(flat.bg_color)
				flat.border_color = flip(flat.border_color)
				flat.shadow_color = flip(flat.shadow_color)
			# same thing with flat but with line instead
			var line := box as StyleBoxLine
			if line:
				line.color = flip(line.color)
	return light

## inverts brightness of greys. colours with real saturation are accents and are unchanged (i.e the clips)
static func flip(colour: Color) -> Color:
	if colour.s > 0.3:
		# basically, if you see flip(), it doesnt necessarily flip, as if sat > 0.3, it simply just returns
		return colour
	return Color.from_hsv(colour.h, colour.s, 1.0 - colour.v, colour.a)
