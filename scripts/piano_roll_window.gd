class_name PianoRollWindow
extends Window
## Popup window with the piano roll editor and piano instrument.
## Play/stop transport and schedules notes on the synth.

var _synth: PianoSynth
var _playing := false
var _playhead := 0.0
var _sounding: Array[bool] = []
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

	_synth = PianoSynth.new()
	add_child(_synth)

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
	_playhead = 0.0
	_roll.show_playhead = _playing # show the red line only while playing
	_sounding.clear()
	_synth.all_notes_off()
	_roll.queue_redraw()


func _on_close_requested() -> void:
	if _playing:
		_toggle_play()
	hide()


func _process(delta: float) -> void:
	if not _playing:
		return
	var total := float(_roll.bars * _roll.beats_per_bar)
	_playhead += delta * _project.bpm / 60.0
	if _playhead >= total:
		_playhead -= total
		_synth.all_notes_off()
		_sounding.clear()
	if _sounding.size() != _roll.notes.size():
		_sounding.resize(_roll.notes.size())
	for i in _roll.notes.size():
		var n := _roll.notes[i]
		var on: bool = _playhead >= n.start and _playhead < n.start + n.length
		if on and not _sounding[i]:
			_sounding[i] = true
			_synth.note_on(n.pitch, n.velocity)
		elif not on and _sounding[i]:
			_sounding[i] = false
			_synth.note_off(n.pitch)
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
