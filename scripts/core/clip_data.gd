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
## how far into the clip's content (audio file / notes) the clip starts, in seconds. trimming the
## left edge raises this, so the content stays where it was in the song and the beginning just gets hidden
@export var offset: float = 0.0:
	set(value):
		offset = maxf(value, 0.0)
		emit_changed()

var end: float:
	get:
		return start + length


## moves the left edge to new_start without moving whats inside: the right edge stays put and
## offset grows/shrinks by however much got hidden/shown. cant go past where the content begins
## (offset 0) or the start of the song, and keeps at least a sliver of clip
func trim_start_to(new_start: float) -> void:
	new_start = clampf(new_start, maxf(start - offset, 0.0), end - 0.01)
	var moved := new_start - start
	offset += moved
	length -= moved
	start = new_start
