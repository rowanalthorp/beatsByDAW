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
	quit()
