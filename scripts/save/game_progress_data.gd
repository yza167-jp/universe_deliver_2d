class_name GameProgressData
extends RefCounted

const CURRENT_SCHEMA_VERSION: int = 2
const DEFAULT_SETTINGS_REFERENCE: StringName = &"local_settings"
const LEGACY_RED_SAND_ORDER_ID: StringName = &"order_red_sand_m0"
const CANONICAL_RED_SAND_ORDER_ID: StringName = &"order_red_sand_cooling_core"
const RED_SAND_ORDER_COMPLETION_FLAG: StringName = (
	&"story_red_sand_order_completed"
)
const RED_SAND_PLANET_ID: StringName = M1ProgressRules.PLANET_RED_SAND
const RED_SAND_REVISIT_CHAPTER_ID: StringName = (
	M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
)
const FIRST_DELIVERY_STATION_STATE_ID: StringName = &"station_after_first_delivery"
const RED_SAND_CODEX_ENTRY_ID: StringName = &"codex_planet_red_sand"
const IYA_CODEX_ENTRY_ID: StringName = &"codex_character_iya"
const RELAY_PLAQUE_CODEX_ENTRY_ID: StringName = &"codex_souvenir_old_relay_plaque"
const RELAY_PLAQUE_SOUVENIR_ID: StringName = &"souvenir_old_relay_plaque"
const RED_SAND_REVISIT_ORDER_ID: StringName = (
	&"order_m1_red_sand_shielding_retrofit"
)
const RED_SAND_REVISIT_COMPLETION_FLAG: StringName = (
	&"story_m1_red_sand_shielding_retrofit_completed"
)
const RED_SAND_REVISIT_CARGO_CODEX_ENTRY_ID: StringName = (
	&"codex_cargo_relay_pattern_shielding_materials"
)
const RELAY_ECHO_CODEX_ENTRY_ID: StringName = &"codex_anomaly_relay_echo"
const WHITE_NOISE_CODEX_ENTRY_ID: StringName = &"codex_planet_white_noise"
const WHITE_NOISE_PLANET_ID: StringName = M1ProgressRules.PLANET_WHITE_NOISE
const WHITE_NOISE_CHAPTER_ID: StringName = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
const HIGH_VOLTAGE_SHIELDING_MODULE_ID: StringName = (
	M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
)
const RED_SAND_ARRIVAL_COMPLETED_FLAG: StringName = (
	&"story_red_sand_arrival_main_dialogue_completed"
)

var schema_version: int = CURRENT_SCHEMA_VERSION
var migrated_from_version: int = CURRENT_SCHEMA_VERSION
var settings_reference: StringName = DEFAULT_SETTINGS_REFERENCE
var last_saved_at_unix: int = 0
var build_version: String = ""

var current_order_id: StringName = &""
var destination_id: StringName = &""
var cargo_id: StringName = &""
var ship_configuration: Dictionary[StringName, StringName] = {}
var story_flags: Dictionary[StringName, bool] = {}
var read_dialogue_ids: Dictionary[StringName, bool] = {}
var completed_order_ids: Dictionary[StringName, bool] = {}
var credits: int = 0
var station_upgrade_ids: Dictionary[StringName, bool] = {}
var departure_confirmed: bool = false
var travel_state: GameStateModel.TravelState = GameStateModel.TravelState.IDLE
var travel_destination_id: StringName = &""
var order_run_state: OrderRunState = OrderRunState.new()
var main_story_chapter: StringName = &""
var unlocked_planet_ids: Array[StringName] = []
var planet_relation_values: Dictionary[StringName, int] = {}
var planet_permission_ids: Array[StringName] = []
var codex_entry_ids: Array[StringName] = []
var souvenir_ids: Array[StringName] = []
var completed_side_order_ids: Array[StringName] = []
var failed_side_order_ids: Array[StringName] = []
var order_states: Dictionary[StringName, int] = {}
var reward_applied_order_ids: Array[StringName] = []
var station_state_level: int = 0
var ship_upgrade_ids: Array[StringName] = []
var revisit_state: Dictionary[StringName, StringName] = {}
var demo_ending_flags: Dictionary[StringName, Variant] = {}
var last_stable_station_state: StringName = &""

var validation_error: String = ""


func _init() -> void:
	ship_configuration = ShipLoadoutRules.create_default_configuration()
	order_run_state.reset()


static func capture(game_state: GameStateModel) -> GameProgressData:
	var progress: GameProgressData = GameProgressData.new()
	if game_state == null:
		progress.validation_error = "GameState is unavailable."
		return progress
	progress.last_saved_at_unix = roundi(Time.get_unix_time_from_system())
	progress.build_version = String(
		ProjectSettings.get_setting("application/config/version", "unknown")
	)
	progress.current_order_id = game_state.current_order_id
	progress.destination_id = game_state.destination_id
	progress.cargo_id = game_state.cargo_id
	progress.ship_configuration = _copy_string_name_map(game_state.ship_configuration)
	progress.story_flags = _copy_enabled_ids(game_state.story_flags)
	progress.read_dialogue_ids = _copy_enabled_ids(game_state.read_dialogue_ids)
	progress.completed_order_ids = _copy_enabled_ids(game_state.completed_order_ids)
	progress.credits = game_state.credits
	progress.station_upgrade_ids = _copy_enabled_ids(game_state.station_upgrade_ids)
	progress.departure_confirmed = game_state.departure_confirmed
	progress.travel_state = game_state.travel_state
	progress.travel_destination_id = game_state.travel_destination_id
	progress.order_run_state = _copy_order_run_state(game_state.order_run_state)
	progress.main_story_chapter = game_state.main_story_chapter
	progress.unlocked_planet_ids = _copy_unique_id_array(game_state.unlocked_planet_ids)
	progress.planet_relation_values = _copy_integer_map(game_state.planet_relation_values)
	progress.planet_permission_ids = _copy_unique_id_array(
		game_state.planet_permission_ids
	)
	progress.codex_entry_ids = _copy_unique_id_array(game_state.codex_entry_ids)
	progress.souvenir_ids = _copy_unique_id_array(game_state.souvenir_ids)
	progress.completed_side_order_ids = _copy_unique_id_array(
		game_state.completed_side_order_ids
	)
	progress.failed_side_order_ids = _copy_unique_id_array(
		game_state.failed_side_order_ids
	)
	progress.order_states = _copy_order_state_map(game_state.order_states)
	progress.reward_applied_order_ids = _copy_unique_id_array(
		game_state.reward_applied_order_ids
	)
	progress.station_state_level = game_state.station_state_level
	progress.ship_upgrade_ids = _copy_unique_id_array(game_state.ship_upgrade_ids)
	progress.revisit_state = _copy_string_name_map(game_state.revisit_state)
	progress.demo_ending_flags = _copy_variant_map(game_state.demo_ending_flags)
	progress.last_stable_station_state = game_state.last_stable_station_state
	progress._apply_completed_m0_compatibility()
	progress._apply_red_sand_revisit_content_compatibility()
	progress._apply_station_state_compatibility()
	progress._apply_order_state_compatibility()
	progress._validate_consistency()
	return progress


