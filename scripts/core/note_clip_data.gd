class_name NoteClipData
extends ClipData
## a clip on an instrument track: a normal clip that also holds the notes the piano roll edits.
## notes are in the piano roll's format {pitch, start, length, velocity}. start/length are in beats
## from the start of this clip (not the song), so moving the clip moves its notes with it

@export var notes: Array[Dictionary] = []

@export var instrument: String = "piano"

## semitones the clip plays back shifted by (render-time, notes stay as written)
@export var transpose: int = 0

## tuning reference — frequency of A4 in Hz
@export var ref_pitch: float = 440.0

## key/scale the piano roll snaps placed notes to — "none" disables snapping
@export var scale_root: int = 0   # pitch class, 0 = C
@export var scale_type: String = "none"   # "none" | "major" | "minor"

## absolute path of rendered wav for the engine, empty until rendered
## the engine plays it via add_audio_clip(wav_path, clip.start)
var wav_path := ""

## true when notes changed since the last render
var notes_dirty := true

var _stream: AudioStreamWAV # the last render, reused until something it was made from changes
var _rendered_from: Array = [] # copy of [notes, length, bpm] at the last render, to tell if it's out of date

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
	notes_dirty = true
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


## the notes rendered to sound with kris's piano. renders again only when the notes, the clip's length
## or the tempo changed since last time. the piano roll edits notes straight in the array without telling
## the clip, so comparing against a copy of what the last render was made from catches every kind of edit
func get_stream() -> AudioStream:
	var made_from := [notes.duplicate(true), length, Session.project.bpm]
	if _stream == null or made_from != _rendered_from:
		_stream = NoteRenderer.render_pattern(notes, length / _beat_seconds(), Session.project.bpm)
		_rendered_from = made_from
		_save_render()
	return _stream


## same file and folder the piano roll window saves to, so the engine finds the newest render in wav_path
func _save_render() -> void:
	DirAccess.make_dir_recursive_absolute("user://renders")
	var path := "user://renders/%d.wav" % get_instance_id()
	if _stream.save_to_wav(path) == OK:
		wav_path = ProjectSettings.globalize_path(path)
		notes_dirty = false

## notes are in beats, so this is how many seconds one beat lasts at the songs tempo
func _beat_seconds() -> float:
	return 60.0 / Session.project.bpm
