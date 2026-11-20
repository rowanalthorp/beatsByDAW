extends Node
## turns the clips on the timeline into sound. while the clock (Transport) runs, every frame
## it works out which clips are under the playhead and makes sure exactly those are playing, each
## from the right spot in its sound. uses godot's own AudioStreamPlayers for now. only _start_sound and
## _stop_sound touch them, so swapping in rowan's engine later only changes those two

var _players: Dictionary[ClipData, AudioStreamPlayer] = {} # clips sounding right now -> the player for each


func _ready() -> void:
	Transport.playing_changed.connect(_on_playing_changed)
	# after a jump or an edit, the players that are going are at the wrong spot (or for a clip that's
	# gone). easiest fix is to stop everything, and the next frame starts the right ones from the right spot
	Transport.seeked.connect(_stop_all.unbind(1))
	Session.song_length_changed.connect(_stop_all) # a clip got moved, trimmed, deleted, pasted...
	Session.project_changed.connect(_stop_all.unbind(1))


func _process(_delta: float) -> void:
	if not Transport.playing:
		return
	var now := Transport.position
	# solo on any track means only the soloed tracks get heard
	var any_solo := Session.project.tracks.any(func(track: TrackData) -> bool: return track.solo)
	var heard: Array[ClipData] = []
	for track: TrackData in Session.project.tracks:
		if track.muted or (any_solo and not track.solo):
			continue
		for clip: ClipData in track.clips:
			if now < clip.start or now >= clip.end:
				continue
			if not _players.has(clip):
				var stream := clip.get_stream()
				if stream == null:
					continue # plain clip with nothing to play
				# how far into the sound we are: the hidden bit at the front (offset) plus how far into the clip the playhead is
				_players[clip] = _start_sound(stream, clip.offset + now - clip.start)
			heard.append(clip)
			_players[clip].volume_db = track.volume_db # every frame, so dragging the slider is heard right away
	# anything still going that shouldnt be anymore: the clip ended, got muted, or another track got soloed
	for clip: ClipData in _players.keys():
		if not clip in heard:
			_stop_sound(clip)


## pressing play renders any instrument clips that changed up front. otherwise the render would happen
## right when the playhead reaches the clip, and the frame it takes could make the sound stutter
func _on_playing_changed(playing: bool) -> void:
	if not playing:
		_stop_all()
		return
	for track: TrackData in Session.project.tracks:
		for clip: ClipData in track.clips:
			clip.get_stream()


func _stop_all() -> void:
	for clip: ClipData in _players.keys():
		_stop_sound(clip)


## plays stream starting from_seconds into it
func _start_sound(stream: AudioStream, from_seconds: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.play(from_seconds)
	return player


func _stop_sound(clip: ClipData) -> void:
	_players[clip].stop()
	_players[clip].queue_free()
	_players.erase(clip)
