class_name OrderUnlockCondition
extends Resource

## Typed, data-driven acceptance gate. Evaluation is owned by GameState/M1 order rules.
enum ConditionType {
	PLANET_UNLOCKED,
	PERMISSION_GRANTED,
	MODULE_AVAILABLE,
}

@export var condition_type: ConditionType = ConditionType.PLANET_UNLOCKED
@export var reference_id: StringName = &""
