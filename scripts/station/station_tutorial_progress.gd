class_name StationTutorialProgress
extends RefCounted

enum Requirement {
	MOVE,
	LAO_PI_INTERACTION,
	ORDER_TERMINAL_INTERACTION,
	COMPLETE,
}

const LAO_PI_INTERACTION_ID: StringName = &"lao_pi"
const ORDER_TERMINAL_INTERACTION_ID: StringName = &"order_terminal"

var _requirement: Requirement = Requirement.MOVE
var _movement_completed: bool = false
var _lao_pi_interacted: bool = false
var _order_terminal_interacted: bool = false


func _init(already_completed: bool = false) -> void:
	if already_completed:
		_movement_completed = true
		_lao_pi_interacted = true
		_order_terminal_interacted = true
		_requirement = Requirement.COMPLETE


func record_movement(distance: float, required_distance: float) -> bool:
	var previous_requirement: Requirement = _requirement
	if distance >= maxf(required_distance, 0.0):
		_movement_completed = true
	_advance_requirements()
	return _requirement != previous_requirement


func record_interaction(interaction_id: StringName) -> bool:
	var previous_requirement: Requirement = _requirement
	match interaction_id:
		LAO_PI_INTERACTION_ID:
			_lao_pi_interacted = true
		ORDER_TERMINAL_INTERACTION_ID:
			_order_terminal_interacted = true
	_advance_requirements()
	return _requirement != previous_requirement


func get_requirement() -> Requirement:
	return _requirement


func has_completed_movement() -> bool:
	return _movement_completed


func has_interacted_with_lao_pi() -> bool:
	return _lao_pi_interacted


func has_inspected_order_terminal() -> bool:
	return _order_terminal_interacted


func is_complete() -> bool:
	return _requirement == Requirement.COMPLETE


func _advance_requirements() -> void:
	var should_continue: bool = true
	while should_continue:
		should_continue = false
		match _requirement:
			Requirement.MOVE:
				if _movement_completed:
					_requirement = Requirement.LAO_PI_INTERACTION
					should_continue = true
			Requirement.LAO_PI_INTERACTION:
				if _lao_pi_interacted:
					_requirement = Requirement.ORDER_TERMINAL_INTERACTION
					should_continue = true
			Requirement.ORDER_TERMINAL_INTERACTION:
				if _order_terminal_interacted:
					_requirement = Requirement.COMPLETE
					should_continue = true
