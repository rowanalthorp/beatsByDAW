extends Node
## editor state shared by the whole ui: the open project, how the timeline is shown (zoom, scroll),
## what's selected, and the clip edits (split, cut, copy, paste...)

signal project_changed(project: ProjectData)
## something about how the timeline is shown changed (ruler mode, zoom or scroll)
signal view_changed
## a clip was double-clicked and wants its editor opened (piano roll for instrument clips)
signal open_clip_requested(clip: ClipData)
## a different clip or track got clicked (or the clip got deselected)
signal selection_changed
## a clip was moved or deleted, so the song might be a different length now
signal song_length_changed
## a track's Effects button was pressed and wants the sidebar opened for it
signal effects_requested(track: TrackData)
## the Import Audio button or menu item was pressed and wants the file picker opened
signal import_requested

const MIN_ZOOM := 2.0 # px per second. all the way out, a 5 min song is ~600px wide
const MAX_ZOOM := 1000.0 # px per second. all the way in, one beat at 120 bpm is 500px
const ZOOM_STEP := 1.25 # each zoom press multiplies/divides by this

var project: ProjectData = ProjectData.new()

## zoom: how many pixels wide one second of the project is
var pixels_per_second: float = 40.0:
	set(value):
		# clamp so you cant zoom in or out forever
		pixels_per_second = clampf(value, MIN_ZOOM, MAX_ZOOM)
		view_changed.emit()

## ruler shows minutes:seconds (like audacity) instead of bars (like ableton)
var show_seconds: bool = false:
	set(value):
		show_seconds = value
		view_changed.emit()

## horizontal scroll: the song time (in seconds) at the left edge of the lanes
var scroll_seconds: float = 0.0:
	set(value):
		scroll_seconds = maxf(value, 0.0) # cant scroll to before the song starts
		view_changed.emit()

## how many px wide the visible lane area is. timeline keeps this up to date so zoom to fit knows how much room there is
var lane_width: float = 0.0

## the clip that was clicked last. null means nothing is selected
var selected_clip: ClipData = null:
	set(value):
		selected_clip = value
		if value:
			selected_track = _track_of(value) # clicking a clip selects its track too
		selection_changed.emit()

## the track paste goes to. clicking empty lane space or a clip on a track selects it. null = none yet
var selected_track: TrackData = null:
	set(value):
		selected_track = value
		selection_changed.emit()

## when on, dragged clips land on the nearest beat. the checkbox in the bottom bar sets this
var snap_to_beat: bool = false

## the undo steps. each one holds the song from before and after an edit
var history := UndoRedo.new()

var _clipboard: ClipData = null # copy of the last cut/copied clip. null until something gets copied
var _clipboard_track: TrackData = null # where it was copied from, so paste has a track when nothing's selected


## UndoRedo isnt a node, so it has to be freed by hand
func _exit_tree() -> void:
	history.free()


#region Project

func open_project(new_project: ProjectData) -> void:
	project = new_project
	history.clear_history() # the old project's undo steps dont belong to this one
	project_changed.emit(project)


## adds an empty track at the bottom, named like "Audio 3" or something
func add_new_track(kind: TrackData.Kind) -> void:
	var before := snapshot()
	project.add_track(make_track(kind))
	save_undo_step("Add Track", before)


## the track's Delete button. undo brings it back with its clips
func remove_track(track: TrackData) -> void:
	var before := snapshot()
	project.remove_track(track)
	if selected_track == track:
		selected_track = null
	save_undo_step("Delete Track", before)


## a new empty track that isnt added yet, so import can add it in the same undo step as their clip
func make_track(kind: TrackData.Kind) -> TrackData:
	var track := TrackData.new()
	track.kind = kind
	var label := "Audio" if kind == TrackData.Kind.AUDIO else "Instrument"
	track.name = "%s %d" % [label, project.tracks.size() + 1]
	return track

#endregion


#region View

## multiply instead of add so every press feels the same size,
## +10 px/s would be huge at 20 px/s but do basically nothing at 800
func zoom_in() -> void:
	pixels_per_second *= ZOOM_STEP


func zoom_out() -> void:
	pixels_per_second /= ZOOM_STEP


## zoom so the whole song fits on screen, and scroll back to the start
func zoom_to_fit() -> void:
	var length := project.get_length()
	if length <= 0.0 or lane_width <= 0.0:
		return # empty song, or the timeline hasnt been laid out yet. nothing to fit
	scroll_seconds = 0.0
	# 95% of the width so the last clip isnt jammed right against the edge
	pixels_per_second = lane_width * 0.95 / length

#endregion


#region Signal relays

## godot was giving a warning if I didn't emit the signal this way so
func request_open_clip(clip: ClipData) -> void:
	open_clip_requested.emit(clip)


