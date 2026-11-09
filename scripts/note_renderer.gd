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

static func make_voice(pitch: int, velocity: float) -> Dictionary:
	return {
    	"pitch": pitch,
		"freq": 440.0 * pow(2.0, (pitch - 69) / 12.0),
		"t": 0.0,
		"rel_t": 0.0,
		"vel": velocity,
		"releasing": false,
		"dead": false,
    }

static func sample_voice(v: Dictionary, dt: float) -> float:
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