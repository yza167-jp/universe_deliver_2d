class_name StationModalCoordinator
extends SceneModalCoordinator


func _init() -> void:
	player_path = NodePath("../StationPlayer")
	managed_control_paths = [
		NodePath("../TutorialUILayer/TutorialObjective"),
	]
