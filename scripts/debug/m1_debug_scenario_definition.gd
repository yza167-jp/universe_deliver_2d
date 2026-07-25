class_name M1DebugScenarioDefinition
extends RefCounted

## Immutable-by-convention description of one isolated M1 development entry.

var scenario_id: StringName = &""
var chapter_id: StringName = &""
var unlocked_planet_ids: Array[StringName] = []
var focus_planet_id: StringName = &""
var catalog_focus_order_id: StringName = &""
var active_order_id: StringName = &""
var fixture_source_order_id: StringName = &""
var available_module_ids: Array[StringName] = []
var equipped_module_ids: Array[StringName] = []
var permission_ids: Array[StringName] = []
var relation_values: Dictionary[StringName, int] = {}
var starting_credits: int = 0
var completed_order_ids: Array[StringName] = []
var story_flag_ids: Array[StringName] = []
var revisit_states: Dictionary[StringName, StringName] = {}
var target_stage: int = SceneRouterService.Stage.STATION
var target_scene_path: String = ""
var preview_only: bool = true


func to_canonical_dictionary() -> Dictionary[String, Variant]:
	return {
		"scenario_id": String(scenario_id),
		"chapter_id": String(chapter_id),
		"unlocked_planet_ids": _sorted_strings(unlocked_planet_ids),
		"focus_planet_id": String(focus_planet_id),
		"catalog_focus_order_id": String(catalog_focus_order_id),
		"active_order_id": String(active_order_id),
		"fixture_source_order_id": String(fixture_source_order_id),
		"available_module_ids": _sorted_strings(available_module_ids),
		"equipped_module_ids": _sorted_strings(equipped_module_ids),
		"permission_ids": _sorted_strings(permission_ids),
		"relation_values": _sorted_integer_map(relation_values),
		"starting_credits": starting_credits,
		"completed_order_ids": _sorted_strings(completed_order_ids),
		"story_flag_ids": _sorted_strings(story_flag_ids),
		"revisit_states": _sorted_string_name_map(revisit_states),
		"target_stage": target_stage,
		"target_scene_path": target_scene_path,
		"preview_only": preview_only,
	}


static func _sorted_strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	result.sort()
	return result


static func _sorted_integer_map(
	values: Dictionary[StringName, int]
) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {}
	var keys: Array[StringName] = []
	for key: StringName in values:
		keys.append(key)
	keys.sort()
	for key: StringName in keys:
		result[String(key)] = values[key]
	return result


static func _sorted_string_name_map(
	values: Dictionary[StringName, StringName]
) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {}
	var keys: Array[StringName] = []
	for key: StringName in values:
		keys.append(key)
	keys.sort()
	for key: StringName in keys:
		result[String(key)] = String(values[key])
	return result
