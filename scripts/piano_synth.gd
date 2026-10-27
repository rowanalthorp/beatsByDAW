class_name PianoSynth
extends AudioStreamPlayer
## Synthesized piano
## Each note is a sum of decaying harmonics with a fast attack

const MIX_RATE := 44100.0
const MAX_VOICES := 16
const ATTACK := 0.004
const RELEASE := 0.07
const MAX_VOICE_AGE := 8.0
const MASTER_GAIN := 0.3

## higher partials decay faster, like a real piano
const PARTIALS := [
	[1.0, 1.00, 1.00],
	[2.0, 0.45, 0.60],
	[3.0, 0.20, 0.40],
	[4.0, 0.10, 0.28],
	[5.0, 0.05, 0.20],
]

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
	_voices.append({
		"pitch": pitch,
		"freq": 440.0 * pow(2.0, (pitch - 69) / 12.0),
		"t": 0.0,
		"rel_t": 0.0,
		"vel": velocity,
		"releasing": false,
		"dead": false,
	})


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
			s += _sample_voice(v, dt)
		s = tanh(s) # soft clip so chords don't distort
		playback.push_frame(Vector2(s, s))
	for i in range(_voices.size() - 1, -1, -1):
		if _voices[i].dead:
			_voices.remove_at(i)


func _sample_voice(v: Dictionary, dt: float) -> float:
	v.t += dt
	# Low notes ring longer than high notes
	var tau := lerpf(2.4, 0.5, inverse_lerp(21.0, 108.0, float(v.pitch)))
	var env := minf(v.t / ATTACK, 1.0)
	if v.releasing:
		v.rel_t += dt
		env *= exp(-v.rel_t / RELEASE)
		if env < 0.001:
			v.dead = true
	if v.t > MAX_VOICE_AGE:
		v.dead = true
	var s := 0.0
	for p in PARTIALS:
		s += p[1] * sin(TAU * v.freq * p[0] * v.t) * exp(-v.t / (tau * p[2]))
	return s * env * v.vel * MASTER_GAIN
