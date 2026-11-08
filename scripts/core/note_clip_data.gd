class_name NoteClipData
extends ClipData
## a clip on an instrument track: a normal clip that also holds the notes the piano roll edits.
## notes are in the piano roll's format {pitch, start, length, velocity}. start/length are in beats
## from the start of this clip (not the song), so moving the clip moves its notes with it

@export var notes: Array[Dictionary] = []