static func from_dictionary(source: Dictionary) -> GameProgressData:
	var progress: GameProgressData = GameProgressData.new()
	progress._read_dictionary(source)
	return progress


func is_valid() -> bool:
	return validation_error.is_empty()


func was_migrated() -> bool:
	return migrated_from_version < CURRENT_SCHEMA_VERSION


func to_dictionary() -> Dictionary[String, Variant]:
	var game_progress: Dictionary[String, Variant] = {
		"current_order_id": String(current_order_id),
		"destination_id": String(destination_id),
		"cargo_id": String(cargo_id),
		"ship_configuration": _serialize_configuration(ship_configuration),
		"story_flags": _serialize_enabled_ids(story_flags),
		"read_dialogue_ids": _serialize_enabled_ids(read_dialogue_ids),
		"completed_order_ids": _serialize_enabled_ids(completed_order_ids),
		"credits": credits,
		"station_upgrade_ids": _serialize_enabled_ids(station_upgrade_ids),
		"departure_confirmed": departure_confirmed,
		"travel_state": _travel_state_to_name(travel_state),
		"travel_destination_id": String(travel_destination_id),
		"order_run_state": _serialize_order_run_state(order_run_state),
		"main_story_chapter": String(main_story_chapter),
		"unlocked_planet_ids": _serialize_id_array(unlocked_planet_ids),
		"planet_relation_values": _serialize_integer_map(planet_relation_values),
		"planet_permission_ids": _serialize_id_array(planet_permission_ids),
		"codex_entry_ids": _serialize_id_array(codex_entry_ids),
		"souvenir_ids": _serialize_id_array(souvenir_ids),
		"completed_side_order_ids": _serialize_id_array(completed_side_order_ids),
		"failed_side_order_ids": _serialize_id_array(failed_side_order_ids),
		"order_states": _serialize_order_state_map(order_states),
		"reward_applied_order_ids": _serialize_id_array(reward_applied_order_ids),
		"station_state_level": station_state_level,
		"ship_upgrade_ids": _serialize_id_array(ship_upgrade_ids),
		"revisit_state": _serialize_string_name_map(revisit_state),
		"demo_ending_flags": _serialize_variant_map(demo_ending_flags),
		"last_stable_station_state": String(last_stable_station_state),
	}
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"game_progress": game_progress,
		"last_saved_at_unix": last_saved_at_unix,
		"build_version": build_version,
		"settings_reference": String(settings_reference),
	}


func apply_to(game_state: GameStateModel) -> bool:
	if not is_valid() or game_state == null:
		return false
	game_state.reset_runtime_state()
	game_state.current_order_id = current_order_id
	game_state.destination_id = destination_id
	game_state.cargo_id = cargo_id
	game_state.ship_configuration = _copy_string_name_map(ship_configuration)
	game_state.story_flags = _copy_enabled_ids(story_flags)
	game_state.read_dialogue_ids = _copy_enabled_ids(read_dialogue_ids)
	game_state.completed_order_ids = _copy_enabled_ids(completed_order_ids)
	game_state.credits = credits
	game_state.station_upgrade_ids = _copy_enabled_ids(station_upgrade_ids)
	game_state.departure_confirmed = departure_confirmed
	game_state.travel_state = travel_state
	game_state.travel_destination_id = travel_destination_id
	game_state.order_run_state = _copy_order_run_state(order_run_state)
	game_state.main_story_chapter = main_story_chapter
	game_state.unlocked_planet_ids = _copy_unique_id_array(unlocked_planet_ids)
	game_state.planet_relation_values = _copy_integer_map(planet_relation_values)
	game_state.planet_permission_ids = _copy_unique_id_array(planet_permission_ids)
	game_state.codex_entry_ids = _copy_unique_id_array(codex_entry_ids)
	game_state.souvenir_ids = _copy_unique_id_array(souvenir_ids)
	game_state.completed_side_order_ids = _copy_unique_id_array(
		completed_side_order_ids
	)
	game_state.failed_side_order_ids = _copy_unique_id_array(failed_side_order_ids)
	game_state.order_states = _copy_order_state_map(order_states)
	game_state.reward_applied_order_ids = _copy_unique_id_array(
		reward_applied_order_ids
	)
	game_state.station_state_level = station_state_level
	game_state.ship_upgrade_ids = _copy_unique_id_array(ship_upgrade_ids)
	game_state.revisit_state = _copy_string_name_map(revisit_state)
	game_state.demo_ending_flags = _copy_variant_map(demo_ending_flags)
	game_state.last_stable_station_state = last_stable_station_state
	game_state.last_order_error = &""
	game_state.last_loadout_error = &""
	game_state.last_travel_error = &""
	game_state.runtime_state_restored.emit()
	return true


func _read_dictionary(source: Dictionary) -> void:
	validation_error = ""
	migrated_from_version = 0
	var stored_version: int = 0
	if source.has("schema_version"):
		stored_version = _read_integer(
			source.get("schema_version"),
			"schema_version",
			0,
			2147483647
		)
		if not validation_error.is_empty():
			return
	if stored_version > CURRENT_SCHEMA_VERSION:
		validation_error = "Save schema %d is newer than supported schema %d." % [
			stored_version,
			CURRENT_SCHEMA_VERSION,
		]
		return
	migrated_from_version = stored_version
	schema_version = CURRENT_SCHEMA_VERSION

	var versioned_source: Dictionary = source
	if stored_version == 0:
		versioned_source = _migrate_schema_0_to_1(source)
		stored_version = 1

	settings_reference = _read_string_name(
		versioned_source.get("settings_reference", DEFAULT_SETTINGS_REFERENCE),
		"settings_reference",
		false
	)
	if not validation_error.is_empty():
		return
	if versioned_source.has("last_saved_at_unix"):
		last_saved_at_unix = _read_integer(
			versioned_source.get("last_saved_at_unix"),
			"last_saved_at_unix",
			0,
			9223372036854775807
		)
	if versioned_source.has("build_version"):
		build_version = String(
			_read_string_name(
				versioned_source.get("build_version"),
				"build_version",
				true
			)
		)
	if not validation_error.is_empty():
		return

	var raw_payload: Variant = versioned_source.get("game_progress")
	if not raw_payload is Dictionary:
		validation_error = "game_progress must be an object."
		return
	var payload: Dictionary = raw_payload as Dictionary
	_read_schema_v1_fields(payload)
	if not validation_error.is_empty():
		return
	_apply_station_state_compatibility()
	_apply_order_state_compatibility()
	_validate_consistency()
	if not validation_error.is_empty():
		return

	if stored_version == 1:
		_migrate_schema_1_to_2()
	else:
		_read_schema_v2_fields(payload)
	if not validation_error.is_empty():
		return
	_apply_completed_m0_compatibility()
	_apply_red_sand_revisit_content_compatibility()
	_apply_station_state_compatibility()
	_apply_order_state_compatibility()
	_validate_consistency()


func _read_schema_v1_fields(payload: Dictionary) -> void:
	current_order_id = _read_optional_id(payload, "current_order_id")
	destination_id = _read_optional_id(payload, "destination_id")
	cargo_id = _read_optional_id(payload, "cargo_id")
	ship_configuration = _read_configuration(payload)
	story_flags = _read_enabled_id_set(payload, "story_flags")
	read_dialogue_ids = _read_enabled_id_set(payload, "read_dialogue_ids")
	completed_order_ids = _read_enabled_id_set(payload, "completed_order_ids")
	if payload.has("credits"):
		credits = _read_integer(payload.get("credits"), "credits", 0, 2147483647)
	station_upgrade_ids = _read_enabled_id_set(payload, "station_upgrade_ids")
	if payload.has("departure_confirmed"):
		departure_confirmed = _read_bool(
			payload.get("departure_confirmed"),
			"departure_confirmed"
		)
	if payload.has("travel_state"):
		travel_state = _read_travel_state(payload.get("travel_state"))
	travel_destination_id = _read_optional_id(payload, "travel_destination_id")
	if payload.has("order_run_state"):
		var raw_run_state: Variant = payload.get("order_run_state")
		if not raw_run_state is Dictionary:
			validation_error = "order_run_state must be an object."
			return
		order_run_state = _read_order_run_state(raw_run_state as Dictionary)


func _read_schema_v2_fields(payload: Dictionary) -> void:
	main_story_chapter = _read_optional_id(payload, "main_story_chapter")
	unlocked_planet_ids = _read_progress_id_array(payload, "unlocked_planet_ids")
	planet_relation_values = _read_integer_map(payload, "planet_relation_values")
	planet_permission_ids = _read_progress_id_array(payload, "planet_permission_ids")
	codex_entry_ids = _read_progress_id_array(payload, "codex_entry_ids")
	souvenir_ids = _read_progress_id_array(payload, "souvenir_ids")
	completed_side_order_ids = _read_progress_id_array(
		payload,
		"completed_side_order_ids"
	)
	failed_side_order_ids = _read_progress_id_array(payload, "failed_side_order_ids")
	order_states = _read_order_state_map(payload)
	reward_applied_order_ids = _read_progress_id_array(
		payload,
		"reward_applied_order_ids"
	)
	if payload.has("station_state_level"):
		station_state_level = _read_integer(
			payload.get("station_state_level"),
			"station_state_level",
			0,
			2147483647
		)
	ship_upgrade_ids = _read_progress_id_array(payload, "ship_upgrade_ids")
	revisit_state = _read_string_name_dictionary(payload, "revisit_state")
	demo_ending_flags = _read_demo_ending_flags(payload)
	last_stable_station_state = _read_optional_id(
		payload,
		"last_stable_station_state"
	)


## Schema-less M0 data used the progress payload as the root object.
static func _migrate_schema_0_to_1(source: Dictionary) -> Dictionary:
	var migrated: Dictionary = source.duplicate(true)
	if source.has("game_progress"):
		migrated["schema_version"] = 1
		return migrated
	var payload: Dictionary = source.duplicate(true)
	for metadata_key: String in [
		"schema_version",
		"last_saved_at_unix",
		"build_version",
		"settings_reference",
	]:
		payload.erase(metadata_key)
	migrated = {
		"schema_version": 1,
		"game_progress": payload,
		"last_saved_at_unix": source.get("last_saved_at_unix", 0),
		"build_version": source.get("build_version", ""),
		"settings_reference": source.get(
			"settings_reference",
			String(DEFAULT_SETTINGS_REFERENCE)
		),
	}
	return migrated


func _migrate_schema_1_to_2() -> void:
	_apply_completed_m0_compatibility()
	_apply_order_state_compatibility()


func _apply_completed_m0_compatibility() -> void:
	var first_delivery_completed: bool = (
		completed_order_ids.get(LEGACY_RED_SAND_ORDER_ID, false)
		or completed_order_ids.get(CANONICAL_RED_SAND_ORDER_ID, false)
	)
	var red_sand_known: bool = (
		first_delivery_completed
		or story_flags.get(RED_SAND_ARRIVAL_COMPLETED_FLAG, false)
	)
	if red_sand_known:
		_append_unique_id(unlocked_planet_ids, RED_SAND_PLANET_ID)
		_append_unique_id(codex_entry_ids, RED_SAND_CODEX_ENTRY_ID)
	if (
		story_flags.get(RED_SAND_ARRIVAL_COMPLETED_FLAG, false)
		or first_delivery_completed
	):
		_append_unique_id(codex_entry_ids, IYA_CODEX_ENTRY_ID)
	if station_upgrade_ids.get(
		M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY,
		false
	):
		_append_unique_id(souvenir_ids, RELAY_PLAQUE_SOUVENIR_ID)
		_append_unique_id(codex_entry_ids, RELAY_PLAQUE_CODEX_ENTRY_ID)
	if not first_delivery_completed:
		return
	completed_order_ids[LEGACY_RED_SAND_ORDER_ID] = true
	completed_order_ids[CANONICAL_RED_SAND_ORDER_ID] = true
	story_flags[M0ProgressIds.STORY_STATION_TUTORIAL_COMPLETED] = true
	story_flags[RED_SAND_ORDER_COMPLETION_FLAG] = true
	if main_story_chapter.is_empty():
		main_story_chapter = RED_SAND_REVISIT_CHAPTER_ID
	_append_unique_id(unlocked_planet_ids, RED_SAND_PLANET_ID)
	station_state_level = maxi(station_state_level, 1)
	if last_stable_station_state.is_empty():
		last_stable_station_state = FIRST_DELIVERY_STATION_STATE_ID


