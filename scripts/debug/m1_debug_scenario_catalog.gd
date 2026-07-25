class_name M1DebugScenarioCatalog
extends RefCounted

## Central, validated source for M1 development-only scenario state.

const ARGUMENT_PREFIX: String = "--m1-debug="
const CATALOG_SCENE_PATH: String = "res://scenes/debug/m1_catalog_debug.tscn"
const FLIGHT_LAB_SCENE_PATH: String = "res://scenes/flight/flight_lab.tscn"
const DELIVERY_LAB_SCENE_PATH: String = "res://scenes/flight/delivery_lab.tscn"
const RED_SAND_ROUTE_SCENE_PATH: String = (
	"res://scenes/flight/flight_level.tscn"
)
const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"

const SCENARIO_RED_SAND_REVISIT: StringName = &"red_sand_revisit"
const SCENARIO_WHITE_NOISE_CATALOG: StringName = &"white_noise_catalog"
const SCENARIO_CANOPY_CATALOG: StringName = &"canopy_catalog"
const SCENARIO_TIDAL_CATALOG: StringName = &"tidal_catalog"
const SCENARIO_LOW_ALTITUDE_DROP: StringName = &"low_altitude_drop"
const SCENARIO_EXPRESS_ORDER: StringName = &"express_order"
const SCENARIO_GATE_E: StringName = &"gate_e"

const SCENARIO_IDS: Array[StringName] = [
	SCENARIO_RED_SAND_REVISIT,
	SCENARIO_WHITE_NOISE_CATALOG,
	SCENARIO_CANOPY_CATALOG,
	SCENARIO_TIDAL_CATALOG,
	SCENARIO_LOW_ALTITUDE_DROP,
	SCENARIO_EXPRESS_ORDER,
	SCENARIO_GATE_E,
]

const ORDER_M0: StringName = &"order_red_sand_m0"
const ORDER_M0_CANONICAL: StringName = &"order_red_sand_cooling_core"
const ORDER_RED_SAND_REVISIT: StringName = (
	&"order_m1_red_sand_shielding_retrofit"
)
const ORDER_WHITE_NOISE: StringName = &"order_m1_white_noise_archive_core"
const ORDER_CANOPY: StringName = &"order_m1_canopy_ecology_cargo"
const ORDER_TIDAL: StringName = &"order_m1_tidal_weather_core"
const ORDER_CANOPY_DROP: StringName = &"side_canopy_spore_drop"
const ORDER_TIDAL_EXPRESS: StringName = &"side_tidal_beacon_before_eye"
const DEBUG_EXPRESS_ORDER_ID: StringName = &"debug_m1_express_order"

const STORY_M0_COMPLETED: StringName = &"story_red_sand_order_completed"
const STORY_M0_ARRIVAL: StringName = (
	&"story_red_sand_arrival_main_dialogue_completed"
)
const STORY_REVISIT_COMPLETED: StringName = (
	&"story_m1_red_sand_shielding_retrofit_completed"
)
const STORY_WHITE_COMPLETED: StringName = (
	&"story_m1_white_noise_archive_core_completed"
)
const STORY_CANOPY_COMPLETED: StringName = (
	&"story_m1_canopy_ecology_cargo_completed"
)
const STORY_TIDAL_COMPLETED: StringName = (
	&"story_m1_tidal_weather_core_completed"
)

var last_error: String = ""


func parse_arguments(
	user_arguments: PackedStringArray,
	registry: GameDataRegistry
) -> M1DebugScenarioDefinition:
	last_error = ""
	var matches: PackedStringArray = []
	for argument: String in user_arguments:
		if argument == "--m1-debug" or argument.begins_with(ARGUMENT_PREFIX):
			matches.append(argument)
	if matches.size() != 1:
		last_error = (
			"Expected exactly one %s<scenario_id> argument; found %d."
			% [ARGUMENT_PREFIX, matches.size()]
		)
		return null
	var raw_id: String = (
		""
		if matches[0] == "--m1-debug"
		else matches[0].trim_prefix(ARGUMENT_PREFIX)
	)
	if raw_id.is_empty():
		last_error = "M1 debug scenario ID cannot be empty."
		return null
	return get_definition(StringName(raw_id), registry)


