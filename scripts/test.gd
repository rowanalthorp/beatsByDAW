extends Node

func _ready() -> void:
	# This function is simply to test if the .gdextention for cpp is working
		if test_cpp_instance():
			test_audio_engine()
		pass
func test_cpp_instance():
	if ClassDB.class_exists("TestCPP"):
		var test_instance = TestCPP.new()
		print("C++ is working")
		test_instance.queue_free()
		return true
	else:
		print("error, need the cpp to work")
		return false
func test_audio_engine():
	# TODO: add a sega like start audio for this testing, so that know it works by the audio actually playing
	var audio_engine = AudioEngine.new()
	add_child(audio_engine)
	var file_path = ProjectSettings.globalize_path("res://test_audio.wav")
	var result = audio_engine.start_audio(file_path)
	if result != 0:
		print("CRAP AUDIO FAILED!!!")
		audio_engine.queue_free()
		return
	print("Audio Device has gotten started")
	await get_tree().create_timer(1.0).timeout
	
	result = audio_engine.stop_audio()
	if result != 0:
		print("CRAP stopping audio failedd")
	else:
		print("SUCCEssFully stopped audio")
	audio_engine.queue_free()