func _apply_red_sand_revisit_content_compatibility() -> void:
	var revisit_completed: bool = (
		completed_order_ids.get(RED_SAND_REVISIT_ORDER_ID, false)
		or story_flags.get(RED_SAND_REVISIT_COMPLETION_FLAG, false)
	)
	if not revisit_completed:
		return
	_append_unique_id(
		codex_entry_ids,
		RED_SAND_REVISIT_CARGO_CODEX_ENTRY_ID
	)
	_append_unique_id(codex_entry_ids, RELAY_ECHO_CODEX_ENTRY_ID)
	_append_unique_id(codex_entry_ids, WHITE_NOISE_CODEX_ENTRY_ID)
	if (
		completed_order_ids.get(RED_SAND_REVISIT_ORDER_ID, false)
		and story_flags.get(RED_SAND_REVISIT_COMPLETION_FLAG, false)
		and M1ProgressRules.has_reached_chapter(
			main_story_chapter,
			WHITE_NOISE_CHAPTER_ID
		)
		and ship_upgrade_ids.has(HIGH_VOLTAGE_SHIELDING_MODULE_ID)
	):
		_append_unique_id(unlocked_planet_ids, WHITE_NOISE_PLANET_ID)


func _apply_order_state_compatibility() -> void:
	for completed_id: StringName in completed_side_order_ids:
		completed_order_ids[completed_id] = true
	for completed_id: StringName in completed_order_ids:
		if not completed_order_ids.get(completed_id, false):
			continue
		if not order_states.has(completed_id):
			order_states[completed_id] = GameStateModel.OrderStatus.COMPLETED
		_append_unique_id(reward_applied_order_ids, completed_id)
	for failed_id: StringName in failed_side_order_ids:
		if (
			not completed_order_ids.get(failed_id, false)
			and not order_states.has(failed_id)
		):
			order_states[failed_id] = GameStateModel.OrderStatus.FAILED
	if not current_order_id.is_empty() and not order_states.has(current_order_id):
		order_states[current_order_id] = GameStateModel.OrderStatus.ACCEPTED


func _apply_station_state_compatibility() -> void:
	station_state_level = maxi(
		station_state_level,
		StationStateRules.get_required_summary_level(station_upgrade_ids)
	)


func _validate_consistency() -> void:
	if settings_reference.is_empty():
		validation_error = "settings_reference cannot be empty."
		return
	if credits < 0:
		validation_error = "credits cannot be negative."
		return
	if current_order_id.is_empty():
		if not destination_id.is_empty() or not cargo_id.is_empty():
			validation_error = "Destination and cargo require an active order."
			return
		if departure_confirmed:
			validation_error = "A completed or empty order cannot remain departure-confirmed."
			return
		if travel_state != GameStateModel.TravelState.IDLE:
			validation_error = "Travel state requires an active order."
			return
		if not travel_destination_id.is_empty():
			validation_error = "Travel destination requires an active order."
			return
		if (
			not order_run_state.order_id.is_empty()
			and int(
				order_states.get(
					order_run_state.order_id,
					GameStateModel.OrderStatus.AVAILABLE
				)
			) not in [
				GameStateModel.OrderStatus.COMPLETED,
				GameStateModel.OrderStatus.FAILED,
				GameStateModel.OrderStatus.ABANDONED,
			]
		):
			validation_error = "Inactive order-run state has no terminal order-state record."
			return
	else:
		if destination_id.is_empty() or cargo_id.is_empty():
			validation_error = "An active order requires destination and cargo IDs."
			return
		if completed_order_ids.get(current_order_id, false):
			validation_error = "An order cannot be active and completed at the same time."
			return
		if int(
			order_states.get(
				current_order_id,
				GameStateModel.OrderStatus.AVAILABLE
			)
		) != GameStateModel.OrderStatus.ACCEPTED:
			validation_error = "The active order must have ACCEPTED order state."
			return
		if order_run_state.order_id.is_empty():
			order_run_state.order_id = current_order_id
		elif order_run_state.order_id != current_order_id:
			validation_error = "Order run state does not match the active order."
			return
	if travel_state != GameStateModel.TravelState.IDLE:
		if not departure_confirmed:
			validation_error = "Active travel requires confirmed departure."
			return
		if travel_destination_id.is_empty():
			validation_error = "Active travel requires a destination ID."
			return
		if travel_destination_id != destination_id:
			validation_error = "Travel destination does not match the active order destination."
			return
	elif not travel_destination_id.is_empty():
		validation_error = "Idle travel cannot retain a destination ID."
		return
	_validate_schema_v2_consistency()