func get_definition(
	scenario_id: StringName,
	registry: GameDataRegistry
) -> M1DebugScenarioDefinition:
	last_error = ""
	var definition: M1DebugScenarioDefinition = _create_definition(scenario_id)
	if definition == null:
		last_error = "Unknown M1 debug scenario: %s." % scenario_id
		return null
	var validation_errors: PackedStringArray = validate_definition(
		definition,
		registry
	)
	if not validation_errors.is_empty():
		last_error = "; ".join(validation_errors)
		return null
	return definition


func build_initial_progress(
	definition: M1DebugScenarioDefinition,
	registry: GameDataRegistry
) -> GameProgressData:
	last_error = ""
	var validation_errors: PackedStringArray = validate_definition(
		definition,
		registry
	)
	if not validation_errors.is_empty():
		last_error = "; ".join(validation_errors)
		return null

	var progress: GameProgressData = GameProgressData.new()
	progress.last_saved_at_unix = 0
	progress.build_version = "m1_debug"
	progress.main_story_chapter = definition.chapter_id
	progress.unlocked_planet_ids = definition.unlocked_planet_ids.duplicate()
	progress.planet_permission_ids = definition.permission_ids.duplicate()
	progress.planet_relation_values = definition.relation_values.duplicate()
	progress.credits = definition.starting_credits
	progress.ship_upgrade_ids = definition.available_module_ids.duplicate()
	progress.story_flags[STORY_M0_ARRIVAL] = true
	for flag_id: StringName in definition.story_flag_ids:
		progress.story_flags[flag_id] = true
	for planet_id: StringName in definition.revisit_states:
		progress.revisit_state[planet_id] = definition.revisit_states[planet_id]
	for order_id: StringName in definition.completed_order_ids:
		progress.completed_order_ids[order_id] = true
		progress.order_states[order_id] = GameStateModel.OrderStatus.COMPLETED
		progress.reward_applied_order_ids.append(order_id)
	progress.station_upgrade_ids[
		M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
	] = true
	progress.codex_entry_ids = [
		M0ProgressIds.CODEX_PLANET_RED_SAND,
		M0ProgressIds.CODEX_CHARACTER_IYA,
		M0ProgressIds.CODEX_RELAY_PLAQUE,
	]
	progress.souvenir_ids = [M0ProgressIds.SOUVENIR_RELAY_PLAQUE]
	progress.station_state_level = StationStateRules.M0_FIRST_DELIVERY_LEVEL
	progress.last_stable_station_state = &"station_after_first_delivery"
	progress.ship_configuration = ShipLoadoutRules.create_default_configuration()
	for module_id: StringName in definition.equipped_module_ids:
		var module: ShipModuleDefinition = registry.find_module(module_id)
		var slot_id: StringName = ShipLoadoutRules.get_configuration_slot_id(module)
		progress.ship_configuration[slot_id] = module_id

	var validated_progress: GameProgressData = GameProgressData.from_dictionary(
		progress.to_dictionary()
	)
	if not validated_progress.is_valid():
		last_error = validated_progress.validation_error
		return null
	return validated_progress


