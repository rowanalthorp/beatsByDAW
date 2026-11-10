class_name PianoSynth
extends AudioStreamPlayer
## Synthesized piano
## Each note is a sum of decaying harmonics with a fast attack

const MIX_RATE := 44100.0
const MAX_VOICES := 16

var _voices: Array[Dictionary] = []


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.15
	stream = gen
	play()


func note_on(pitch: int, velocity: float = 1.0) -> void:
	# Retriggering a held pitch fades the old voice out instead of stacking
	for v in _voices:
		if v.pitch == pitch and not v.releasing:
			v.releasing = true
	if _voices.size() >= MAX_VOICES:
		_voices.remove_at(0)
	_voices.append(NoteRenderer.make_voice(pitch, velocity, 1.0 / MIX_RATE))


func note_off(pitch: int) -> void:
	for v in _voices:
		if v.pitch == pitch and not v.releasing:
			v.releasing = true


func all_notes_off() -> void:
	_voices.clear()


func _process(_delta: float) -> void:
	var playback := get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var dt := 1.0 / MIX_RATE
	var frames := playback.get_frames_available()
	for i in frames:
		var s := 0.0
		for v in _voices:
			s += NoteRenderer.sample_voice(v, dt)
		s = tanh(s) # soft clip so chords don't distort
		playback.push_frame(Vector2(s, s))
	for i in range(_voices.size() - 1, -1, -1):
		if _voices[i].dead:
			_voices.remove_at(i)
