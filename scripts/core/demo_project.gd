class_name DemoProject
## fake song so the screen has content before import is a thing
## delete once we can open files


static func create() -> ProjectData:
	var project := ProjectData.new()
	project.name = "Demo"
	project.add_track(_track("Drums", TrackData.Kind.AUDIO, [["Beat", 0.0, 8.0], ["Fill", 9.0, 4.0]]))
	project.add_track(_track("Vocals", TrackData.Kind.AUDIO, [["Verse", 2.0, 10.0]]))
	project.add_track(_track("Keys", TrackData.Kind.AUDIO, [["Chords", 0.0, 12.0]]))
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
	
