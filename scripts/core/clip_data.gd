class_name ClipData
extends Resource
## one block on a track. times are seconds from the start of the song
## setters call emit_changed() so the screen can redraw when a value changes

@export var name: String = "Clip":
	set(value):
		name = value
		emit_changed()
@export var start: float = 0.0:
	set(value):
		start = maxf(value, 0.0) # set a floor at 0.0
		emit_changed()
@export var length: float = 1.0:
	set(value):
		length = maxf(value, 0.01) # set a floor at 0.01
		emit_changed()

var end: float:
	get:
		return start + length