func _validate_schema_v2_consistency() -> void:
	if station_state_level < 0:
		validation_error = "station_state_level cannot be negative."
		return
	for station_upgrade_id: StringName in station_upgrade_ids:
		if (
			StationStateRules.is_station_state_candidate(station_upgrade_id)
			and not StationStateRules.is_known_state_id(station_upgrade_id)
		):
			validation_error = (
				"Unknown station state ID: %s." % station_upgrade_id
			)
			return
	var required_station_level: int = (
		StationStateRules.get_required_summary_level(station_upgrade_ids)
	)
	if station_state_level < required_station_level:
		validation_error = (
			"station_state_level is below its authoritative state IDs."
		)
		return
	if (
		not main_story_chapter.is_empty()
		and not M1ProgressRules.is_known_chapter(main_story_chapter)
	):
		validation_error = "Unknown main_story_chapter: %s." % main_story_chapter
		return
	if not _validate_id_array(unlocked_planet_ids, "unlocked_planet_ids"):
		return
	for planet_id: StringName in unlocked_planet_ids:
		if not M1ProgressRules.is_known_planet(planet_id):
			validation_error = "Unknown unlocked planet: %s." % planet_id
			return
	if not _validate_id_array(planet_permission_ids, "planet_permission_ids"):
		return
	for permission_id: StringName in planet_permission_ids:
		if not M1ProgressRules.is_known_permission(permission_id):
			validation_error = "Unknown planet permission: %s." % permission_id
			return
	if not _validate_id_array(codex_entry_ids, "codex_entry_ids"):
		return
	for codex_entry_id: StringName in codex_entry_ids:
		if not M1ProgressRules.is_valid_codex_entry_id(codex_entry_id):
			validation_error = "Invalid codex entry ID: %s." % codex_entry_id
			return
	if not _validate_id_array(souvenir_ids, "souvenir_ids"):
		return
	for souvenir_id: StringName in souvenir_ids:
		if not M1ProgressRules.is_valid_souvenir_id(souvenir_id):
			validation_error = "Invalid souvenir ID: %s." % souvenir_id
			return
	if not _validate_id_array(
		completed_side_order_ids,
		"completed_side_order_ids"
	):
		return
	if not _validate_id_array(failed_side_order_ids, "failed_side_order_ids"):
		return
	if not _validate_id_array(
		reward_applied_order_ids,
		"reward_applied_order_ids"
	):
		return
	if not _validate_id_array(ship_upgrade_ids, "ship_upgrade_ids"):
		return
	var accepted_order_ids: Array[StringName] = []
	for order_id: StringName in order_states:
		if not M1ProgressRules.is_stable_id(order_id):
			validation_error = "order_states contains an invalid order ID: %s." % order_id
			return
		var status: int = order_states.get(
			order_id,
			GameStateModel.OrderStatus.AVAILABLE
		)
		if status <= GameStateModel.OrderStatus.AVAILABLE or status > GameStateModel.OrderStatus.ARCHIVED:
			validation_error = "order_states contains an invalid status for %s." % order_id
			return
		if status == GameStateModel.OrderStatus.ACCEPTED:
			accepted_order_ids.append(order_id)
		if (
			status == GameStateModel.OrderStatus.COMPLETED
			and not completed_order_ids.get(order_id, false)
		):
			validation_error = (
				"COMPLETED order state requires a completed_order_ids record: %s."
				% order_id
			)
			return
		if (
			status == GameStateModel.OrderStatus.FAILED
			and not failed_side_order_ids.has(order_id)
		):
			validation_error = (
				"FAILED order state requires a failed_side_order_ids record: %s."
				% order_id
			)
			return
	if accepted_order_ids.size() > 1:
		validation_error = "Only one order may have ACCEPTED state."
		return
	if current_order_id.is_empty():
		if not accepted_order_ids.is_empty():
			validation_error = "ACCEPTED order state requires current_order_id."
			return
	elif accepted_order_ids != [current_order_id]:
		validation_error = "current_order_id must be the only ACCEPTED order state."
		return
	for completed_id: StringName in completed_order_ids:
		if not completed_order_ids.get(completed_id, false):
			continue
		if int(
			order_states.get(
				completed_id,
				GameStateModel.OrderStatus.AVAILABLE
			)
		) != GameStateModel.OrderStatus.COMPLETED:
			validation_error = (
				"completed_order_ids requires COMPLETED order state: %s."
				% completed_id
			)
			return
		if not reward_applied_order_ids.has(completed_id):
			validation_error = (
				"Completed order is missing its reward-applied ledger entry: %s."
				% completed_id
			)
			return
	for reward_order_id: StringName in reward_applied_order_ids:
		if (
			not completed_order_ids.get(reward_order_id, false)
			or int(
				order_states.get(
					reward_order_id,
					GameStateModel.OrderStatus.AVAILABLE
				)
			) != GameStateModel.OrderStatus.COMPLETED
		):
			validation_error = (
				"reward_applied_order_ids must reference a COMPLETED order: %s."
				% reward_order_id
			)
			return
	for relation_id: StringName in planet_relation_values:
		var relation_value: int = planet_relation_values.get(relation_id, 0)
		if (
			not M1ProgressRules.is_known_planet(relation_id)
			or relation_value < M1ProgressRules.RELATION_MINIMUM
			or relation_value > M1ProgressRules.RELATION_MAXIMUM
		):
			validation_error = (
				"planet_relation_values must use known planets and the supported range."
			)
			return
	for revisit_id: StringName in revisit_state:
		if (
			not M1ProgressRules.is_known_planet(revisit_id)
			or not M1ProgressRules.is_valid_revisit_state_id(
				revisit_state.get(revisit_id, &"")
			)
		):
			validation_error = (
				"revisit_state must use known planets and stable state IDs."
			)
			return
	for flag_id: StringName in demo_ending_flags:
		if flag_id.is_empty() or not _is_supported_demo_ending_flag_value(
			demo_ending_flags.get(flag_id)
		):
			validation_error = (
				"demo_ending_flags keys and values must use supported scalar data."
			)
			return
	for completed_id: StringName in completed_side_order_ids:
		if failed_side_order_ids.has(completed_id):
			validation_error = (
				"A side order cannot be both completed and failed: %s." % completed_id
			)
			return
		if int(
			order_states.get(
				completed_id,
				GameStateModel.OrderStatus.AVAILABLE
			)
		) != GameStateModel.OrderStatus.COMPLETED:
			validation_error = (
				"completed_side_order_ids requires COMPLETED order state: %s."
				% completed_id
			)
			return
	for failed_id: StringName in failed_side_order_ids:
		if int(
			order_states.get(
				failed_id,
				GameStateModel.OrderStatus.AVAILABLE
			)
		) != GameStateModel.OrderStatus.FAILED:
			validation_error = (
				"failed_side_order_ids requires FAILED order state: %s."
				% failed_id
			)
			return
	if (
		not current_order_id.is_empty()
		and (
			completed_side_order_ids.has(current_order_id)
			or failed_side_order_ids.has(current_order_id)
		)
	):
		validation_error = "An active order cannot already have a terminal side-order state."


func _validate_id_array(values: Array[StringName], field_name: String) -> bool:
	var seen_ids: Dictionary[StringName, bool] = {}
	for entry_id: StringName in values:
		if entry_id.is_empty():
			validation_error = "%s cannot contain an empty ID." % field_name
			return false
		if seen_ids.get(entry_id, false):
			validation_error = "%s cannot contain duplicate IDs." % field_name
			return false
		seen_ids[entry_id] = true
	return true


static func _is_supported_demo_ending_flag_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL, TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_STRING, TYPE_STRING_NAME:
			return not String(value).is_empty()
	return false


func _read_configuration(payload: Dictionary) -> Dictionary[StringName, StringName]:
	var configuration: Dictionary[StringName, StringName] = (
		ShipLoadoutRules.create_default_configuration()
	)
	if not payload.has("ship_configuration"):
		return configuration
	var raw_value: Variant = payload.get("ship_configuration")
	if not raw_value is Dictionary:
		validation_error = "ship_configuration must be an object."
		return configuration
	var raw_configuration: Dictionary = raw_value as Dictionary
	for raw_slot: Variant in raw_configuration.keys():
		var slot_id: StringName = _read_string_name(raw_slot, "ship_configuration slot", false)
		if not validation_error.is_empty():
			return configuration
		if not ShipLoadoutRules.is_valid_slot_id(slot_id):
			validation_error = "Unknown ship slot: %s." % slot_id
			return configuration
		var module_id: StringName = _read_string_name(
			raw_configuration.get(raw_slot),
			"ship_configuration.%s" % slot_id,
			true
		)
		if not validation_error.is_empty():
			return configuration
		configuration[slot_id] = module_id
	return configuration


