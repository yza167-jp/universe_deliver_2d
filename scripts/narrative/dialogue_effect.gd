class_name DialogueEffect
extends Resource

enum EffectType {
	SET_STORY_FLAG,
	EMIT_FLOW_EVENT,
}

@export var effect_type: EffectType = EffectType.SET_STORY_FLAG
@export var effect_id: StringName = &""
@export var bool_value: bool = true