func validate_definition(
	definition: M1DebugScenarioDefinition,
	registry: GameDataRegistry
) -> PackedStringArray:
	var errors: PackedStringArray = []
	if definition == null:
		errors.append("Scenario definition is missing.")
		return errors
	if not SCENARIO_IDS.has(definition.scenario_id):
		errors.append("Unknown scenario ID: %s." % definition.scenario_id)
	if registry == null:
		errors.append("M1 data registry is missing.")
		return errors
	if not M1ProgressRules.is_known_chapter(definition.chapter_id):
		errors.append("Unknown chapter ID: %s." % definition.chapter_id)
	if (
		not SceneRouterService.is_valid_stage(definition.target_stage)
		or definition.target_stage == SceneRouterService.Stage.MAIN_MENU
	):
		errors.append("Scenario target Stage is invalid.")
	if (
		definition.target_scene_path.is_empty()
		or not ResourceLoader.exists(definition.target_scene_path)
	):
		errors.append(
			"Scenario target scene is missing: %s." % definition.target_scene_path
		)
	_validate_unique_ids(
		definition.unlocked_planet_ids,
		"unlocked_planet_ids",
		errors
	)
	var expected_planets: Array[StringName] = _expected_unlocked_planets(
		definition.chapter_id
	)
	if definition.unlocked_planet_ids != expected_planets:
		errors.append(
			"Unlocked planets must match the chapter prefix: %s."
			% definition.chapter_id
		)
	for planet_id: StringName in definition.unlocked_planet_ids:
		if (
			not M1ProgressRules.is_known_planet(planet_id)
			or registry.find_planet(planet_id) == null
		):
			errors.append("Unknown unlocked planet: %s." % planet_id)
	if (
		definition.focus_planet_id.is_empty()
		or not definition.unlocked_planet_ids.has(definition.focus_planet_id)
	):
		errors.append("Focused planet must be unlocked by the scenario.")
	var focused_order: OrderDefinition = registry.find_order(
		definition.catalog_focus_order_id
	)
	if focused_order == null:
		errors.append(
			"Unknown catalog focus order: %s."
			% definition.catalog_focus_order_id
		)
	elif focused_order.planet_id != definition.focus_planet_id:
		errors.append("Catalog focus order does not match the focused planet.")
	if (
		definition.preview_only
		and definition.target_scene_path != CATALOG_SCENE_PATH
	):
		errors.append("Preview-only scenarios must open the catalog debug scene.")
	if definition.preview_only and not definition.active_order_id.is_empty():
		errors.append("Preview-only scenarios cannot seed an active order.")
	if definition.active_order_id.is_empty():
		if not definition.fixture_source_order_id.is_empty():
			errors.append("A fixture source requires a debug active order ID.")
	else:
		_validate_debug_active_order(definition, registry, errors)

	_validate_unique_ids(
		definition.available_module_ids,
		"available_module_ids",
		errors
	)
	_validate_unique_ids(
		definition.equipped_module_ids,
		"equipped_module_ids",
		errors
	)
	var occupied_slots: Dictionary[StringName, StringName] = {}
	for module_id: StringName in definition.available_module_ids:
		if registry.find_module(module_id) == null:
			errors.append("Unknown available module: %s." % module_id)
	for module_id: StringName in definition.equipped_module_ids:
		var module: ShipModuleDefinition = registry.find_module(module_id)
		if module == null:
			errors.append("Unknown equipped module: %s." % module_id)
			continue
		if (
			not definition.available_module_ids.has(module_id)
			and not ShipLoadoutRules.BASE_OWNED_MODULE_IDS.has(module_id)
		):
			errors.append("Equipped module is not available: %s." % module_id)
		var slot_id: StringName = ShipLoadoutRules.get_configuration_slot_id(module)
		if occupied_slots.has(slot_id):
			errors.append(
				"Multiple equipped modules target slot %s." % slot_id
			)
		else:
			occupied_slots[slot_id] = module_id

	_validate_unique_ids(definition.permission_ids, "permission_ids", errors)
	for permission_id: StringName in definition.permission_ids:
		if not M1ProgressRules.is_known_permission(permission_id):
			errors.append("Unknown permission: %s." % permission_id)
	for planet_id: StringName in definition.relation_values:
		var relation_value: int = definition.relation_values.get(planet_id, 0)
		if (
			not definition.unlocked_planet_ids.has(planet_id)
			or relation_value < M1ProgressRules.RELATION_MINIMUM
			or relation_value > M1ProgressRules.RELATION_MAXIMUM
		):
			errors.append("Invalid relation value for %s." % planet_id)
	if definition.starting_credits < 0:
		errors.append("Scenario starting credits cannot be negative.")

	_validate_unique_ids(
		definition.completed_order_ids,
		"completed_order_ids",
		errors
	)
	for order_id: StringName in definition.completed_order_ids:
		if registry.find_order(order_id) == null:
			errors.append("Unknown completed order: %s." % order_id)
		if order_id == definition.catalog_focus_order_id:
			errors.append("The focused order cannot already be completed.")
	_validate_unique_ids(definition.story_flag_ids, "story_flag_ids", errors)
	for flag_id: StringName in definition.story_flag_ids:
		if not M1ProgressRules.is_stable_id(flag_id):
			errors.append("Invalid story flag ID: %s." % flag_id)
	for planet_id: StringName in definition.revisit_states:
		var state_id: StringName = definition.revisit_states.get(
			planet_id,
			&""
		)
		if (
			not definition.unlocked_planet_ids.has(planet_id)
			or not M1ProgressRules.is_valid_revisit_state_id(state_id)
		):
			errors.append("Invalid revisit state for %s." % planet_id)
	return errors


