class_name CargoDefinition
extends Resource

enum BoostPolicy {
	ALLOWED,
	LIMITED,
	FORBIDDEN,
}

@export var id: StringName = &""
@export var display_name_key: StringName = &""
@export var company_description_key: StringName = &""
@export var story_description_key: StringName = &""
@export var boost_policy: BoostPolicy = BoostPolicy.ALLOWED
@export_range(0.0, 1.0, 0.01) var collision_tolerance: float = 1.0
@export var attraction_risk_tags: Array[StringName] = []
