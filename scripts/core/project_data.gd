class_name ProjectData
extends Resource
## Just a stub matching what I see in Brett's branch. Delete this when merged.

@export var name: String = "Untitled"
@export_range(20.0, 300.0) var bpm: float = 120.0:
    set(value):
        bpm = clampf(value, 20.0, 300.0)
        emit_changed()
@export var beats_per_bar: int = 4