func _read_enabled_id_set(
	payload: Dictionary,
	field_name: String
) -> Dictionary[StringName, bool]:
	var enabled_ids: Dictionary[StringName, bool] = {}
	if not payload.has(field_name):
		return enabled_ids
	var raw_value: Variant = payload.get(field_name)
	if not raw_value is Array:
		validation_error = "%s must be an array." % field_name
		return enabled_ids
	for raw_id: Variant in raw_value as Array:
		var entry_id: StringName = _read_string_name(raw_id, field_name, false)
		if not validation_error.is_empty():
			return enabled_ids
		enabled_ids[entry_id] = true
	return enabled_ids


func _read_progress_id_array(
	payload: Dictionary,
	field_name: String
) -> Array[StringName]:
	var ids: Array[StringName] = []
	if not payload.has(field_name):
		return ids
	var raw_value: Variant = payload.get(field_name)
	if not raw_value is Array:
		validation_error = "%s must be an array." % field_name
		return ids
	for raw_id: Variant in raw_value as Array:
		var entry_id: StringName = _read_string_name(raw_id, field_name, false)
		if not validation_error.is_empty():
			return ids
		_append_unique_id(ids, entry_id)
	return ids


func _read_integer_map(
	payload: Dictionary,
	field_name: String
) -> Dictionary[StringName, int]:
	var values: Dictionary[StringName, int] = {}
	if not payload.has(field_name):
		return values
	var raw_value: Variant = payload.get(field_name)
	if not raw_value is Dictionary:
		validation_error = "%s must be an object." % field_name
		return values
	var raw_values: Dictionary = raw_value as Dictionary
	for raw_key: Variant in raw_values:
		var key: StringName = _read_string_name(raw_key, "%s key" % field_name, false)
		if not validation_error.is_empty():
			return values
		values[key] = _read_integer(
			raw_values.get(raw_key),
			"%s.%s" % [field_name, key],
			-2147483648,
			2147483647
		)
		if not validation_error.is_empty():
			return values
	return values


func _read_order_state_map(
	payload: Dictionary
) -> Dictionary[StringName, int]:
	var states: Dictionary[StringName, int] = {}
	if not payload.has("order_states"):
		return states
	var raw_value: Variant = payload.get("order_states")
	if not raw_value is Dictionary:
		validation_error = "order_states must be an object."
		return states
	var raw_states: Dictionary = raw_value as Dictionary
	for raw_key: Variant in raw_states:
		var order_id: StringName = _read_string_name(
			raw_key,
			"order_states key",
			false
		)
		if not validation_error.is_empty():
			return states
		var status_name: StringName = _read_string_name(
			raw_states.get(raw_key),
			"order_states.%s" % order_id,
			false
		)
		if not validation_error.is_empty():
			return states
		var status: int = _order_status_from_name(status_name)
		if status < 0:
			validation_error = "Unknown order status '%s' for %s." % [
				status_name,
				order_id,
			]
			return states
		states[order_id] = status
	return states


func _read_string_name_dictionary(
	payload: Dictionary,
	field_name: String
) -> Dictionary[StringName, StringName]:
	var values: Dictionary[StringName, StringName] = {}
	if not payload.has(field_name):
		return values
	var raw_value: Variant = payload.get(field_name)
	if not raw_value is Dictionary:
		validation_error = "%s must be an object." % field_name
		return values
	var raw_values: Dictionary = raw_value as Dictionary
	for raw_key: Variant in raw_values:
		var key: StringName = _read_string_name(raw_key, "%s key" % field_name, false)
		if not validation_error.is_empty():
			return values
		values[key] = _read_string_name(
			raw_values.get(raw_key),
			"%s.%s" % [field_name, key],
			false
		)
		if not validation_error.is_empty():
			return values
	return values


func _read_demo_ending_flags(
	payload: Dictionary
) -> Dictionary[StringName, Variant]:
	var flags: Dictionary[StringName, Variant] = {}
	if not payload.has("demo_ending_flags"):
		return flags
	var raw_value: Variant = payload.get("demo_ending_flags")
	if not raw_value is Dictionary:
		validation_error = "demo_ending_flags must be an object."
		return flags
	var raw_flags: Dictionary = raw_value as Dictionary
	for raw_key: Variant in raw_flags:
		var key: StringName = _read_string_name(
			raw_key,
			"demo_ending_flags key",
			false
		)
		if not validation_error.is_empty():
			return flags
		var flag_value: Variant = _read_demo_ending_flag_value(
			raw_flags.get(raw_key),
			"demo_ending_flags.%s" % key
		)
		if not validation_error.is_empty():
			return flags
		flags[key] = flag_value
	return flags


func _read_demo_ending_flag_value(value: Variant, field_name: String) -> Variant:
	match typeof(value):
		TYPE_BOOL, TYPE_INT:
			return value
		TYPE_FLOAT:
			if is_finite(float(value)):
				return value
		TYPE_STRING, TYPE_STRING_NAME:
			return _read_string_name(value, field_name, false)
	validation_error = (
		"%s must be a boolean, integer, finite number, or non-empty stable ID."
		% field_name
	)
	return false


func _read_order_run_state(raw: Dictionary) -> OrderRunState:
	var run_state: OrderRunState = OrderRunState.new()
	run_state.reset(_read_optional_id(raw, "order_id"))
	run_state.cargo_integrity = _read_optional_nonnegative_float(
		raw,
		"cargo_integrity",
		OrderRunState.DEFAULT_RESOURCE_VALUE,
		OrderRunState.DEFAULT_RESOURCE_VALUE
	)
	run_state.hull = _read_optional_nonnegative_float(
		raw,
		"hull",
		OrderRunState.DEFAULT_RESOURCE_VALUE,
		OrderRunState.DEFAULT_RESOURCE_VALUE
	)
	run_state.shield = _read_optional_nonnegative_float(
		raw,
		"shield",
		OrderRunState.DEFAULT_RESOURCE_VALUE,
		OrderRunState.DEFAULT_RESOURCE_VALUE
	)
	run_state.fuel = _read_optional_nonnegative_float(
		raw,
		"fuel",
		OrderRunState.DEFAULT_RESOURCE_VALUE,
		OrderRunState.DEFAULT_RESOURCE_VALUE
	)
	run_state.boost_energy = _read_optional_nonnegative_float(
		raw,
		"boost_energy",
		OrderRunState.DEFAULT_RESOURCE_VALUE,
		OrderRunState.DEFAULT_RESOURCE_VALUE
	)
	run_state.active_checkpoint_id = _read_optional_id(raw, "active_checkpoint_id")
	run_state.entry_style = _read_optional_id(raw, "entry_style")
	run_state.entry_duration = _read_optional_nonnegative_float(raw, "entry_duration", 0.0)
	run_state.max_downward_speed = _read_optional_nonnegative_float(
		raw,
		"max_downward_speed",
		0.0
	)
	run_state.max_total_speed = _read_optional_nonnegative_float(raw, "max_total_speed", 0.0)
	run_state.max_risk_or_heat = _read_optional_nonnegative_float(
		raw,
		"max_risk_or_heat",
		0.0,
		1.0
	)
	if raw.has("scenic_trigger_count"):
		run_state.scenic_trigger_count = _read_integer(
			raw.get("scenic_trigger_count"),
			"order_run_state.scenic_trigger_count",
			0,
			2147483647
		)
	if raw.has("late_pull_up_detected"):
		run_state.late_pull_up_detected = _read_bool(
			raw.get("late_pull_up_detected"),
			"order_run_state.late_pull_up_detected"
		)
	if raw.has("collision_count"):
		run_state.collision_count = _read_integer(
			raw.get("collision_count"),
			"order_run_state.collision_count",
			0,
			2147483647
		)
	run_state.landing_result = _read_optional_id(raw, "landing_result")
	run_state.landing_cargo_damage = _read_optional_nonnegative_float(
		raw,
		"landing_cargo_damage",
		0.0,
		OrderRunState.DEFAULT_RESOURCE_VALUE
	)
	run_state.elapsed_time = _read_optional_nonnegative_float(raw, "elapsed_time", 0.0)
	run_state.optional_trigger_ids = _read_id_array(raw, "optional_trigger_ids")
	run_state.result_tags = _read_id_array(raw, "result_tags")
	if not run_state.landing_result.is_empty() and run_state.landing_result not in [
		OrderRunState.LANDING_RESULT_SMOOTH,
		OrderRunState.LANDING_RESULT_ROUGH,
	]:
		validation_error = "Unknown landing result: %s." % run_state.landing_result
	if not run_state.entry_style.is_empty() and not FlightStyleTracker.is_valid_style(
		run_state.entry_style
	):
		validation_error = "Unknown entry style: %s." % run_state.entry_style
	return run_state


