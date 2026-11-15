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
## how far into the clip's audio the clip starts, in seconds. trimming the left edge raises this, so
## the audio stays where it was in the song and the beginning just gets hidden. note clips move their
## actual notes instead (see NoteClipData), so for them this stays 0
@export var offset: float = 0.0:
	set(value):
		offset = maxf(value, 0.0)
		emit_changed()

var end: float:
	get:
		return start + length


## moves the left edge to new_start without moving whats inside: the right edge stays put and
## offset grows/shrinks by however much got hidden/shown. cant go past where the content begins
## (offset 0) or the start of the song, and keeps at least min_length of clip
func trim_start_to(new_start: float, min_length: float = 0.01) -> void:
	new_start = clampf(new_start, maxf(start - offset, 0.0), end - min_length)
	var moved := new_start - start
	offset += moved
	length -= moved
	start = new_start


## cuts this clip at `at` (song seconds). this one becomes the left half, and the right half
## comes back as a new clip, trimmed up to `at` so whats inside stays put
func split_at(at: float) -> ClipData:
	# true = deep copy. without it both halves share one notes array, and editing one changes both
	var right_half := duplicate(true) as ClipData
	right_half.trim_start_to(at)
	length = at - start
	return right_half
