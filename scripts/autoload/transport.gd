extends Node
## playback clock. while rowan's audio engine is playing something, the position is read from it
## (through Playback), so the playhead matches what's actually heard. when it isn't (nothing to play,
## or everything already played to the end) time just counts up in _process

signal playing_changed(playing: bool)
signal position_changed(seconds: float)
## the clock jumped somewhere (ruler click, to start/end, stop), instead of just ticking forward
signal seeked(seconds: float)

var playing: bool = false
var position: float = 0.0  ## seconds from the start of the song


func _process(delta: float) -> void:
	if not playing:
		return
	var engine_time := Playback.get_engine_time()
	if engine_time >= 0.0:
		_set_position(engine_time)
	else:
		_set_position(position + delta)


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
	_set_position(seconds)
	seeked.emit(position)


## the ticking forward in _process goes through here too, but that's not a jump, so no seeked
func _set_position(seconds: float) -> void:
	# shouldnt receive any negatives, but just to be sure set a lower bound of zero
	position = maxf(seconds, 0.0)
	position_changed.emit(position)
