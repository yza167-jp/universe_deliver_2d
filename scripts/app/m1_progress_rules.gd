class_name M1ProgressRules
extends RefCounted

## Central M1 progression whitelist. It contains no mutable player state.

const CHAPTER_M0_RED_SAND_COMPLETE: StringName = &"chapter_m0_red_sand_complete"
const CHAPTER_M1_RED_SAND_REVISIT: StringName = &"chapter_m1_red_sand_revisit"
const CHAPTER_M1_WHITE_NOISE: StringName = &"chapter_m1_white_noise"
const CHAPTER_M1_CANOPY_WORLD: StringName = &"chapter_m1_canopy_world"
const CHAPTER_M1_TIDAL_ARCHIPELAGO: StringName = &"chapter_m1_tidal_archipelago"
const CHAPTER_M1_DEMO_EPILOGUE: StringName = &"chapter_m1_demo_epilogue"

const CHAPTER_SEQUENCE: Array[StringName] = [
	CHAPTER_M0_RED_SAND_COMPLETE,
	CHAPTER_M1_RED_SAND_REVISIT,
	CHAPTER_M1_WHITE_NOISE,
	CHAPTER_M1_CANOPY_WORLD,
	CHAPTER_M1_TIDAL_ARCHIPELAGO,
	CHAPTER_M1_DEMO_EPILOGUE,
]

const PLANET_RED_SAND: StringName = &"planet_red_sand"
const PLANET_WHITE_NOISE: StringName = &"planet_white_noise"
const PLANET_CANOPY_WORLD: StringName = &"planet_canopy_world"
const PLANET_TIDAL_ARCHIPELAGO: StringName = &"planet_tidal_archipelago"

const PLANET_IDS: Array[StringName] = [
	PLANET_RED_SAND,
	PLANET_WHITE_NOISE,
	PLANET_CANOPY_WORLD,
	PLANET_TIDAL_ARCHIPELAGO,
]

const PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS: StringName = (
	&"permission_white_noise_archive_access"
)
const PERMISSION_CANOPY_CORE_ROUTE: StringName = &"permission_canopy_core_route"
const PERMISSION_TIDAL_WEATHER_TOWER: StringName = &"permission_tidal_weather_tower"

const PERMISSION_IDS: Array[StringName] = [
	PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS,
	PERMISSION_CANOPY_CORE_ROUTE,
	PERMISSION_TIDAL_WEATHER_TOWER,
]

const MODULE_HIGH_VOLTAGE_SHIELDING: StringName = &"module_high_voltage_shielding"
const MODULE_BIOSIGNAL_ISOLATION: StringName = &"module_biosignal_isolation"
const MODULE_CROSSWIND_STABILIZER: StringName = &"module_crosswind_stabilizer"

const SHIP_UPGRADE_IDS: Array[StringName] = [
	MODULE_HIGH_VOLTAGE_SHIELDING,
	MODULE_BIOSIGNAL_ISOLATION,
	MODULE_CROSSWIND_STABILIZER,
]

const REVISIT_RED_SAND_AVAILABLE: StringName = &"revisit_red_sand_available"
const REVISIT_RED_SAND_MATERIALS_PENDING: StringName = (
	&"revisit_red_sand_materials_pending"
)
const REVISIT_RED_SAND_COMPLETED: StringName = &"revisit_red_sand_completed"

const RELATION_MINIMUM: int = -2
const RELATION_MAXIMUM: int = 3
const RELATION_EVENT_FLAG_PREFIX: String = "m1_relation_event/"

