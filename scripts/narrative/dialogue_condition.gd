class_name DialogueCondition
extends Resource

enum ConditionType {
	STORY_FLAG_EQUALS,
	SHIP_MODULE_EQUIPPED,
	ENTRY_STYLE_EQUALS,
	CARGO_INTEGRITY_AT_LEAST,
}

@export var condition_type: ConditionType = ConditionType.STORY_FLAG_EQUALS
@export var flag_id: StringName = &""
@export var module_id: StringName = &""
@export var entry_style: StringName = &""
@export_range(0.0, 100.0, 1.0) var cargo_integrity_threshold: float = 80.0
@export var expected_value: bool = true


func is_met(game_state: GameStateModel) -> bool:
	if game_state == null:
		return false

	match condition_type:
		ConditionType.STORY_FLAG_EQUALS:
			if flag_id.is_empty():
				return false
			return game_state.has_story_flag(flag_id) == expected_value
		ConditionType.SHIP_MODULE_EQUIPPED:
			if module_id.is_empty():
				return false
			return game_state.is_ship_module_equipped(module_id) == expected_value
		ConditionType.ENTRY_STYLE_EQUALS:
			if not FlightStyleTracker.is_valid_style(entry_style):
				return false
			return game_state.has_order_entry_style(entry_style)
		ConditionType.CARGO_INTEGRITY_AT_LEAST:
			var run_state: OrderRunState = game_state.get_active_order_run_state()
			if run_state == null:
				return false
			var meets_threshold: bool = (
				run_state.cargo_integrity >= cargo_integrity_threshold
			)
			return meets_threshold == expected_value
		_:
			return false
