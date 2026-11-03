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
	var file_path = ProjectSettings.globalize_path("res://test_audio_welcome_to_beatsByDaw.wav")
	if not audio_engine.add_audio_source(file_path):
		print("COULD not load the first audio file")
		audio_engine.queue_free()
		return
	if not audio_engine.add_audio_source(file_path):
		print("COULD not LOad the secodn audio file")
		audio_engine.queue_free()
		return
	var result = audio_engine.start_audio_sources()
	if result != 0:
		print("CRAP AUDIO FAILED!!!")
		audio_engine.stop_audio()
		audio_engine.queue_free()
		return
	print("Audio Device has gotten started")
	
	while not audio_engine.is_audio_finished():
		await get_tree().process_frame
	
	result = audio_engine.stop_audio()
	if result != 0:
		print("CRAP stopping audio failedd")
	else:
		print("SUCCEssFully stopped audio")
	audio_engine.queue_free()
