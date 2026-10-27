extends Window
## Popup window with the piano roll editor and piano instrument.
## Play/stop transport and schedules notes on the synth.

const BPM := 120.0

var _synth: PianoSynth
var _playing := false
var _playhead := 0.0
var _sounding: Array[bool] = []

@onready var _roll: PianoRoll = $VBox/Scroll/PianoRoll
@onready var _play_button: Button = $VBox/Toolbar/PlayButton
@onready var _clear_button: Button = $VBox/Toolbar/ClearButton


func _ready() -> void:
	close_requested.connect(_on_close_requested)

	_synth = PianoSynth.new()
	add_child(_synth)

	_roll.preview_note_on.connect(_synth.note_on)
	_roll.preview_note_off.connect(_synth.note_off)
	_play_button.pressed.connect(_toggle_play)
	_clear_button.pressed.connect(_roll.clear_notes)


func _toggle_play() -> void:
	_playing = not _playing
	_play_button.text = "Stop" if _playing else "Play"
	_playhead = 0.0
	_sounding.clear()
	_synth.all_notes_off()
	_roll.show_playhead = _playing
	_roll.queue_redraw()


func _on_close_requested() -> void:
	if _playing:
		_toggle_play()
	hide()


func _process(delta: float) -> void:
	if not _playing:
		return
	var total := float(PianoRoll.BARS * PianoRoll.BEATS_PER_BAR)
	_playhead += delta * BPM / 60.0
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
