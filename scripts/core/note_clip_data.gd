class_name NoteClipData
extends ClipData
## a clip on an instrument track: a normal clip that also holds the notes the piano roll edits.
## notes are in the piano roll's format {pitch, start, length, velocity}. start/length are in beats
## from the start of this clip (not the song), so moving the clip moves its notes with it

@export var notes: Array[Dictionary] = []

## notes are in beats, so this is how many seconds one beat lasts at the songs tempo
func _beat_seconds() -> float:
	return 60.0 / Session.project.bpm


## the piano roll always shows notes from beat 0, so hiding the start with offset (like audio)
## doesnt work for notes. instead the notes slide back by however much the edge moved, so they
## stay put in the song. ones that end up before the new edge get dropped, ones half over it get cut
func trim_start_to(new_start: float, min_length: float = 0.01) -> void:
	new_start = clampf(new_start, 0.0, end - min_length)
	var moved_beats := (new_start - start) / _beat_seconds()
	# backwards so removing one doesnt skip the next. edits the array in place since the piano roll shares it
	for i in range(notes.size() - 1, -1, -1):
		var note := notes[i]
		note.start -= moved_beats
		if note.start + note.length <= 0.0:
			notes.remove_at(i) # all of it is before the new edge
		elif note.start < 0.0:
			note.length += note.start # sticks out past the edge, cut off the part before it
			note.start = 0.0
	length = end - new_start
	start = new_start


## the right half already dropped the notes before the split (its trim does that),
## so this half drops the ones after it. a note across the split ends up cut in two
func split_at(at: float) -> ClipData:
	var right_half := super(at)
	var split_beat := length / _beat_seconds()
	for i in range(notes.size() - 1, -1, -1):
		var note := notes[i]
		if note.start >= split_beat:
			notes.remove_at(i)
		elif note.start + note.length > split_beat:
			note.length = split_beat - note.start
	return right_half