static func has_m1_debug_argument(user_arguments: PackedStringArray) -> bool:
	for argument: String in user_arguments:
		if argument == "--m1-debug" or argument.begins_with(ARGUMENT_PREFIX):
			return true
	return false


static func get_scenario_ids() -> Array[StringName]:
	return SCENARIO_IDS.duplicate()


func _create_definition(
	scenario_id: StringName
) -> M1DebugScenarioDefinition:
	match scenario_id:
		SCENARIO_RED_SAND_REVISIT:
			return _build_red_sand_revisit()
		SCENARIO_WHITE_NOISE_CATALOG:
			return _build_white_noise_catalog()
		SCENARIO_CANOPY_CATALOG:
			return _build_canopy_catalog()
		SCENARIO_TIDAL_CATALOG:
			return _build_tidal_catalog()
		SCENARIO_LOW_ALTITUDE_DROP:
			return _build_low_altitude_drop()
		SCENARIO_EXPRESS_ORDER:
			return _build_express_order()
		SCENARIO_GATE_E:
			return _build_gate_e()
	return null


func _build_red_sand_revisit() -> M1DebugScenarioDefinition:
	var definition: M1DebugScenarioDefinition = _base_catalog_definition(
		SCENARIO_RED_SAND_REVISIT,
		M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT,
		[M1ProgressRules.PLANET_RED_SAND],
		M1ProgressRules.PLANET_RED_SAND,
		ORDER_RED_SAND_REVISIT
	)
	definition.completed_order_ids = [ORDER_M0, ORDER_M0_CANONICAL]
	definition.story_flag_ids = [STORY_M0_COMPLETED]
	definition.relation_values = {M1ProgressRules.PLANET_RED_SAND: 1}
	definition.starting_credits = 100
	definition.revisit_states = {
		M1ProgressRules.PLANET_RED_SAND:
		M1ProgressRules.REVISIT_RED_SAND_AVAILABLE,
	}
	definition.active_order_id = ORDER_RED_SAND_REVISIT
	definition.target_stage = SceneRouterService.Stage.FLIGHT
	definition.target_scene_path = RED_SAND_ROUTE_SCENE_PATH
	definition.preview_only = false
	return definition


func _build_white_noise_catalog() -> M1DebugScenarioDefinition:
	var definition: M1DebugScenarioDefinition = _base_catalog_definition(
		SCENARIO_WHITE_NOISE_CATALOG,
		M1ProgressRules.CHAPTER_M1_WHITE_NOISE,
		[
			M1ProgressRules.PLANET_RED_SAND,
			M1ProgressRules.PLANET_WHITE_NOISE,
		],
		M1ProgressRules.PLANET_WHITE_NOISE,
		ORDER_WHITE_NOISE
	)
	definition.completed_order_ids = [ORDER_M0, ORDER_RED_SAND_REVISIT]
	definition.story_flag_ids = [
		STORY_M0_COMPLETED,
		STORY_REVISIT_COMPLETED,
	]
	definition.available_module_ids = [
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING,
	]
	definition.equipped_module_ids = [
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING,
	]
	definition.relation_values = {
		M1ProgressRules.PLANET_RED_SAND: 2,
		M1ProgressRules.PLANET_WHITE_NOISE: 0,
	}
	return definition


func _build_canopy_catalog() -> M1DebugScenarioDefinition:
	var definition: M1DebugScenarioDefinition = _base_catalog_definition(
		SCENARIO_CANOPY_CATALOG,
		M1ProgressRules.CHAPTER_M1_CANOPY_WORLD,
		[
			M1ProgressRules.PLANET_RED_SAND,
			M1ProgressRules.PLANET_WHITE_NOISE,
			M1ProgressRules.PLANET_CANOPY_WORLD,
		],
		M1ProgressRules.PLANET_CANOPY_WORLD,
		ORDER_CANOPY
	)
	definition.completed_order_ids = [
		ORDER_M0,
		ORDER_RED_SAND_REVISIT,
		ORDER_WHITE_NOISE,
	]
	definition.story_flag_ids = [
		STORY_M0_COMPLETED,
		STORY_REVISIT_COMPLETED,
		STORY_WHITE_COMPLETED,
	]
	definition.available_module_ids = [
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING,
		&"module_biosignal_isolation",
	]
	definition.equipped_module_ids = [&"module_biosignal_isolation"]
	definition.permission_ids = [
		M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS,
	]
	definition.relation_values = {
		M1ProgressRules.PLANET_RED_SAND: 2,
		M1ProgressRules.PLANET_WHITE_NOISE: 1,
		M1ProgressRules.PLANET_CANOPY_WORLD: 0,
	}
	return definition


