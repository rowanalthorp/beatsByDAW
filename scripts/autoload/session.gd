extends Node
## editor state which is shared by the whole ui. for now: the open project

signal project_changed(project: ProjectData)

var project: ProjectData = ProjectData.new()
## Zoom: how many pixels wide one second of the project is
var pixels_per_second: float = 40.0

func open_project(new_project: ProjectData) -> void:
	project = new_project
	project_changed.emit(project)
