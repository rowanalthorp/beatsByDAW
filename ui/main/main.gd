extends Control

const MIN_WINDOW_SIZE := Vector2i(1024, 576)

# StringName instead of String because actions are converted to StringNames anyways, and this is technically more efficient
const SHORTCUT_ACTIONS: Array[StringName] = [
	&"play_pause", &"go_to_start", &"go_to_end",
	&"delete_selected", &"zoom_in", &"zoom_out", &"zoom_fit",
]

# enum since we will prob get more entries with zooming in, out, and expanding
enum ViewMenuId { LIGHT_THEME }

var _dark_theme: Theme
var _light_theme: Theme  # built the first time it's turned on

func _ready() -> void:
	get_window().min_size = MIN_WINDOW_SIZE
	_dark_theme = theme # set dark theme to the default start up theme
	var view_menu: PopupMenu = %View
	view_menu.id_pressed.connect(_on_view_menu_id_pressed)

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

func _on_view_menu_id_pressed(id: int) -> void:
	if id == ViewMenuId.LIGHT_THEME:
		var view_menu: PopupMenu = %View
		var index := view_menu.get_item_index(id)
		# PopupMenu doesnt tick its own checkboxes, so toggle it here
		var light_on := not view_menu.is_item_checked(index)
		view_menu.set_item_checked(index, light_on)
		_toggle_light_theme(light_on)

# toggle between light and dark mode
func _toggle_light_theme(on: bool) -> void:
	if on and _light_theme == null:
		_light_theme = ThemeTools.make_light(_dark_theme)
	theme = _light_theme if on else _dark_theme
	# the window background behind the panels isn't part of the theme (and we gotta change that too)
	var clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	RenderingServer.set_default_clear_color(ThemeTools.flip(clear) if on else clear)