func _build_tidal_catalog() -> M1DebugScenarioDefinition:
	var definition: M1DebugScenarioDefinition = _base_catalog_definition(
		SCENARIO_TIDAL_CATALOG,
		M1ProgressRules.CHAPTER_M1_TIDAL_ARCHIPELAGO,
		M1ProgressRules.PLANET_IDS.duplicate(),
		M1ProgressRules.PLANET_TIDAL_ARCHIPELAGO,
		ORDER_TIDAL
	)
	definition.completed_order_ids = [
		ORDER_M0,
		ORDER_RED_SAND_REVISIT,
		ORDER_WHITE_NOISE,
		ORDER_CANOPY,
	]
	definition.story_flag_ids = [
		STORY_M0_COMPLETED,
		STORY_REVISIT_COMPLETED,
		STORY_WHITE_COMPLETED,
		STORY_CANOPY_COMPLETED,
	]
	definition.available_module_ids = [
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING,
		&"module_biosignal_isolation",
		&"module_crosswind_stabilizer",
	]
	definition.equipped_module_ids = [&"module_crosswind_stabilizer"]
	definition.permission_ids = [
		M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS,
		M1ProgressRules.PERMISSION_CANOPY_CORE_ROUTE,
	]
	definition.relation_values = {
		M1ProgressRules.PLANET_RED_SAND: 2,
		M1ProgressRules.PLANET_WHITE_NOISE: 1,
		M1ProgressRules.PLANET_CANOPY_WORLD: 1,
		M1ProgressRules.PLANET_TIDAL_ARCHIPELAGO: 0,
	}
	return definition


func _build_low_altitude_drop() -> M1DebugScenarioDefinition:
	var definition: M1DebugScenarioDefinition = _build_canopy_catalog()
	definition.scenario_id = SCENARIO_LOW_ALTITUDE_DROP
	definition.catalog_focus_order_id = ORDER_CANOPY_DROP
	definition.completed_order_ids.append(ORDER_CANOPY)
	definition.story_flag_ids.append(STORY_CANOPY_COMPLETED)
	definition.target_stage = SceneRouterService.Stage.FLIGHT
	definition.target_scene_path = DELIVERY_LAB_SCENE_PATH
	definition.preview_only = false
	return definition


func _build_express_order() -> M1DebugScenarioDefinition:
	var definition: M1DebugScenarioDefinition = _build_tidal_catalog()
	definition.scenario_id = SCENARIO_EXPRESS_ORDER
	definition.catalog_focus_order_id = ORDER_TIDAL_EXPRESS
	definition.completed_order_ids.append(ORDER_TIDAL)
	definition.story_flag_ids.append(STORY_TIDAL_COMPLETED)
	definition.permission_ids.append(
		M1ProgressRules.PERMISSION_TIDAL_WEATHER_TOWER
	)
	definition.active_order_id = DEBUG_EXPRESS_ORDER_ID
	definition.fixture_source_order_id = ORDER_TIDAL_EXPRESS
	definition.target_stage = SceneRouterService.Stage.FLIGHT
	definition.target_scene_path = FLIGHT_LAB_SCENE_PATH
	definition.preview_only = false
	return definition


func _build_gate_e() -> M1DebugScenarioDefinition:
	var definition: M1DebugScenarioDefinition = _base_catalog_definition(
		SCENARIO_GATE_E,
		M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT,
		[M1ProgressRules.PLANET_RED_SAND],
		M1ProgressRules.PLANET_RED_SAND,
		ORDER_RED_SAND_REVISIT
	)
	definition.completed_order_ids = [ORDER_M0, ORDER_M0_CANONICAL]
	definition.story_flag_ids = [
		STORY_M0_COMPLETED,
		StationTutorialController.COMPLETION_FLAG,
		M0ProgressIds.STORY_FIRST_DELIVERY_SETTLED,
		M0ProgressIds.STORY_RETURN_DIALOGUE_COMPLETED,
	]
	definition.relation_values = {M1ProgressRules.PLANET_RED_SAND: 1}
	definition.starting_credits = 100
	definition.revisit_states = {
		M1ProgressRules.PLANET_RED_SAND:
		M1ProgressRules.REVISIT_RED_SAND_AVAILABLE,
	}
	definition.target_stage = SceneRouterService.Stage.STATION
	definition.target_scene_path = STATION_SCENE_PATH
	definition.preview_only = false
	return definition