func _read_id_array(raw: Dictionary, field_name: String) -> Array[StringName]:
	var ids: Array[StringName] = []
	if not raw.has(field_name):
		return ids
	var raw_value: Variant = raw.get(field_name)
	if not raw_value is Array:
		validation_error = "order_run_state.%s must be an array." % field_name
		return ids
	for raw_id: Variant in raw_value as Array:
		var entry_id: StringName = _read_string_name(
			raw_id,
			"order_run_state.%s" % field_name,
			false
		)
		if not validation_error.is_empty():
			return ids
		if not ids.has(entry_id):
			ids.append(entry_id)
	return ids


func _read_optional_id(source: Dictionary, field_name: String) -> StringName:
	if not source.has(field_name):
		return &""
	return _read_string_name(source.get(field_name), field_name, true)


func _read_optional_nonnegative_float(
	source: Dictionary,
	field_name: String,
	default_value: float,
	maximum: float = INF
) -> float:
	if not source.has(field_name):
		return default_value
	return _read_nonnegative_float(
		source.get(field_name),
		"order_run_state.%s" % field_name,
		maximum
	)


func _read_string_name(value: Variant, field_name: String, allow_empty: bool) -> StringName:
	if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME]:
		validation_error = "%s must be a string." % field_name
		return &""
	var parsed: StringName = StringName(String(value))
	if not allow_empty and parsed.is_empty():
		validation_error = "%s cannot be empty." % field_name
	return parsed


func _read_bool(value: Variant, field_name: String) -> bool:
	if typeof(value) != TYPE_BOOL:
		validation_error = "%s must be a boolean." % field_name
		return false
	return bool(value)


func _read_integer(value: Variant, field_name: String, minimum: int, maximum: int) -> int:
	var parsed: int = 0
	if typeof(value) == TYPE_INT:
		parsed = int(value)
	elif typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), roundf(float(value))):
		parsed = roundi(float(value))
	else:
		validation_error = "%s must be an integer." % field_name
		return 0
	if parsed < minimum or parsed > maximum:
		validation_error = "%s is outside the supported range." % field_name
		return 0
	return parsed


func _read_nonnegative_float(
	value: Variant,
	field_name: String,
	maximum: float = INF
) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		validation_error = "%s must be numeric." % field_name
		return 0.0
	var parsed: float = float(value)
	if not is_finite(parsed) or parsed < 0.0 or parsed > maximum:
		validation_error = "%s is outside the supported range." % field_name
		return 0.0
	return parsed


func _read_travel_state(value: Variant) -> GameStateModel.TravelState:
	var state_name: StringName = _read_string_name(value, "travel_state", false)
	match state_name:
		&"IDLE":
			return GameStateModel.TravelState.IDLE
		&"DESTINATION_CONFIRMED":
			return GameStateModel.TravelState.DESTINATION_CONFIRMED
		&"DEPARTURE":
			return GameStateModel.TravelState.DEPARTURE
		&"CRUISE":
			return GameStateModel.TravelState.CRUISE
		&"APPROACH":
			return GameStateModel.TravelState.APPROACH
		&"COMPLETED":
			return GameStateModel.TravelState.COMPLETED
	validation_error = "Unknown travel_state: %s." % state_name
	return GameStateModel.TravelState.IDLE


static func _travel_state_to_name(state: GameStateModel.TravelState) -> String:
	match state:
		GameStateModel.TravelState.DESTINATION_CONFIRMED:
			return "DESTINATION_CONFIRMED"
		GameStateModel.TravelState.DEPARTURE:
			return "DEPARTURE"
		GameStateModel.TravelState.CRUISE:
			return "CRUISE"
		GameStateModel.TravelState.APPROACH:
			return "APPROACH"
		GameStateModel.TravelState.COMPLETED:
			return "COMPLETED"
		_:
			return "IDLE"


static func _order_status_from_name(status_name: StringName) -> int:
	match status_name:
		&"AVAILABLE":
			return GameStateModel.OrderStatus.AVAILABLE
		&"ACCEPTED":
			return GameStateModel.OrderStatus.ACCEPTED
		&"COMPLETED":
			return GameStateModel.OrderStatus.COMPLETED
		&"FAILED":
			return GameStateModel.OrderStatus.FAILED
		&"ABANDONED":
			return GameStateModel.OrderStatus.ABANDONED
		&"ARCHIVED":
			return GameStateModel.OrderStatus.ARCHIVED
	return -1


static func _order_status_to_name(status: int) -> String:
	match status:
		GameStateModel.OrderStatus.ACCEPTED:
			return "ACCEPTED"
		GameStateModel.OrderStatus.COMPLETED:
			return "COMPLETED"
		GameStateModel.OrderStatus.FAILED:
			return "FAILED"
		GameStateModel.OrderStatus.ABANDONED:
			return "ABANDONED"
		GameStateModel.OrderStatus.ARCHIVED:
			return "ARCHIVED"
	return "AVAILABLE"