## same warning thing as request_open_clip
func request_effects(track: TrackData) -> void:
	effects_requested.emit(track)


## same warning thing as request_open_clip
func request_import() -> void:
	import_requested.emit()


## clip_view calls this when a drag/trim ends, so the whole drag is one undo step. same warning thing as request_open_clip
func report_clip_moved(clip: ClipData, before: Dictionary, action_name: String) -> void:
	clear_under(clip)
	song_length_changed.emit()
	save_undo_step(action_name, before)

#endregion


#region Clip editing

## rounds a time (seconds) to the nearest beat if snap is on, otherwise gives it back untouched.
## one beat is 60 / bpm seconds, snappedf rounds to the nearest multiple of that
func snap(seconds: float) -> float:
	if not snap_to_beat:
		return seconds
	return snappedf(seconds, 60.0 / project.bpm)


## takes the selected clip off whatever track its on
func delete_selected(action_name: String = "Delete Clip") -> void:
	if selected_clip == null:
		return
	var before := snapshot()
	for track: TrackData in project.tracks:
		if selected_clip in track.clips:
			track.remove_clip(selected_clip)
			break
	# clear it even if no track had it (its track might have been deleted already)
	selected_clip = null
	song_length_changed.emit()
	save_undo_step(action_name, before)


## cuts the selected clip in two at the playhead. the original becomes the left half, and the right
## half is a copy trimmed up to the playhead (so whats inside stays put). nothing happens if the
## playhead isnt inside the clip
func split_selected() -> void:
	var clip := selected_clip
	var at := Transport.position
	if clip == null or at <= clip.start or at >= clip.end:
		return
	var track := _track_of(clip)
	if track == null:
		return

	var before := snapshot()
	var right_half := clip.split_at(at)
	track.add_clip(right_half)
	selected_clip = right_half
	save_undo_step("Split Clip", before)


## keeps a copy of the selected clip for paste. a copy and not the clip itself, so changing or
## deleting the original afterwards doesnt change what gets pasted
func copy_selected() -> void:
	if selected_clip == null:
		return
	_clipboard = selected_clip.duplicate(true)
	_clipboard_track = _track_of(selected_clip)


func cut_selected() -> void:
	copy_selected()
	delete_selected("Cut Clip")


## puts a copy of the clipboard at the playhead, on the selected track
## (or the track it was copied from if no track has been picked yet)
func paste() -> void:
	if _clipboard == null:
		return
	var track: TrackData = selected_track if selected_track else _clipboard_track
	if track == null or not track in project.tracks:
		return # the track got deleted since
	# note clips only go on instrument tracks and audio clips only on audio tracks
	if (_clipboard is NoteClipData) != (track.kind == TrackData.Kind.INSTRUMENT):
		return
	var before := snapshot()
	# copy again so pasting twice gives two separate clips, not the same one twice
	var clip := _clipboard.duplicate(true) as ClipData
	clip.start = Transport.position
	track.add_clip(clip)
	clear_under(clip) # the pasted clip wins, anything it lands on gets cut away
	selected_clip = clip
	song_length_changed.emit() # pasting past the end makes the song longer
	save_undo_step("Paste Clip", before)


## a copy of the selected clip placed right after it, on the same track
func duplicate_selected() -> void:
	if selected_clip == null:
		return
	var track := _track_of(selected_clip)
	if track == null:
		return
	var before := snapshot()
	var copy := selected_clip.duplicate(true) as ClipData
	copy.start = selected_clip.end
	track.add_clip(copy)
	clear_under(copy) # the copy wins, anything it lands on gets cut away
	selected_clip = copy
	song_length_changed.emit()
	save_undo_step("Duplicate Clip", before)


## makes "clip" win over any other clip its sitting on top of on the same track: the covered parts of
## the others get cut away (trimmed, split around it, or deleted if fully covered). two clips stacked
## on one track would both play at once
func clear_under(clip: ClipData) -> void:
	var track := _track_of(clip)
	if track == null:
		return
	# loop over a copy, since this adds/removes clips from the real list as it goes
	for other: ClipData in track.clips.duplicate():
		if other == clip or other.end <= clip.start or other.start >= clip.end:
			continue # itself, or not touching it
		if other.start >= clip.start and other.end <= clip.end:
			track.remove_clip(other) # completely covered
		elif other.start < clip.start and other.end > clip.end:
			# sticks out both sides: split off the part after, then cut the part before short
			track.add_clip(other.split_at(clip.end))
			other.length = clip.start - other.start
		elif other.start < clip.start:
			other.length = clip.start - other.start # sticks out on the left, cut its end off
		else:
			other.trim_start_to(clip.end) # sticks out on the right, cut its start off


