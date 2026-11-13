class_name NoteClipData
extends ClipData
## a clip on an instrument track: a normal clip that also holds the notes the piano roll edits.
## notes are in the piano roll's format {pitch, start, length, velocity}. start/length are in beats
## from the start of this clip (not the song), so moving the clip moves its notes with it

@export var notes: Array[Dictionary] = []

## absolute path of rendered wav for the engine, empty until rendered
## the engine plays it via add_audio_clip(wav_path, clip.start)
var wav_path := ""

## true when notes changed since the last render
var notes_dirty := true
