class_name DemoProject
## fake song so the screen has content before import is a thing
## delete once we can open files


static func create() -> ProjectData:
	var project := ProjectData.new()
	project.name = "Demo"
	project.add_track(_track("Drums", TrackData.Kind.AUDIO, [["Beat", 0.0, 8.0], ["Fill", 9.0, 4.0]]))
	project.add_track(_track("Vocals", TrackData.Kind.AUDIO, [["Verse", 2.0, 10.0]]))
	# keys is an instrument track, so its clip holds notes instead of pointing at audio.
	# C, F, G, C chords, one bar each (4 bars = 8s at 120 bpm)
	var keys := _track("Keys", TrackData.Kind.INSTRUMENT, [])
	keys.add_clip(_note_clip("Chords", 0.0, 8.0, [
		[60, 0.0, 4.0], [64, 0.0, 4.0], [67, 0.0, 4.0],
		[65, 4.0, 4.0], [69, 4.0, 4.0], [72, 4.0, 4.0],
		[67, 8.0, 4.0], [71, 8.0, 4.0], [74, 8.0, 4.0],
		[60, 12.0, 4.0], [64, 12.0, 4.0], [67, 12.0, 4.0],
	]))
	project.add_track(keys)
	project.add_track(_track("Test", TrackData.Kind.AUDIO, [["Test", 20.0, 30.0]]))
	return project


## clip_specs: [[Name, Start, Length], ...]
static func _track(track_name: String, kind: TrackData.Kind, clip_specs: Array) -> TrackData:
	var track := TrackData.new()
	track.name = track_name
	track.kind = kind
	for spec in clip_specs:
		var clip := ClipData.new()
		clip.name = spec[0]
		clip.start = spec[1]
		clip.length = spec[2]
		track.add_clip(clip)
	return track


## note_specs: [[pitch, start beat, length in beats], ...]. pitch is a MIDI number, 60 = middle C
static func _note_clip(clip_name: String, start: float, length: float, note_specs: Array) -> NoteClipData:
	var clip := NoteClipData.new()
	clip.name = clip_name
	clip.start = start
	clip.length = length
	for spec in note_specs:
		# same dictionary shape kris's piano roll uses, so it can edit these directly
		clip.notes.append({"pitch": spec[0], "start": spec[1], "length": spec[2], "velocity": 1.0})
	return clip
