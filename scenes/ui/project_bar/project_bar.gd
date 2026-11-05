extends PanelContainer
## bottom bar: tempo, snap, the playback time and play state

var _project: ProjectData # the project whose changed signal is connected


func _ready() -> void:
	Transport.position_changed.connect(_on_position_changed)
	Transport.playing_changed.connect(_on_playing_changed)
	_on_position_changed(Transport.position)
	%TempoSpin.value_changed.connect(_on_tempo_changed)
	Session.project_changed.connect(_on_project_changed)
	_on_project_changed(Session.project)


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


## same swap as timeline.gd and ruler.gd: stop listening to the old project, listen to the new one
func _on_project_changed(project: ProjectData) -> void:
	if _project:
		_project.changed.disconnect(_show_tempo)
	_project = project
	_project.changed.connect(_show_tempo) # bpm changed somewhere else (like the piano roll), so update the box
	_show_tempo()


## typing in the box sets the song tempo. the ruler already redraws on project.changed so it follows on its own
func _on_tempo_changed(value: float) -> void:
	_project.bpm = value


func _show_tempo() -> void:
	# no_signal so filling in the box doesnt fire value_changed and set the bpm all over again
	%TempoSpin.set_value_no_signal(_project.bpm)
