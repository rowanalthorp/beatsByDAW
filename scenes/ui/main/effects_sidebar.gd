extends PanelContainer
## right side panel for one track's effects. a track's Effects button opens it.
## only open/close for now, the effect list itself is obj 4 (the slots in it are mockups)

const EFFECT_SLOT_SCENE := preload("res://scenes/ui/effect_slot/effect_slot.tscn")

var _track: TrackData # whose effects are showing. null when closed
var _project: ProjectData # the project whose track_removed is connected


func _ready() -> void:
	hide()
	Session.effects_requested.connect(_on_effects_requested)
	Session.project_changed.connect(_on_project_changed)
	_on_project_changed(Session.project)
	%CloseButton.pressed.connect(close)
	%AddEffectButton.get_popup().id_pressed.connect(_on_add_effect_id_pressed)

func _on_effects_requested(track: TrackData) -> void:
	# pressing Effects again on the track that's already showing closes it, like a toggle
	if visible and track == _track:
		close()
		return
	_set_track(track)
	show()


func close() -> void:
	_set_track(null)
	hide()


## swaps which track the title follows. disconnect the old one first,
## or renaming a track we're not showing anymore would still change the title
func _set_track(track: TrackData) -> void:
	if _track:
		_track.changed.disconnect(_show_name)
		_track.effects_changed.disconnect(_show_effects)
	_track = track
	if _track:
		_track.changed.connect(_show_name) # renamed while open, so the title keeps up
		_track.effects_changed.connect(_show_effects) # added/removed an effect
		_show_name()
	_show_effects() # outside the if so closing (null) clears the slots too


func _show_name() -> void:
	%TrackName.text = "Effects: %s" % _track.name


## same swap as timeline.gd and project_bar.gd. a new project means the old track is gone too
func _on_project_changed(project: ProjectData) -> void:
	if _project:
		_project.track_removed.disconnect(_on_track_removed)
	_project = project
	_project.track_removed.connect(_on_track_removed)
	close()


## the track we're showing got deleted, nothing left to show
func _on_track_removed(track: TrackData) -> void:
	if track == _track:
		close()


## throws out the slots and makes one per effect on the current track.
## easier than working out which one changed, and a track only has a few effects
func _show_effects() -> void:
	for slot: Node in %EffectList.get_children():
		%EffectList.remove_child(slot) # out right away so old and new dont both show for a frame
		slot.queue_free()
	if _track == null:
		return
	for effect: EffectData in _track.effects:
		var slot := EFFECT_SLOT_SCENE.instantiate() as EffectSlot
		%EffectList.add_child(slot)
		slot.setup(effect)
		slot.remove_requested.connect(_track.remove_effect)


## the menu items are named the same as the types in EffectData, so the item text is the type
func _on_add_effect_id_pressed(id: int) -> void:
	var popup: PopupMenu = %AddEffectButton.get_popup()
	_track.add_effect(EffectData.create(popup.get_item_text(popup.get_item_index(id))))
