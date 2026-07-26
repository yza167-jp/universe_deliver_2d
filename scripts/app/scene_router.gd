class_name SceneRouterService
extends Node

## Owns stage scene lifecycle only; order, narrative, and flight rules stay outside the router.
signal stage_changed(previous_stage: int, current_stage: int)
signal transition_rejected(current_stage: int, requested_stage: int, reason: String)

enum Stage {
	MAIN_MENU,
	STATION,
	COCKPIT,
	FLIGHT,
	ARRIVAL,
	RESULTS,
}

const INVALID_STAGE: int = -1

var current_stage: int = INVALID_STAGE
var last_error: String = ""

var _scene_container: Node
var _active_scene: Node


func register_scene_container(scene_container: Node) -> bool:
	if not is_instance_valid(scene_container):
		return _reject_transition(INVALID_STAGE, "Scene container is not valid.")
	if is_instance_valid(_scene_container) and _scene_container != scene_container:
		return _reject_transition(INVALID_STAGE, "A different scene container is already registered.")

	_scene_container = scene_container
	last_error = ""
	return true


func unregister_scene_container(scene_container: Node) -> void:
	if _scene_container != scene_container:
		return

	_scene_container = null
	_active_scene = null
	current_stage = INVALID_STAGE
	last_error = ""


func start() -> bool:
	if current_stage != INVALID_STAGE:
		return _reject_transition(Stage.MAIN_MENU, "Scene flow has already started.")
	return _change_stage(Stage.MAIN_MENU)


func request_stage(requested_stage: int) -> bool:
	if not is_valid_stage(requested_stage):
		return _reject_transition(requested_stage, "Requested stage is not defined.")
	if current_stage == INVALID_STAGE:
		return _reject_transition(requested_stage, "Scene flow has not started.")
	if not is_transition_allowed(current_stage, requested_stage):
		return _reject_transition(
			requested_stage,
			"Transition %s -> %s is not allowed."
			% [get_stage_name(current_stage), get_stage_name(requested_stage)]
		)

	return _change_stage(requested_stage)


## Production scene override for content whose destination owns a dedicated scene.
func request_stage_scene(requested_stage: int, scene_path: String) -> bool:
	if not is_valid_stage(requested_stage):
		return _reject_transition(requested_stage, "Requested stage is not defined.")
	if current_stage == INVALID_STAGE:
		return _reject_transition(requested_stage, "Scene flow has not started.")
	if not is_transition_allowed(current_stage, requested_stage):
		return _reject_transition(
			requested_stage,
			"Transition %s -> %s is not allowed."
			% [get_stage_name(current_stage), get_stage_name(requested_stage)]
		)
	if not _is_valid_project_scene_path(scene_path):
		return _reject_transition(
			requested_stage,
			"Requested production scene path is invalid."
		)
	return _change_stage(requested_stage, scene_path)


## Development-only escape hatch for opening any M0 stage without replaying the full flow.
func debug_switch_to_stage(requested_stage: int) -> bool:
	if not OS.is_debug_build():
		return _reject_transition(requested_stage, "Direct stage switching is debug-only.")
	if not is_valid_stage(requested_stage):
		return _reject_transition(requested_stage, "Requested debug stage is not defined.")
	return _change_stage(requested_stage)


## Debug-only scene override keeps isolated labs available after a stage gains real content.
func debug_switch_to_stage_scene(requested_stage: int, scene_path: String) -> bool:
	if not OS.is_debug_build():
		return _reject_transition(requested_stage, "Direct stage switching is debug-only.")
	if not is_valid_stage(requested_stage):
		return _reject_transition(requested_stage, "Requested debug stage is not defined.")
	if not _is_valid_project_scene_path(scene_path):
		return _reject_transition(requested_stage, "Requested debug scene path is invalid.")
	return _change_stage(requested_stage, scene_path)


static func get_all_stages() -> PackedInt32Array:
	return PackedInt32Array([
		Stage.MAIN_MENU,
		Stage.STATION,
		Stage.COCKPIT,
		Stage.FLIGHT,
		Stage.ARRIVAL,
		Stage.RESULTS,
	])


static func is_valid_stage(stage: int) -> bool:
	return stage >= Stage.MAIN_MENU and stage <= Stage.RESULTS


static func is_transition_allowed(from_stage: int, to_stage: int) -> bool:
	match from_stage:
		Stage.MAIN_MENU:
			return to_stage == Stage.STATION
		Stage.STATION:
			return to_stage == Stage.COCKPIT
		Stage.COCKPIT:
			return to_stage == Stage.FLIGHT
		Stage.FLIGHT:
			return to_stage == Stage.ARRIVAL
		Stage.ARRIVAL:
			return to_stage == Stage.RESULTS
		Stage.RESULTS:
			return to_stage == Stage.STATION
		_:
			return false


static func get_stage_name(stage: int) -> String:
	match stage:
		Stage.MAIN_MENU:
			return "MAIN_MENU"
		Stage.STATION:
			return "STATION"
		Stage.COCKPIT:
			return "COCKPIT"
		Stage.FLIGHT:
			return "FLIGHT"
		Stage.ARRIVAL:
			return "ARRIVAL"
		Stage.RESULTS:
			return "RESULTS"
		_:
			return "INVALID"


static func get_stage_scene_path(stage: int) -> String:
	match stage:
		Stage.MAIN_MENU:
			return "res://scenes/app/main_menu.tscn"
		Stage.STATION:
			return "res://scenes/station/station_hub.tscn"
		Stage.COCKPIT:
			return "res://scenes/cockpit/cockpit.tscn"
		Stage.FLIGHT:
			return "res://scenes/flight/flight_level.tscn"
		Stage.ARRIVAL:
			return "res://scenes/arrival/red_sand_arrival.tscn"
		Stage.RESULTS:
			return "res://scenes/app/results.tscn"
		_:
			return ""


func _change_stage(requested_stage: int, scene_path_override: String = "") -> bool:
	if not is_instance_valid(_scene_container):
		return _reject_transition(requested_stage, "No scene container is registered.")

	var scene_path: String = (
		scene_path_override
		if not scene_path_override.is_empty()
		else get_stage_scene_path(requested_stage)
	)
	var scene_resource: Resource = load(scene_path)
	var packed_scene: PackedScene = scene_resource as PackedScene
	if packed_scene == null:
		return _reject_transition(requested_stage, "Stage scene could not be loaded: %s" % scene_path)

	var next_scene: Node = packed_scene.instantiate()
	var previous_stage: int = current_stage
	_release_active_scene()
	_scene_container.add_child(next_scene)
	_active_scene = next_scene
	current_stage = requested_stage
	last_error = ""
	stage_changed.emit(previous_stage, current_stage)
	return true


func _release_active_scene() -> void:
	if not is_instance_valid(_active_scene):
		_active_scene = null
		return

	var old_scene: Node = _active_scene
	var was_inside_tree: bool = old_scene.is_inside_tree()
	if old_scene.get_parent() == _scene_container:
		_scene_container.remove_child(old_scene)
	_active_scene = null

	if was_inside_tree:
		old_scene.queue_free()
	else:
		old_scene.free()


func _reject_transition(requested_stage: int, reason: String) -> bool:
	last_error = reason
	transition_rejected.emit(current_stage, requested_stage, reason)
	return false


static func _is_valid_project_scene_path(scene_path: String) -> bool:
	return (
		scene_path.begins_with("res://")
		and scene_path.ends_with(".tscn")
		and ResourceLoader.exists(scene_path, "PackedScene")
	)
