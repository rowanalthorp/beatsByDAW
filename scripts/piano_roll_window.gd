extends Window
## Popup window with the piano roll editor.


func _ready() -> void:
	close_requested.connect(hide)
