class_name TrackData
extends Resource
## one row of the timeline: its settings and the clips on it

signal clip_added(clip: ClipData)
signal clip_removed(clip: ClipData)
signal effects_changed # an effect was added or removed

enum Kind { AUDIO, INSTRUMENT }

@export var name: String = "Track":
	set(value):
		name = value
		emit_changed()
@export var kind: Kind = Kind.AUDIO
@export_range(-60.0, 6.0) var volume_db: float = 0.0:
	set(value):
		volume_db = value
		emit_changed()
@export_range(-1.0, 1.0) var pan: float = 0.0:
	set(value):
		pan = value
		emit_changed()
@export var muted: bool = false:
	set(value):
		muted = value
		emit_changed()
@export var solo: bool = false:
	set(value):
		solo = value
		emit_changed()
@export var clips: Array[ClipData] = []
@export var effects: Array[EffectData] = []


func add_clip(clip: ClipData) -> void:
	clips.append(clip)
	clip_added.emit(clip)


func remove_clip(clip: ClipData) -> void:
	clips.erase(clip)
	clip_removed.emit(clip)


func add_effect(effect: EffectData) -> void:
	effects.append(effect)
	effects_changed.emit()


func remove_effect(effect: EffectData) -> void:
	effects.erase(effect)
	effects_changed.emit()
