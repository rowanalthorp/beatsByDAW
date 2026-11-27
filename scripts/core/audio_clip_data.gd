class_name AudioClipData
extends ClipData
## a clip on an audio track that plays (part of) an audio file from the computer: wav or mp3.
## only the file's path gets saved with the clip, the sound itself is loaded from that path when needed

## full path to the audio file, like C:/Users/me/Music/kick.wav
@export var file_path: String = ""

# sounds already loaded, by file path. split, copy/paste and duplicate all make new clips that point
# at the same file, so they share one loaded copy instead of each loading the whole file again
static var _loaded_streams: Dictionary[String, AudioStream] = {}


## loads the file and makes a clip as long as the whole thing. null if godot couldnt read it
static func from_file(path: String) -> AudioClipData:
	var stream := _load_stream(path)
	if stream == null:
		return null
	var clip := AudioClipData.new()
	clip.file_path = path
	clip.name = path.get_file().get_basename() # "C:/Music/kick.wav" -> "kick"
	clip.length = stream.get_length()
	return clip


## the sound this clip plays. the whole file, offset and length decide which part of it gets heard
func get_stream() -> AudioStream:
	return _load_stream(file_path)


## files outside the project (res://) cant go through load(), since godot only imports what's in the
## project folder. each format has its own load_from_file instead
static func _load_stream(path: String) -> AudioStream:
	if _loaded_streams.has(path):
		return _loaded_streams[path]
	var stream: AudioStream = null
	match path.get_extension().to_lower():
		"wav":
			stream = AudioStreamWAV.load_from_file(path)
		"mp3":
			stream = AudioStreamMP3.load_from_file(path)
	if stream == null:
		push_error("couldnt load audio file: " + path)
		return null
	_loaded_streams[path] = stream
	return stream
