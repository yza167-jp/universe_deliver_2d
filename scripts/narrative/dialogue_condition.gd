class_name DialogueCondition
extends Resource

enum ConditionType {
	STORY_FLAG_EQUALS,
	SHIP_MODULE_EQUIPPED,
}

@export var condition_type: ConditionType = ConditionType.STORY_FLAG_EQUALS
@export var flag_id: StringName = &""
@export var module_id: StringName = &""
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
		_:
			return false
