extends Node
## playback clock. fake for now: time just counts up in _process.
## when audio engine is added, play/pause/seek forward to it and the position
## gets read back from it. the signals stay the same, so the ui wont change

signal playing_changed(playing: bool)
signal position_changed(seconds: float)

var playing: bool = false
var position: float = 0.0  ## seconds from the start of the song


func _process(delta: float) -> void:
	if playing:
		seek(position + delta)


func play() -> void:
	if not playing:
		playing = true
		playing_changed.emit(true)


func pause() -> void:
	if playing:
		playing = false
		playing_changed.emit(false)


func toggle_play() -> void:
	if playing:
		pause()
	else:
		play()


## pause and jump back to the start.
func stop() -> void:
	pause()
	seek(0.0)


func seek(seconds: float) -> void:
	# shoulnt receive any negatives, but just to be sure sset a lower bound of zero
	position = maxf(seconds, 0.0)
	position_changed.emit(position)
