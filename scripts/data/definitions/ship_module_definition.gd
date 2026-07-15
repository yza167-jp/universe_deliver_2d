class_name ShipModuleDefinition
extends Resource

enum SlotType {
	POWER,
	DEFENSE,
	UTILITY,
}

@export var id: StringName = &""
@export var display_name_key: StringName = &""
@export var description_key: StringName = &""
@export var slot_type: SlotType = SlotType.POWER
@export var stat_modifiers: Dictionary[StringName, float] = {}
@export var capability_tags: Array[StringName] = []
@export_range(0, 100000, 1, "or_greater") var cost: int = 0
@export var story_unlock_flags: Array[StringName] = []
