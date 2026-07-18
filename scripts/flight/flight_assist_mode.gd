class_name FlightAssistMode
extends RefCounted

const OFF: float = 0.0
const LIMITED: float = 0.75
const UNLIMITED: float = 1.0

const OFF_NAME_KEY: StringName = &"UI_FLIGHT_ASSIST_MODE_OFF"
const LIMITED_NAME_KEY: StringName = &"UI_FLIGHT_ASSIST_MODE_LIMITED"
const UNLIMITED_NAME_KEY: StringName = &"UI_FLIGHT_ASSIST_MODE_UNLIMITED"
const UNLIMITED_DESCRIPTION_KEY: StringName = &"UI_FLIGHT_ASSIST_MODE_UNLIMITED_DESCRIPTION"


static func get_presets() -> Array[float]:
	return [OFF, LIMITED, UNLIMITED]


static func get_nearest_preset_index(assist_strength: float) -> int:
	var presets: Array[float] = get_presets()
	var safe_strength: float = clampf(assist_strength, 0.0, 1.0)
	var nearest_index: int = 0
	var nearest_distance: float = INF
	for index: int in presets.size():
		var distance: float = absf(presets[index] - safe_strength)
		if distance < nearest_distance:
			nearest_index = index
			nearest_distance = distance
	return nearest_index


static func get_display_name_key(assist_strength: float) -> StringName:
	match get_nearest_preset_index(assist_strength):
		0:
			return OFF_NAME_KEY
		1:
			return LIMITED_NAME_KEY
	return UNLIMITED_NAME_KEY


static func get_description_key(assist_strength: float) -> StringName:
	if get_nearest_preset_index(assist_strength) == 2:
		return UNLIMITED_DESCRIPTION_KEY
	return &""
