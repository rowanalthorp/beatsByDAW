extends SceneTree

func _initialize() -> void:
	var notes: Array[Dictionary] = [
		{"pitch": 60, "start": 0.0, "length": 2.0, "velocity": 0.8},
		{"pitch": 64, "start": 1.0, "length": 2.0, "velocity": 0.8},
		{"pitch": 60, "start": 1.5, "length": 2.0, "velocity": 0.8},
	]
	var wav := NoteRenderer.render_pattern(notes, 4.0, 120.0)
	var result := wav.save_to_wav("user://test_note_render.wav")
	print("Save result: ", result)
	print(ProjectSettings.globalize_path("user://test_note_renderer.wav"))

	# native c++ path stub renders a 440 Hz sine for 1 second
	var native_data: PackedByteArray = PianoRenderer.render_note(60, 1.0, 1.0, 44100)
	var native_wav: AudioStreamWAV = AudioStreamWAV.new()
	native_wav.format = AudioStreamWAV.FORMAT_16_BITS
	native_wav.mix_rate = 44100
	native_wav.stereo = false
	native_wav.data = native_data
	print("Native save: ", native_wav.save_to_wav("user://native_sine.wav"))
	print(ProjectSettings.globalize_path("user://native_sine.wav"))

	quit()
