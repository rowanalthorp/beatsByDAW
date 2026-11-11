class_name PianoRollWindow
extends Window
## Popup window with the piano roll editor and piano instrument.
## Play/stop transport and schedules notes on the synth.

var _synth: PianoSynth

var _stream_player: AudioStreamPlayer

var _playing := false
var _playhead := 0.0

# the song's real project instead of a private one, so the tempo matches the main window
var _project: ProjectData:
	get:
		return Session.project

@onready var _roll: PianoRoll = $VBox/Scroll/PianoRoll
@onready var _play_button: Button = $VBox/Toolbar/PlayButton
@onready var _bpm_spin: SpinBox = $VBox/Toolbar/BpmSpin
@onready var _clear_button: Button = $VBox/Toolbar/ClearButton


func _ready() -> void:
	close_requested.connect(_on_close_requested)

	# Realtime Preview
	_synth = PianoSynth.new()
	add_child(_synth)

	# Rendered playback
	_stream_player = AudioStreamPlayer.new()
	add_child(_stream_player)


	_roll.preview_note_on.connect(_synth.note_on)
	_roll.preview_note_off.connect(_synth.note_off)
	_play_button.pressed.connect(_toggle_play)
	_clear_button.pressed.connect(_roll.clear_notes)

	_roll.beats_per_bar = _project.beats_per_bar
	_bpm_spin.value = _project.bpm
	_bpm_spin.value_changed.connect(func(v): _project.bpm = v)


func _toggle_play() -> void:
	_playing = not _playing
	_play_button.text = "Stop" if _playing else "Play"
	if _playing:
		var pattern_beats := float(_roll.bars * _roll.beats_per_bar)
		var seconds_per_beat := 60.0 / _project.bpm
		var wav := NoteRenderer.render_pattern(_roll.notes, pattern_beats, _project.bpm)
		# only loop the pattern end not the buffer, 
		# so release doesn't add a gap to each repetition
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = roundi(pattern_beats * seconds_per_beat * wav.mix_rate)
		_stream_player.stream = wav
		_stream_player.play()
	else:
		_stream_player.stop()
		_synth.all_notes_off()
	_playhead = 0.0
	_roll.show_playhead = _playing
	_roll.queue_redraw()

func _on_close_requested() -> void:
	if _playing:
		_toggle_play()
	hide()


func _process(_delta: float) -> void:
	if not _playing:
		return
	_playhead = _stream_player.get_playback_position() / (60.0 / _project.bpm)
	_roll.playhead_beat = _playhead
	_roll.queue_redraw()


## opens the window editing this clip's notes. the roll gets the clip's own notes array (same array, not a copy),
## so every note placed, moved or deleted is saved straight into the clip
func open_clip(clip: NoteClipData) -> void:
	if _playing:
		_toggle_play()
	title = "Piano Roll - " + clip.name
	_roll.notes = clip.notes
	_roll.beats_per_bar = _project.beats_per_bar
	# enough bars to cover the whole clip. seconds per bar = 60 / bpm * beats per bar
	var bar_seconds := 60.0 / _project.bpm * _project.beats_per_bar
	_roll.bars = ceili(clip.length / bar_seconds)
	_bpm_spin.set_value_no_signal(_project.bpm) # tempo may have changed in the bottom bar since last open
	_roll.queue_redraw()
	# size the window to fit the toolbar and the clip's bars, so theres no empty grey past the last bar
	var toolbar_width: float = $VBox/Toolbar.get_combined_minimum_size().x
	var roll_width := _roll.custom_minimum_size.x + 16.0 # + room for the vertical scroll bar
	var wanted := Vector2i(int(maxf(toolbar_width, roll_width)), 660)
	# clamped version shrinks it to at most 85% of the main window if it doesnt fit,
	# so the title bar stays on screen instead of popping out the top
	popup_centered_clamped(wanted, 0.85)