const REASON_ALREADY_CURRENT: StringName = &"already_current"
const REASON_ALREADY_UNLOCKED: StringName = &"already_unlocked"
const REASON_ALREADY_APPLIED: StringName = &"already_applied"
const REASON_ALREADY_GRANTED: StringName = &"already_granted"
const REASON_ALREADY_PRESENT: StringName = &"already_present"
const REASON_CHAPTER_NOT_INITIALIZED: StringName = &"chapter_not_initialized"
const REASON_CHAPTER_REGRESSION: StringName = &"chapter_regression"
const REASON_CHAPTER_SKIPPED: StringName = &"chapter_skipped"
const REASON_INVALID_CHAPTER: StringName = &"invalid_chapter"
const REASON_INVALID_PLANET: StringName = &"invalid_planet"
const REASON_INVALID_PERMISSION: StringName = &"invalid_permission"
const REASON_INVALID_CODEX_ENTRY: StringName = &"invalid_codex_entry"
const REASON_INVALID_SOUVENIR: StringName = &"invalid_souvenir"
const REASON_INVALID_REVISIT_STATE: StringName = &"invalid_revisit_state"
const REASON_INVALID_RELATION_EVENT: StringName = &"invalid_relation_event"
const REASON_RELATION_AT_LIMIT: StringName = &"relation_at_limit"
const REASON_REQUIRED_CHAPTER: StringName = &"required_chapter"
const REASON_REQUIRED_PLANET: StringName = &"required_planet"
const REASON_REQUIRED_MODULE: StringName = &"required_module"
const REASON_REQUIRED_PERMISSION: StringName = &"required_permission"
const REASON_REQUIRED_STORY_FLAG: StringName = &"required_story_flag"
const REASON_REQUIRED_COMPLETED_ORDER: StringName = &"required_completed_order"
const REASON_REQUIRED_CONTEXT: StringName = &"required_context"


class PlanetUnlockRule:
	extends RefCounted

	var planet_id: StringName = &""
	var minimum_chapter_id: StringName = &""
	var required_planet_ids: Array[StringName] = []
	var required_module_ids: Array[StringName] = []
	var required_permission_ids: Array[StringName] = []
	var required_story_flag_ids: Array[StringName] = []
	var required_completed_order_ids: Array[StringName] = []
	var required_context_ids: Array[StringName] = []


static func is_known_chapter(chapter_id: StringName) -> bool:
	return CHAPTER_SEQUENCE.has(chapter_id)


static func get_chapter_index(chapter_id: StringName) -> int:
	return CHAPTER_SEQUENCE.find(chapter_id)


static func has_reached_chapter(
	current_chapter_id: StringName,
	target_chapter_id: StringName
) -> bool:
	var current_index: int = get_chapter_index(current_chapter_id)
	var target_index: int = get_chapter_index(target_chapter_id)
	return current_index >= 0 and target_index >= 0 and current_index >= target_index


static func get_chapter_advance_reason(
	current_chapter_id: StringName,
	requested_chapter_id: StringName
) -> StringName:
	if not is_known_chapter(requested_chapter_id):
		return REASON_INVALID_CHAPTER
	if current_chapter_id.is_empty():
		return REASON_CHAPTER_NOT_INITIALIZED
	if not is_known_chapter(current_chapter_id):
		return REASON_INVALID_CHAPTER
	if current_chapter_id == requested_chapter_id:
		return REASON_ALREADY_CURRENT
	var current_index: int = get_chapter_index(current_chapter_id)
	var requested_index: int = get_chapter_index(requested_chapter_id)
	if requested_index < current_index:
		return REASON_CHAPTER_REGRESSION
	if requested_index > current_index + 1:
		return REASON_CHAPTER_SKIPPED
	return &""


static func is_known_planet(planet_id: StringName) -> bool:
	return PLANET_IDS.has(planet_id)


static func is_known_permission(permission_id: StringName) -> bool:
	return PERMISSION_IDS.has(permission_id)


static func is_known_ship_upgrade(module_id: StringName) -> bool:
	return SHIP_UPGRADE_IDS.has(module_id)


static func get_planet_unlock_rule(planet_id: StringName) -> PlanetUnlockRule:
	if not is_known_planet(planet_id):
		return null
	var rule: PlanetUnlockRule = PlanetUnlockRule.new()
	rule.planet_id = planet_id
	match planet_id:
		PLANET_RED_SAND:
			rule.minimum_chapter_id = CHAPTER_M0_RED_SAND_COMPLETE
		PLANET_WHITE_NOISE:
			rule.minimum_chapter_id = CHAPTER_M1_WHITE_NOISE
			rule.required_planet_ids = [PLANET_RED_SAND]
			rule.required_module_ids = [MODULE_HIGH_VOLTAGE_SHIELDING]
		PLANET_CANOPY_WORLD:
			rule.minimum_chapter_id = CHAPTER_M1_CANOPY_WORLD
			rule.required_planet_ids = [PLANET_WHITE_NOISE]
		PLANET_TIDAL_ARCHIPELAGO:
			rule.minimum_chapter_id = CHAPTER_M1_TIDAL_ARCHIPELAGO
			rule.required_planet_ids = [PLANET_CANOPY_WORLD]
	return rule


