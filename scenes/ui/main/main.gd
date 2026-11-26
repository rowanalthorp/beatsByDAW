extends Control

enum FileMenuId { NEW, OPEN, SAVE, IMPORT_AUDIO, EXPORT }
# enum since we will prob get more entries with zooming in, out, and expanding
enum ViewMenuId { LIGHT_THEME, RULER_SECONDS }

const MIN_WINDOW_SIZE := Vector2i(1024, 576)
# StringName instead of String because actions are converted to StringNames anyways, and this is technically more efficient
const SHORTCUT_ACTIONS: Array[StringName] = [
	&"play_pause", &"go_to_start", &"go_to_end",
	&"delete_selected", &"zoom_in", &"zoom_out",
	&"zoom_fit", &"split", &"copy", &"cut", &"paste",
	&"duplicate"
]
const PIANO_ROLL_WINDOW := preload("res://scenes/piano_roll/piano_roll_window.tscn")

var _dark_theme: Theme
var _light_theme: Theme # built the first time it's turned on
var _piano_window: PianoRollWindow # made the first time an instrument clip is opened, then reused
var _import_dialog: FileDialog # made the first time Import Audio is pressed, then reused


func _ready() -> void:
	get_window().min_size = MIN_WINDOW_SIZE
	_dark_theme = theme # set dark theme to the default start up theme

	Session.open_clip_requested.connect(_on_open_clip_requested)
	Session.import_requested.connect(_on_import_requested)
	%File.id_pressed.connect(_on_file_menu_id_pressed)
	%View.id_pressed.connect(_on_view_menu_id_pressed)
	%Tracks.id_pressed.connect(_on_add_track_id_pressed)

	Session.open_project(DemoProject.create())


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


## func for when shortcuts are pressed
func _on_shortcut(action: StringName) -> void:
	match action:
		&"play_pause":
			Transport.toggle_play()
		&"go_to_start":
			Transport.seek(0.0)
		&"go_to_end":
			Transport.seek(Session.project.get_length())
		&"zoom_in":
			Session.zoom_in()
		&"zoom_out":
			Session.zoom_out()
		&"zoom_fit":
			Session.zoom_to_fit()
		&"delete_selected":
			Session.delete_selected()
		&"split":
			Session.split_selected()
		&"cut":
			Session.cut_selected()
		&"copy":
			Session.copy_selected()
		&"paste":
			Session.paste()
		&"duplicate":
			Session.duplicate_selected()
		_:
			print("Shortcut: ", action) # catch everything with no handler


## only Import Audio does something so far, the rest come with save/load and export
func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		FileMenuId.IMPORT_AUDIO:
			Session.request_import()


func _on_view_menu_id_pressed(id: int) -> void:
	var view_menu: PopupMenu = %View
	var index := view_menu.get_item_index(id)
	# PopupMenu doesnt tick its own checkboxes, so toggle it here
	var checked := not view_menu.is_item_checked(index)
	view_menu.set_item_checked(index, checked)
	match id:
		ViewMenuId.LIGHT_THEME:
			_toggle_light_theme(checked)
		ViewMenuId.RULER_SECONDS:
			Session.show_seconds = checked


# toggle between light and dark mode
func _toggle_light_theme(on: bool) -> void:
	if on and _light_theme == null:
		_light_theme = ThemeTools.make_light(_dark_theme)
	theme = _light_theme if on else _dark_theme
	# the window background behind the panels isn't part of the theme (and we gotta change that too)
	var clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	RenderingServer.set_default_clear_color(ThemeTools.flip(clear) if on else clear)


## item ids match TrackData.Kind: 0 = audio, 1 = instrument.
func _on_add_track_id_pressed(id: int) -> void:
	Session.add_new_track(id as TrackData.Kind)


## a clip was double-clicked: instrument clips open the piano roll, audio clip shenanigans come in later
func _on_open_clip_requested(clip: ClipData) -> void:
	var note_clip := clip as NoteClipData
	if note_clip == null:
		return
	if _piano_window == null:
		_piano_window = PIANO_ROLL_WINDOW.instantiate()
		# its own real OS window instead of being drawn inside the main one, so it can go anywhere on screen
		_piano_window.force_native = true
		add_child(_piano_window)
	_piano_window.open_clip(note_clip)


## opens the file picker. picking a file hands its path to Session.import_audio
func _on_import_requested() -> void:
	if _import_dialog == null:
		_import_dialog = FileDialog.new()
		_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_import_dialog.access = FileDialog.ACCESS_FILESYSTEM # anywhere on the computer, not just inside the project
		_import_dialog.filters = ["*.wav, *.mp3 ; Audio Files"]
		_import_dialog.use_native_dialog = true # windows' own file picker, so it looks like every other app's
		_import_dialog.file_selected.connect(Session.import_audio)
		add_child(_import_dialog)
	_import_dialog.popup_file_dialog()
