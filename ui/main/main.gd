extends Control

const MIN_WINDOW_SIZE := Vector2i(1024, 576)
# StringName instead of String because actions are converted to StringNames anyways, and this is technically more efficient
const SHORTCUT_ACTIONS: Array[StringName] = [
	&"play_pause", &"go_to_start", &"go_to_end",
	&"delete_selected", &"zoom_in", &"zoom_out", &"zoom_fit",
]

func _ready() -> void:
	get_window().min_size = MIN_WINDOW_SIZE

## runs whenever any input is pressed
func _input(event: InputEvent) -> void:
	# if the input is not one being looked for, or its done while typing, ignore
	if not event is InputEventKey or _is_typing():
		return
	for action: StringName in SHORTCUT_ACTIONS:
		if event.is_action_pressed(action):
			# stop the input from being used for anything else than shortcut
			get_viewport().set_input_as_handled()
			_on_shortcut(action)
			return


## returns if the user is currently typing in a text box
func _is_typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit

## placeholder func when shortcuts are pressed
func _on_shortcut(action: StringName) -> void:
	print("Shortcut: ", action)
