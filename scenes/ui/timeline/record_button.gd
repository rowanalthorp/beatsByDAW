extends Button

@export var cache_folder := "res://cache/recordings/"

var active := false
var record_effect: AudioEffectRecord
var mic_player: AudioStreamPlayer


func _on_pressed() -> void:
	active = !active
	
	if active:
		if record_effect and not record_effect.is_recording_active():
			record_effect.set_recording_active(true)
		text = "Stop"
	else:
		text = "Mic"
		if record_effect and record_effect.is_recording_active():
			var recording: AudioStreamWAV = record_effect.get_recording()
			record_effect.set_recording_active(false)
			
			if recording:
				var fp := cache_folder.path_join("track_%d.wav" % Time.get_unix_time_from_system()) # change this later
				if (recording.save_to_wav(fp) == OK):
					print("Recording is Saved")
				else:
					print("CRAP REcording of Mic Failed")

func _ready() -> void:
	var bus_idx := AudioServer.get_bus_index("Record")
	if bus_idx == -1:
		bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, "Record")
		AudioServer.set_bus_mute(bus_idx, true)

	if AudioServer.get_bus_effect_count(bus_idx) == 0:
		record_effect = AudioEffectRecord.new()
		AudioServer.add_bus_effect(bus_idx, record_effect)
	else:
		record_effect = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectRecord
	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "Record"
	mic_player.autoplay = true
	add_child(mic_player)
		
