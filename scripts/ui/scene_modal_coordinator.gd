class_name SceneModalCoordinator
extends Node

signal modal_state_changed(is_modal_active: bool)

@export var player_path: NodePath = NodePath("../StationPlayer")
@export var managed_control_paths: Array[NodePath] = []

var _player: StationPlayer
var _managed_controls: Array[Control] = []
var _active_modal_ids: Dictionary[StringName, bool] = {}
var _managed_requested_visibility: Dictionary[Control, bool] = {}
var _player_input_was_enabled: bool = true
var _player_prompt_was_suppressed: bool = false
var _applying_managed_visibility: bool = false


func _ready() -> void:
	_player = get_node_or_null(player_path) as StationPlayer
	if _player == null:
		push_error("Scene modal coordinator could not resolve its StationPlayer.")
		return
	for control_path: NodePath in managed_control_paths:
		var control: Control = get_node_or_null(control_path) as Control
		if control == null:
			push_error(
				"Scene modal coordinator could not resolve managed control '%s'."
				% control_path
			)
			continue
		_managed_controls.append(control)
		if not control.visibility_changed.is_connected(
			_on_managed_visibility_changed.bind(control)
		):
			control.visibility_changed.connect(
				_on_managed_visibility_changed.bind(control)
			)


## Acquires one world-input lock; repeated acquisition by the same source is ignored.
func begin_modal(modal_id: StringName) -> bool:
	if modal_id.is_empty() or _active_modal_ids.has(modal_id) or _player == null:
		return false
	var was_modal_active: bool = is_modal_active()
	_active_modal_ids[modal_id] = true
	if was_modal_active:
		return true

	_player_input_was_enabled = _player.is_input_enabled()
	_player_prompt_was_suppressed = _player.is_interaction_prompt_suppressed()
	_player.set_interaction_prompt_suppressed(true)
	_player.set_input_enabled(false)
	_managed_requested_visibility.clear()
	for control: Control in _managed_controls:
		_managed_requested_visibility[control] = control.visible
		_set_managed_control_visible(control, false)
	modal_state_changed.emit(true)
	return true


## Releases one source and restores world input only after the final modal closes.
func end_modal(modal_id: StringName) -> bool:
	if modal_id.is_empty() or not _active_modal_ids.has(modal_id):
		return false
	_active_modal_ids.erase(modal_id)
	if is_modal_active():
		return true

	_player.set_input_enabled(_player_input_was_enabled)
	_player.set_interaction_prompt_suppressed(_player_prompt_was_suppressed)
	for control: Control in _managed_controls:
		_set_managed_control_visible(
			control,
			_managed_requested_visibility.get(control, control.visible)
		)
	_managed_requested_visibility.clear()
	modal_state_changed.emit(false)
	return true


func is_modal_active() -> bool:
	return not _active_modal_ids.is_empty()


func has_modal(modal_id: StringName) -> bool:
	return _active_modal_ids.has(modal_id)


func get_active_modal_count() -> int:
	return _active_modal_ids.size()


func _on_managed_visibility_changed(control: Control) -> void:
	if (
		_applying_managed_visibility
		or not is_modal_active()
		or control == null
	):
		return
	_managed_requested_visibility[control] = control.visible
	if control.visible:
		_set_managed_control_visible(control, false)


func _set_managed_control_visible(control: Control, should_be_visible: bool) -> void:
	if control == null or control.visible == should_be_visible:
		return
	_applying_managed_visibility = true
	control.visible = should_be_visible
	_applying_managed_visibility = false