## puts an audio file on the timeline as a new clip at the playhead. it goes on the selected track if
## that's an audio track, otherwise it gets a new audio track of its own
func import_audio(path: String) -> void:
	var clip := AudioClipData.from_file(path)
	if clip == null:
		return # not a file godot can read, from_file already printed why
	var before := snapshot()
	var track := selected_track
	# the selected track might have been deleted since, same check as paste
	if track == null or track.kind != TrackData.Kind.AUDIO or not track in project.tracks:
		track = make_track(TrackData.Kind.AUDIO)
		project.add_track(track)
	clip.start = Transport.position
	track.add_clip(clip)
	clear_under(clip) # the imported clip wins, same as paste
	selected_clip = clip
	song_length_changed.emit() # a long file can make the song longer
	save_undo_step("Import Audio", before)

#endregion


#region Undo and redo

func undo() -> void:
	history.undo()


func redo() -> void:
	history.redo()


## copy of the song for undo: tempo, tracks with their settings, and where each clip sits. the tracks and
## clips themselves arent copied, so undo puts the same ones back and the ui showing them stays hooked up
func snapshot() -> Dictionary:
	var tracks: Array[Dictionary] = []
	for track: TrackData in project.tracks:
		var clips: Array[Dictionary] = []
		for clip: ClipData in track.clips:
			clips.append(_clip_snapshot(clip))
		tracks.append({
			track = track,
			name = track.name,
			volume_db = track.volume_db,
			pan = track.pan,
			muted = track.muted,
			solo = track.solo,
			effects = track.effects.duplicate(),
			clips = clips,
		})
	return {bpm = project.bpm, tracks = tracks}


## saves one undo step from before to now, skipped if nothing changed. merge squashes a slider drag into one step
func save_undo_step(action_name: String, before: Dictionary, merge: bool = false) -> void:
	var after := snapshot()
	if after == before:
		return
	history.create_action(action_name, UndoRedo.MERGE_ENDS if merge else UndoRedo.MERGE_DISABLE)
	history.add_do_method(_restore.bind(after))
	history.add_undo_method(_restore.bind(before))
	history.commit_action(false) # false since the edit already happened

#endregion


## one clip for snapshot(). note clips copy their notes too, since trims and splits actually delete notes
func _clip_snapshot(clip: ClipData) -> Dictionary:
	var values := {clip = clip, name = clip.name, start = clip.start, length = clip.length, offset = clip.offset}
	if clip is NoteClipData:
		values.notes = (clip as NoteClipData).notes.duplicate(true) # true = deep copy
	return values


## puts the song back the way it was in a snapshot()
func _restore(saved: Dictionary) -> void:
	project.bpm = saved.bpm
	var saved_tracks: Array[TrackData] = []
	for values: Dictionary in saved.tracks:
		saved_tracks.append(values.track)
	# drop tracks that werent there yet, then put missing ones back in their old spot
	for track: TrackData in project.tracks.duplicate():
		if not track in saved_tracks:
			project.remove_track(track)
	for i in saved.tracks.size():
		var values: Dictionary = saved.tracks[i]
		var track: TrackData = values.track
		# before re-adding, so its row gets built with the right clips
		_restore_track(track, values)
		if not track in project.tracks:
			project.add_track(track, i)
	# cant keep something selected that just got taken away
	if selected_clip and _track_of(selected_clip) == null:
		selected_clip = null
	if selected_track and not selected_track in project.tracks:
		selected_track = null
	song_length_changed.emit()


func _restore_track(track: TrackData, values: Dictionary) -> void:
	track.name = values.name
	track.volume_db = values.volume_db
	track.pan = values.pan
	track.muted = values.muted
	track.solo = values.solo
	if track.effects != values.effects:
		track.set_effects(values.effects)
	var saved_clips: Array[ClipData] = []
	for clip_values: Dictionary in values.clips:
		saved_clips.append(clip_values.clip)
	# same as the tracks: drop new clips, bring back missing ones
	for clip: ClipData in track.clips.duplicate():
		if not clip in saved_clips:
			track.remove_clip(clip)
	for clip_values: Dictionary in values.clips:
		var clip: ClipData = clip_values.clip
		_restore_clip(clip, clip_values) # values first so it shows up in the right spot
		if not clip in track.clips:
			track.add_clip(clip)


func _restore_clip(clip: ClipData, values: Dictionary) -> void:
	clip.name = values.name
	clip.start = values.start
	clip.length = values.length
	clip.offset = values.offset
	if values.has("notes"):
		var note_clip := clip as NoteClipData
		# assign so the piano roll keeps the same array, copied so later edits dont touch the saved notes
		var saved_notes: Array = values.notes
		note_clip.notes.assign(saved_notes.duplicate(true))
		note_clip.notes_dirty = true


## the track a clip is on, or null if its not on one (like its track got deleted)
func _track_of(clip: ClipData) -> TrackData:
	for track: TrackData in project.tracks:
		if clip in track.clips:
			return track
	return null
