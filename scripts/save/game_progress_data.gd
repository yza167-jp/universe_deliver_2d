class_name GameProgressData
extends RefCounted

const CURRENT_SCHEMA_VERSION: int = 1
const DEFAULT_SETTINGS_REFERENCE: StringName = &"local_settings"

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

	var payload: Dictionary = {}
	if source.has("game_progress"):
		var raw_payload: Variant = source.get("game_progress")
		if not raw_payload is Dictionary:
			validation_error = "game_progress must be an object."
			return
		payload = raw_payload as Dictionary
	elif stored_version == 0:
		payload = source
	else:
		validation_error = "game_progress is missing."
		return

	settings_reference = _read_string_name(
		source.get("settings_reference", DEFAULT_SETTINGS_REFERENCE),
		"settings_reference",
		false
	)
	if not validation_error.is_empty():
		return
	if source.has("last_saved_at_unix"):
		last_saved_at_unix = _read_integer(
			source.get("last_saved_at_unix"),
			"last_saved_at_unix",
			0,
			9223372036854775807
		)
	if source.has("build_version"):
		build_version = String(
			_read_string_name(source.get("build_version"), "build_version", true)
		)
	if not validation_error.is_empty():
		return

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
	if not validation_error.is_empty():
		return
	_validate_consistency()


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
			and not completed_order_ids.get(order_run_state.order_id, false)
		):
			validation_error = "Completed order-run state has no completed-order record."
			return
	else:
		if destination_id.is_empty() or cargo_id.is_empty():
			validation_error = "An active order requires destination and cargo IDs."
			return
		if completed_order_ids.get(current_order_id, false):
			validation_error = "An order cannot be active and completed at the same time."
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
	elif not travel_destination_id.is_empty():
		validation_error = "Idle travel cannot retain a destination ID."


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


static func _serialize_configuration(
	configuration: Dictionary[StringName, StringName]
) -> Dictionary[String, Variant]:
	var serialized: Dictionary[String, Variant] = {}
	for slot_id: StringName in ShipLoadoutRules.SLOT_ORDER:
		serialized[String(slot_id)] = String(configuration.get(slot_id, &""))
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
