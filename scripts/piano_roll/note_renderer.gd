class_name NoteRenderer

static func render_note(pitch: int, velocity: float, duration_seconds: float) -> AudioStreamWAV:
	var sample_rate := 44100
	var data := PianoRenderer.render_note(pitch, velocity, duration_seconds, sample_rate)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

static func render_pattern(notes: Array[Dictionary], length_beats: float, bpm: float) -> AudioStreamWAV:
	var sample_rate := 44100
	var data := PianoRenderer.render_pattern(notes, length_beats, bpm, sample_rate)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav
