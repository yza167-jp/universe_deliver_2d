class_name StationModalCoordinator
extends Node

signal modal_state_changed(is_modal_active: bool)

var _player: StationPlayer
var _objective_root: Control
var _active_modal_ids: Dictionary[StringName, bool] = {}
var _player_input_was_enabled: bool = true
var _objective_requested_visible: bool = false
var _applying_objective_visibility: bool = false


func _ready() -> void:
	_player = get_node_or_null("../StationPlayer") as StationPlayer
	_objective_root = get_node_or_null(
		"../TutorialUILayer/TutorialObjective"
	) as Control
	if _player == null or _objective_root == null:
		push_error("Station modal coordinator could not resolve the player or objective HUD.")
		return
	if not _objective_root.visibility_changed.is_connected(_on_objective_visibility_changed):
		_objective_root.visibility_changed.connect(_on_objective_visibility_changed)


## Opens one modal source without duplicating locks when the same source retries.
func begin_modal(modal_id: StringName) -> bool:
	if modal_id.is_empty() or _active_modal_ids.has(modal_id):
		return false
	var was_modal_active: bool = is_modal_active()
	_active_modal_ids[modal_id] = true
	if was_modal_active:
		return true
	if _player != null:
		_player_input_was_enabled = _player.is_input_enabled()
		_player.set_interaction_prompt_suppressed(true)
		_player.set_input_enabled(false)
	if _objective_root != null:
		_objective_requested_visible = _objective_root.visible
		_set_objective_visible(false)
	modal_state_changed.emit(true)
	return true


## Releases one modal source and restores the world only after the final source closes.
func end_modal(modal_id: StringName) -> bool:
	if modal_id.is_empty() or not _active_modal_ids.has(modal_id):
		return false
	_active_modal_ids.erase(modal_id)
	if is_modal_active():
		return true
	if _player != null:
		_player.set_input_enabled(_player_input_was_enabled)
		_player.set_interaction_prompt_suppressed(false)
	if _objective_root != null:
		_set_objective_visible(_objective_requested_visible)
	modal_state_changed.emit(false)
	return true


func is_modal_active() -> bool:
	return not _active_modal_ids.is_empty()


func has_modal(modal_id: StringName) -> bool:
	return _active_modal_ids.has(modal_id)


func get_active_modal_count() -> int:
	return _active_modal_ids.size()


func _on_objective_visibility_changed() -> void:
	if _applying_objective_visibility or not is_modal_active() or _objective_root == null:
		return
	_objective_requested_visible = _objective_root.visible
	if _objective_root.visible:
		_set_objective_visible(false)


func _set_objective_visible(should_be_visible: bool) -> void:
	if _objective_root == null or _objective_root.visible == should_be_visible:
		return
	_applying_objective_visibility = true
	_objective_root.visible = should_be_visible
	_applying_objective_visibility = false
