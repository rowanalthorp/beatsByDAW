extends Control

## Temporary button for the piano roll window.
## To be replaced with the actual main when available.

const PIANO_ROLL_WINDOW := preload("res://scenes/piano_roll_window.tscn")

var _piano_window: Window


func _ready() -> void:
	$Center/OpenPianoRoll.pressed.connect(_open_piano_roll)


func _open_piano_roll() -> void:
	if _piano_window == null:
		_piano_window = PIANO_ROLL_WINDOW.instantiate()
		add_child(_piano_window)
	_piano_window.popup_centered()
