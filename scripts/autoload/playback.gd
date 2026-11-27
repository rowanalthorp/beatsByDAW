extends Node
## turns the clips on the timeline into sound, through rowan's c++ audio engine (AudioEngine).
## the engine wants everything it'll play (tracks, clips, volumes) handed over before it starts, and
## can't take changes once it's running. so when something about the song changes during playback
## (a clip moved, a track muted, a jump somewhere else) the engine's copy gets thrown away and built
## again from the playhead. while it plays, the engine also keeps the clock, Transport reads it from here

## how long the song has to stay unchanged before the engine gets rebuilt. while a clip is dragged or a
## volume slider moves, it changes every frame, and rebuilding that often would just stutter
var rebuild_delay_msec := 150

# rowan's AudioEngine, or null when the c++ part isn't built on this computer. left untyped since
# the AudioEngine class only exists when it is built
var _engine = null
var _running := false # true while the engine is playing something
var _built_from: Array = [] # the song as it was last handed to the engine, from _mix()
var _waiting_mix: Array = [] # a newer version of the song that's waiting to settle before the rebuild
var _waiting_since := 0 # when _waiting_mix last changed, in msec


func _ready() -> void:
	# made through ClassDB instead of AudioEngine.new() so this script still loads without the engine
	# built. the timeline then just plays silent instead of the whole autoload failing
	if ClassDB.class_exists("AudioEngine"):
		_engine = ClassDB.instantiate("AudioEngine")
		add_child(_engine)
	else:
		push_warning("AudioEngine not found (c++ part not built?), playing without sound")
	Transport.playing_changed.connect(_on_playing_changed)
	Transport.seeked.connect(_on_seeked)


## checks every frame if the song changed since the engine got it. comparing against a snapshot
## catches every kind of edit (move, trim, split, delete, mute, solo, volume, tempo) without
## needing a signal for each one
func _process(_delta: float) -> void:
	if not Transport.playing:
		return
	var mix := _mix()
	if mix == _built_from:
		return
	if mix != _waiting_mix:
		_waiting_mix = mix
		_waiting_since = Time.get_ticks_msec()
	elif Time.get_ticks_msec() - _waiting_since >= rebuild_delay_msec:
		_rebuild()


## the engine's clock in seconds, or -1 when it isn't playing anything (nothing to play, or it all
## played to the end). its clock stops once the last clip ends, so Transport counts on its own then
func get_engine_time() -> float:
	if not _running or _engine.is_audio_finished():
		return -1.0
	return _engine.get_playback_time_seconds()


## pausing throws away the engine's copy of the song instead of pausing it, so play always starts
## fresh from wherever the playhead is by then. it also means no sound file is held open while
## paused, so instrument clips can render over their old file
func _on_playing_changed(playing: bool) -> void:
	if playing:
		_rebuild()
	else:
		_stop_engine()


## the engine can only jump while paused, so a jump during playback just builds it again from the new spot
func _on_seeked(_seconds: float) -> void:
	if Transport.playing:
		_rebuild()


## everything about the song the engine cares about: the tempo (instrument clips are rendered at it),
## then for each track that can be heard its volume and its clips with where they sit. no files get
## loaded or rendered here since it runs every frame. clips are compared as objects, so the
## start/offset/length next to each one are what catches a clip being moved or trimmed
func _mix() -> Array:
	# solo on any track means only the soloed tracks get heard
	var any_solo := Session.project.tracks.any(func(track: TrackData) -> bool: return track.solo)
	var mix: Array = [Session.project.bpm]
	for track: TrackData in Session.project.tracks:
		if track.muted or (any_solo and not track.solo):
			continue # tracks that can't be heard just don't get handed to the engine
		var clips: Array = []
		for clip: ClipData in track.clips:
			clips.append([clip, clip.start, clip.offset, clip.length])
		mix.append([track.volume_db, clips])
	return mix


## hands the engine the whole song as it is now and starts it from the playhead
func _rebuild() -> void:
	_stop_engine() # first, so no file is still open in the engine when an instrument clip renders over it
	_built_from = _mix()
	_waiting_mix = _built_from
	if _engine == null:
		return
	var clips_added := 0
	for heard: Array in _built_from.slice(1): # slice skips the tempo at the front
		var track_id: int = _engine.add_track()
		# the engine takes volume as a plain multiplier (1 = unchanged), not dB
		_engine.set_track_volume(track_id, db_to_linear(heard[0]))
		for part: Array in heard[1]:
			var clip: ClipData = part[0]
			var path := _sound_file(clip)
			if path.is_empty():
				continue
			# always passing the length (never the engine's -1 "to the end of the file") keeps it to the
			# part of the file the clip shows, same as offset does at the front
			if _engine.add_audio_clip_to_track(track_id, path, clip.start, clip.offset, clip.length):
				clips_added += 1
			else:
				push_error("engine couldnt load " + path)
	# the engine refuses to seek or start with nothing in it. the playhead still moves on its own then
	if clips_added == 0:
		return
	_engine.seek_audio(Transport.position)
	_running = _engine.start_audio_sources() == 0 # 0 means it worked (miniaudio's MA_SUCCESS)


## the file on disk the engine reads for this clip. audio clips point at the file that was imported,
## instrument clips get their notes rendered to a wav first (get_stream only re-renders if something
## changed). empty when there's nothing to play
func _sound_file(clip: ClipData) -> String:
	if clip is AudioClipData:
		return clip.file_path
	if clip is NoteClipData:
		clip.get_stream()
		return clip.wav_path
	return "" # plain clips like the demo ones have no sound behind them


func _stop_engine() -> void:
	if _engine != null:
		_engine.stop_audio() # also throws away every track and clip it was given
	_running = false