static func evaluate_planet_unlock(
	planet_id: StringName,
	current_chapter_id: StringName,
	unlocked_planets: Array[StringName],
	ship_configuration: Dictionary[StringName, StringName],
	ship_upgrades: Array[StringName],
	permission_ids: Array[StringName],
	story_flags: Dictionary[StringName, bool],
	completed_order_ids: Dictionary[StringName, bool],
	whitelist_context: Dictionary[StringName, bool] = {}
) -> StringName:
	var rule: PlanetUnlockRule = get_planet_unlock_rule(planet_id)
	if rule == null:
		return REASON_INVALID_PLANET
	return evaluate_planet_unlock_rule(
		rule,
		current_chapter_id,
		unlocked_planets,
		ship_configuration,
		ship_upgrades,
		permission_ids,
		story_flags,
		completed_order_ids,
		whitelist_context
	)


static func evaluate_planet_unlock_rule(
	rule: PlanetUnlockRule,
	current_chapter_id: StringName,
	unlocked_planets: Array[StringName],
	ship_configuration: Dictionary[StringName, StringName],
	ship_upgrades: Array[StringName],
	permission_ids: Array[StringName],
	story_flags: Dictionary[StringName, bool],
	completed_order_ids: Dictionary[StringName, bool],
	whitelist_context: Dictionary[StringName, bool] = {}
) -> StringName:
	if rule == null or not is_known_planet(rule.planet_id):
		return REASON_INVALID_PLANET
	if not has_reached_chapter(current_chapter_id, rule.minimum_chapter_id):
		return REASON_REQUIRED_CHAPTER
	for required_planet_id: StringName in rule.required_planet_ids:
		if not unlocked_planets.has(required_planet_id):
			return REASON_REQUIRED_PLANET
	for required_module_id: StringName in rule.required_module_ids:
		if (
			not ship_upgrades.has(required_module_id)
			and not ShipLoadoutRules.is_module_equipped(
				ship_configuration,
				required_module_id
			)
		):
			return REASON_REQUIRED_MODULE
	for required_permission_id: StringName in rule.required_permission_ids:
		if not permission_ids.has(required_permission_id):
			return REASON_REQUIRED_PERMISSION
	for required_story_flag_id: StringName in rule.required_story_flag_ids:
		if not story_flags.get(required_story_flag_id, false):
			return REASON_REQUIRED_STORY_FLAG
	for required_order_id: StringName in rule.required_completed_order_ids:
		if not completed_order_ids.get(required_order_id, false):
			return REASON_REQUIRED_COMPLETED_ORDER
	for required_context_id: StringName in rule.required_context_ids:
		if not whitelist_context.get(required_context_id, false):
			return REASON_REQUIRED_CONTEXT
	return &""


static func clamp_relation(value: int) -> int:
	return clampi(value, RELATION_MINIMUM, RELATION_MAXIMUM)


static func get_relation_event_flag(
	planet_id: StringName,
	event_id: StringName
) -> StringName:
	return StringName("%s%s/%s" % [RELATION_EVENT_FLAG_PREFIX, planet_id, event_id])


static func is_valid_codex_entry_id(entry_id: StringName) -> bool:
	return String(entry_id).begins_with("codex_") and is_stable_id(entry_id)


static func is_valid_souvenir_id(souvenir_id: StringName) -> bool:
	return String(souvenir_id).begins_with("souvenir_") and is_stable_id(souvenir_id)


static func is_valid_revisit_state_id(state_id: StringName) -> bool:
	return is_stable_id(state_id)


static func is_stable_id(value: StringName) -> bool:
	var text: String = String(value)
	if text.is_empty():
		return false
	var first_code: int = text.unicode_at(0)
	if first_code < 97 or first_code > 122:
		return false
	for index: int in range(text.length()):
		var code: int = text.unicode_at(index)
		var is_lowercase: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		if not is_lowercase and not is_digit and code != 95:
			return false
	return true
