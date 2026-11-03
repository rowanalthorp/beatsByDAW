extends PanelContainer
## bottom bar: tempo, snap, the playback time and play state


func _ready() -> void:
	Transport.position_changed.connect(_on_position_changed)
	Transport.playing_changed.connect(_on_playing_changed)
	_on_position_changed(Transport.position)


## shows minutes:seconds.milliseconds, like 01:05.250.
func _on_position_changed(seconds: float) -> void:
	%TimeLabel.text = "%02d:%06.3f" % [floori(seconds / 60.0), fmod(seconds, 60.0)]
	_update_state()


func _on_playing_changed(_playing: bool) -> void:
	_update_state()


func _update_state() -> void:
	if Transport.playing:
		%StateLabel.text = "Playing"
	elif Transport.position == 0.0:
		%StateLabel.text = "Stopped"
	else:
		%StateLabel.text = "Paused"