static func _serialize_configuration(
	configuration: Dictionary[StringName, StringName]
) -> Dictionary[String, Variant]:
	var serialized: Dictionary[String, Variant] = {}
	for slot_id: StringName in ShipLoadoutRules.SLOT_ORDER:
		serialized[String(slot_id)] = String(configuration.get(slot_id, &""))
	return serialized


static func _serialize_integer_map(
	values: Dictionary[StringName, int]
) -> Dictionary[String, Variant]:
	var serialized: Dictionary[String, Variant] = {}
	for key: StringName in values:
		serialized[String(key)] = values[key]
	return serialized


static func _serialize_order_state_map(
	states: Dictionary[StringName, int]
) -> Dictionary[String, Variant]:
	var serialized: Dictionary[String, Variant] = {}
	var order_ids: Array[StringName] = []
	for order_id: StringName in states:
		order_ids.append(order_id)
	order_ids.sort()
	for order_id: StringName in order_ids:
		serialized[String(order_id)] = _order_status_to_name(
			states.get(order_id, GameStateModel.OrderStatus.AVAILABLE)
		)
	return serialized


static func _serialize_string_name_map(
	values: Dictionary[StringName, StringName]
) -> Dictionary[String, Variant]:
	var serialized: Dictionary[String, Variant] = {}
	for key: StringName in values:
		serialized[String(key)] = String(values[key])
	return serialized


static func _serialize_variant_map(
	values: Dictionary[StringName, Variant]
) -> Dictionary[String, Variant]:
	var serialized: Dictionary[String, Variant] = {}
	for key: StringName in values:
		var value: Variant = values[key]
		serialized[String(key)] = (
			String(value)
			if typeof(value) == TYPE_STRING_NAME
			else value
		)
	return serialized


static func _serialize_enabled_ids(enabled_ids: Dictionary[StringName, bool]) -> Array[String]:
	var serialized: Array[String] = []
	for entry_id: StringName in enabled_ids:
		if enabled_ids.get(entry_id, false):
			serialized.append(String(entry_id))
	serialized.sort()
	return serialized


static func _serialize_order_run_state(run_state: OrderRunState) -> Dictionary[String, Variant]:
	var safe_state: OrderRunState = run_state
	if safe_state == null:
		safe_state = OrderRunState.new()
		safe_state.reset()
	return {
		"order_id": String(safe_state.order_id),
		"cargo_integrity": safe_state.cargo_integrity,
		"hull": safe_state.hull,
		"shield": safe_state.shield,
		"fuel": safe_state.fuel,
		"boost_energy": safe_state.boost_energy,
		"active_checkpoint_id": String(safe_state.active_checkpoint_id),
		"entry_style": String(safe_state.entry_style),
		"entry_duration": safe_state.entry_duration,
		"max_downward_speed": safe_state.max_downward_speed,
		"max_total_speed": safe_state.max_total_speed,
		"max_risk_or_heat": safe_state.max_risk_or_heat,
		"scenic_trigger_count": safe_state.scenic_trigger_count,
		"late_pull_up_detected": safe_state.late_pull_up_detected,
		"collision_count": safe_state.collision_count,
		"landing_result": String(safe_state.landing_result),
		"landing_cargo_damage": safe_state.landing_cargo_damage,
		"elapsed_time": safe_state.elapsed_time,
		"optional_trigger_ids": _serialize_id_array(safe_state.optional_trigger_ids),
		"result_tags": _serialize_id_array(safe_state.result_tags),
	}


static func _serialize_id_array(ids: Array[StringName]) -> Array[String]:
	var serialized: Array[String] = []
	for entry_id: StringName in ids:
		if not entry_id.is_empty() and not serialized.has(String(entry_id)):
			serialized.append(String(entry_id))
	serialized.sort()
	return serialized


static func _copy_string_name_map(
	source: Dictionary[StringName, StringName]
) -> Dictionary[StringName, StringName]:
	var copy: Dictionary[StringName, StringName] = {}
	for key: StringName in source:
		copy[key] = source[key]
	return copy


static func _copy_unique_id_array(source: Array[StringName]) -> Array[StringName]:
	var copy: Array[StringName] = []
	for entry_id: StringName in source:
		_append_unique_id(copy, entry_id)
	return copy


static func _copy_integer_map(
	source: Dictionary[StringName, int]
) -> Dictionary[StringName, int]:
	var copy: Dictionary[StringName, int] = {}
	for key: StringName in source:
		copy[key] = source[key]
	return copy


static func _copy_order_state_map(
	source: Dictionary[StringName, int]
) -> Dictionary[StringName, int]:
	var copy: Dictionary[StringName, int] = {}
	for order_id: StringName in source:
		copy[order_id] = source[order_id]
	return copy


static func _copy_variant_map(
	source: Dictionary[StringName, Variant]
) -> Dictionary[StringName, Variant]:
	var copy: Dictionary[StringName, Variant] = {}
	for key: StringName in source:
		copy[key] = source[key]
	return copy


static func _append_unique_id(values: Array[StringName], entry_id: StringName) -> void:
	if not values.has(entry_id):
		values.append(entry_id)


static func _copy_enabled_ids(
	source: Dictionary[StringName, bool]
) -> Dictionary[StringName, bool]:
	var copy: Dictionary[StringName, bool] = {}
	for entry_id: StringName in source:
		if source.get(entry_id, false):
			copy[entry_id] = true
	return copy


static func _copy_order_run_state(source: OrderRunState) -> OrderRunState:
	var copy: OrderRunState = OrderRunState.new()
	if source == null:
		copy.reset()
		return copy
	copy.order_id = source.order_id
	copy.cargo_integrity = source.cargo_integrity
	copy.hull = source.hull
	copy.shield = source.shield
	copy.fuel = source.fuel
	copy.boost_energy = source.boost_energy
	copy.active_checkpoint_id = source.active_checkpoint_id
	copy.entry_style = source.entry_style
	copy.entry_duration = source.entry_duration
	copy.max_downward_speed = source.max_downward_speed
	copy.max_total_speed = source.max_total_speed
	copy.max_risk_or_heat = source.max_risk_or_heat
	copy.scenic_trigger_count = source.scenic_trigger_count
	copy.late_pull_up_detected = source.late_pull_up_detected
	copy.collision_count = source.collision_count
	copy.landing_result = source.landing_result
	copy.landing_cargo_damage = source.landing_cargo_damage
	copy.elapsed_time = source.elapsed_time
	copy.optional_trigger_ids = source.optional_trigger_ids.duplicate()
	copy.result_tags = source.result_tags.duplicate()
	return copy