func _base_catalog_definition(
	scenario_id: StringName,
	chapter_id: StringName,
	unlocked_planets: Array[StringName],
	focus_planet_id: StringName,
	focus_order_id: StringName
) -> M1DebugScenarioDefinition:
	var definition: M1DebugScenarioDefinition = M1DebugScenarioDefinition.new()
	definition.scenario_id = scenario_id
	definition.chapter_id = chapter_id
	definition.unlocked_planet_ids = unlocked_planets
	definition.focus_planet_id = focus_planet_id
	definition.catalog_focus_order_id = focus_order_id
	definition.target_stage = SceneRouterService.Stage.STATION
	definition.target_scene_path = CATALOG_SCENE_PATH
	definition.preview_only = true
	return definition


func _validate_debug_active_order(
	definition: M1DebugScenarioDefinition,
	registry: GameDataRegistry,
	errors: PackedStringArray
) -> void:
	if definition.active_order_id == ORDER_RED_SAND_REVISIT:
		var revisit_order: OrderDefinition = registry.find_order(
			ORDER_RED_SAND_REVISIT
		)
		if (
			revisit_order == null
			or not revisit_order.is_playable()
			or definition.catalog_focus_order_id != revisit_order.id
			or not definition.fixture_source_order_id.is_empty()
		):
			errors.append(
				"Red Sand revisit debug must use its playable formal order."
			)
		if (
			definition.target_stage != SceneRouterService.Stage.FLIGHT
			or definition.target_scene_path != RED_SAND_ROUTE_SCENE_PATH
		):
			errors.append(
				"Red Sand revisit debug must open the formal short route."
			)
		return
	if definition.active_order_id != DEBUG_EXPRESS_ORDER_ID:
		errors.append(
			"Only the isolated express fixture may seed an active debug order."
		)
	if not M1ProgressRules.is_stable_id(definition.active_order_id):
		errors.append("Debug active order ID is not stable.")
	var source: OrderDefinition = registry.find_order(
		definition.fixture_source_order_id
	)
	if source == null:
		errors.append(
			"Unknown debug fixture source order: %s."
			% definition.fixture_source_order_id
		)
		return
	if (
		source.content_readiness
		!= OrderDefinition.ContentReadiness.REGISTERED_ONLY
		or not source.is_express
	):
		errors.append(
			"Express fixture source must remain REGISTERED_ONLY and express."
		)
	if definition.catalog_focus_order_id != source.id:
		errors.append("Debug fixture source must match the catalog focus order.")
	if (
		definition.target_stage != SceneRouterService.Stage.FLIGHT
		or definition.target_scene_path != FLIGHT_LAB_SCENE_PATH
	):
		errors.append("Express debug fixture must open the isolated Flight Lab.")


static func _expected_unlocked_planets(
	chapter_id: StringName
) -> Array[StringName]:
	match chapter_id:
		M1ProgressRules.CHAPTER_M0_RED_SAND_COMPLETE, \
		M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT:
			return [M1ProgressRules.PLANET_RED_SAND]
		M1ProgressRules.CHAPTER_M1_WHITE_NOISE:
			return [
				M1ProgressRules.PLANET_RED_SAND,
				M1ProgressRules.PLANET_WHITE_NOISE,
			]
		M1ProgressRules.CHAPTER_M1_CANOPY_WORLD:
			return [
				M1ProgressRules.PLANET_RED_SAND,
				M1ProgressRules.PLANET_WHITE_NOISE,
				M1ProgressRules.PLANET_CANOPY_WORLD,
			]
		M1ProgressRules.CHAPTER_M1_TIDAL_ARCHIPELAGO, \
		M1ProgressRules.CHAPTER_M1_DEMO_EPILOGUE:
			return M1ProgressRules.PLANET_IDS.duplicate()
	return []


static func _validate_unique_ids(
	values: Array[StringName],
	label: String,
	errors: PackedStringArray
) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for value: StringName in values:
		if value.is_empty():
			errors.append("%s contains an empty ID." % label)
		elif seen.get(value, false):
			errors.append("%s contains duplicate ID %s." % [label, value])
		else:
			seen[value] = true
