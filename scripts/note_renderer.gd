class_name NoteRenderer

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

static func make_voice(pitch: int, velocity: float, dt: float) -> Dictionary:
	var tau := lerpf(2.4, 0.5, inverse_lerp(21.0, 108.0, float(pitch)))
	var amps := PackedFloat64Array()
	var decays := PackedFloat64Array()
	for p in PARTIALS:
		amps.append(p[1])
		decays.append(exp(-dt / (tau * p[2])))
	return {
		"pitch": pitch,
		"freq": 440.0 * pow(2.0, (pitch - 69) / 12.0),
		"t": 0.0,
		"rel_t": 0.0,
		"vel": velocity,
		"releasing": false,
		"dead": false,
		"amps": amps,
		"decays": decays,
	}

static func sample_voice(v: Dictionary, dt: float) -> float:
	v.t += dt
	# Low notes ring longer than high notes
	var env := minf(v.t / ATTACK, 1.0)
	if v.releasing:
		v.rel_t += dt
		env *= exp(-v.rel_t / RELEASE)
		if env < 0.001:
			v.dead = true
	if v.t > MAX_VOICE_AGE:
		v.dead = true
	var s := 0.0
	for j in PARTIALS.size():
		v.amps[j] *= v.decays[j]
		s += v.amps[j] * sin(TAU * v.freq * PARTIALS[j][0] * v.t)
	return s * env * v.vel * MASTER_GAIN

static func render_note(pitch: int, velocity: float, duration_seconds: float) -> AudioStreamWAV:
	var sample_rate := 44100
	var dt := 1.0 / sample_rate
	var release_seconds := RELEASE * log(1000.0)
	var held_samples := maxi(1, roundi(duration_seconds * sample_rate))
	var total_samples := held_samples + ceili(release_seconds * sample_rate)
	var voice := make_voice(pitch, velocity, dt)
	var data := PackedByteArray()
	data.resize(total_samples * 2)
	for i in total_samples:
		if i == held_samples:
			voice.releasing = true
		var sample_value := tanh(sample_voice(voice, dt))
		data.encode_s16(i * 2, roundi(sample_value * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav
## beats × seconds/beat × samples/second = samples
static func render_pattern(notes: Array[Dictionary], length_beats: float, bpm: float) -> AudioStreamWAV:
	var sample_rate := 44100
	var dt := 1.0 / sample_rate
	var seconds_per_beat := 60.0 / bpm
	var release_seconds := RELEASE * log(1000.0)
	var scheduled: Array[Dictionary] = []
	for note in notes:
		var start_sample := roundi(float(note.start) * seconds_per_beat * sample_rate)
		var held_samples := maxi(1, roundi(float(note.length) * seconds_per_beat * sample_rate))
		scheduled.append({
			"start_sample": start_sample,
			"end_sample": start_sample + held_samples,
			"voice": make_voice(int(note.pitch), float(note.velocity), dt),
		})

	var pattern_samples := maxi(1, roundi(length_beats * seconds_per_beat * sample_rate))
	var total_samples := pattern_samples + ceili(release_seconds * sample_rate)
	var data := PackedByteArray()
	data.resize(total_samples * 2)

	for i in total_samples:
		var mixed_sample := 0.0
		for event in scheduled:
			if i < event.start_sample:
				continue
			var voice: Dictionary = event.voice
			if voice.dead:
				continue
			if i >= event.end_sample:
				voice.releasing = true
			mixed_sample += sample_voice(voice, dt)
		data.encode_s16(i * 2, roundi(tanh(mixed_sample) * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav