class_name DialogueCondition
extends Resource

enum ConditionType {
	STORY_FLAG_EQUALS,
}

@export var condition_type: ConditionType = ConditionType.STORY_FLAG_EQUALS
@export var flag_id: StringName = &""
@export var expected_value: bool = true


func is_met(game_state: GameStateModel) -> bool:
	if game_state == null or flag_id.is_empty():
		return false

	match condition_type:
		ConditionType.STORY_FLAG_EQUALS:
			return game_state.has_story_flag(flag_id) == expected_value
		_:
			return false
