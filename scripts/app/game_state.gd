class_name GameStateModel
extends Node

## Session data that outlives stage scenes; SaveService owns disk persistence.
signal runtime_state_reset
signal runtime_state_restored
signal order_status_changed(order_id: StringName, status: OrderStatus)
signal ship_configuration_changed
signal departure_readiness_changed(confirmed: bool)
signal travel_state_changed(state: TravelState, destination_id: StringName)
signal progress_changed(credits: int)
signal persistent_state_changed

enum OrderStatus {
	NOT_ACCEPTED,
	ACCEPTED,
	COMPLETED,
}

enum TravelState {
	IDLE,
	DESTINATION_CONFIRMED,
	DEPARTURE,
	CRUISE,
	APPROACH,
	COMPLETED,
}

const ORDER_ERROR_MISSING_DATA: StringName = &"missing_data"
const ORDER_ERROR_STORY_REQUIREMENT: StringName = &"story_requirement"
const ORDER_ERROR_ACTIVE_ORDER: StringName = &"active_order"
const ORDER_ERROR_ALREADY_ACCEPTED: StringName = &"already_accepted"
const ORDER_ERROR_ALREADY_COMPLETED: StringName = &"already_completed"
const ORDER_ERROR_NOT_ACTIVE: StringName = &"not_active"
const ORDER_ERROR_INVALID_SETTLEMENT: StringName = &"invalid_settlement"

const LOADOUT_ERROR_MISSING_DATA: StringName = &"missing_data"
const LOADOUT_ERROR_ORDER_NOT_ACCEPTED: StringName = &"order_not_accepted"
const LOADOUT_ERROR_MISSING_REQUIRED_MODULES: StringName = &"missing_required_modules"
const LOADOUT_ERROR_INVALID_MODULE: StringName = &"invalid_module"
const LOADOUT_ERROR_MODULE_NOT_EQUIPPED: StringName = &"module_not_equipped"

const TRAVEL_ERROR_MISSING_DATA: StringName = &"missing_data"
const TRAVEL_ERROR_ORDER_NOT_ACTIVE: StringName = &"order_not_active"
const TRAVEL_ERROR_DEPARTURE_NOT_CONFIRMED: StringName = &"departure_not_confirmed"
const TRAVEL_ERROR_DESTINATION_NOT_ALLOWED: StringName = &"destination_not_allowed"
const TRAVEL_ERROR_ALREADY_STARTED: StringName = &"already_started"
const TRAVEL_ERROR_ALREADY_COMPLETED: StringName = &"already_completed"
const TRAVEL_ERROR_INVALID_TRANSITION: StringName = &"invalid_transition"

var current_order_id: StringName = &""
var destination_id: StringName = &""
var cargo_id: StringName = &""
var ship_configuration: Dictionary[StringName, StringName] = {}
var story_flags: Dictionary[StringName, bool] = {}
var read_dialogue_ids: Dictionary[StringName, bool] = {}
var completed_order_ids: Dictionary[StringName, bool] = {}
var credits: int = 0
var station_upgrade_ids: Dictionary[StringName, bool] = {}
var last_order_error: StringName = &""
var departure_confirmed: bool = false
var last_loadout_error: StringName = &""
var travel_state: TravelState = TravelState.IDLE
var travel_destination_id: StringName = &""
var last_travel_error: StringName = &""
var order_run_state: OrderRunState = OrderRunState.new()


func _init() -> void:
	ship_configuration = ShipLoadoutRules.create_default_configuration()
	order_run_state.reset()


func reset_runtime_state() -> void:
	current_order_id = &""
	destination_id = &""
	cargo_id = &""
	ship_configuration = ShipLoadoutRules.create_default_configuration()
	story_flags.clear()
	read_dialogue_ids.clear()
	completed_order_ids.clear()
	credits = 0
	station_upgrade_ids.clear()
	last_order_error = &""
	departure_confirmed = false
	last_loadout_error = &""
	travel_state = TravelState.IDLE
	travel_destination_id = &""
	last_travel_error = &""
	if order_run_state == null:
		order_run_state = OrderRunState.new()
	else:
		order_run_state.reset()
	runtime_state_reset.emit()


func get_order_status(order_id: StringName) -> OrderStatus:
	if has_completed_order(order_id):
		return OrderStatus.COMPLETED
	if not order_id.is_empty() and current_order_id == order_id:
		return OrderStatus.ACCEPTED
	return OrderStatus.NOT_ACCEPTED


func get_order_acceptance_error(order: OrderDefinition) -> StringName:
	if not _has_required_order_data(order):
		return ORDER_ERROR_MISSING_DATA
	if has_completed_order(order.id):
		return ORDER_ERROR_ALREADY_COMPLETED
	if current_order_id == order.id:
		return ORDER_ERROR_ALREADY_ACCEPTED
	if not current_order_id.is_empty():
		return ORDER_ERROR_ACTIVE_ORDER
	for requirement: StringName in order.story_requirements:
		if not has_story_flag(requirement):
			return ORDER_ERROR_STORY_REQUIREMENT
	return &""


func can_accept_order(order: OrderDefinition) -> bool:
	return get_order_acceptance_error(order).is_empty()


func accept_order(order: OrderDefinition) -> bool:
	last_order_error = get_order_acceptance_error(order)
	if not last_order_error.is_empty():
		return false
	current_order_id = order.id
	destination_id = order.destination_planet.id
	cargo_id = order.cargo.id
	order_run_state.reset(order.id)
	departure_confirmed = false
	last_loadout_error = &""
	_reset_travel_state(false)
	order_status_changed.emit(order.id, OrderStatus.ACCEPTED)
	departure_readiness_changed.emit(false)
	persistent_state_changed.emit()
	return true


## Moves the active order forward without exposing a main-order cancellation transition.
func complete_current_order(order: OrderDefinition) -> bool:
	last_order_error = &""
	if not _has_required_order_data(order):
		last_order_error = ORDER_ERROR_MISSING_DATA
		return false
	if current_order_id != order.id:
		last_order_error = ORDER_ERROR_NOT_ACTIVE
		return false
	completed_order_ids[order.id] = true
	for completion_flag: StringName in order.completion_flags:
		set_story_flag(completion_flag)
	current_order_id = &""
	departure_confirmed = false
	last_loadout_error = &""
	_reset_travel_state(false)
	order_status_changed.emit(order.id, OrderStatus.COMPLETED)
	departure_readiness_changed.emit(false)
	persistent_state_changed.emit()
	return true


## Commits the one-way main-order reward after the result has been calculated.
func settle_current_order(
	order: OrderDefinition,
	settlement: OrderSettlementResult,
	station_upgrade_id: StringName,
	settlement_flags: Array[StringName] = []
) -> bool:
	last_order_error = &""
	if (
		not _has_required_order_data(order)
		or settlement == null
		or settlement.order_id != order.id
		or settlement.total_reward < 0
		or station_upgrade_id.is_empty()
	):
		last_order_error = ORDER_ERROR_INVALID_SETTLEMENT
		return false
	if has_completed_order(order.id):
		last_order_error = ORDER_ERROR_ALREADY_COMPLETED
		return false
	if current_order_id != order.id:
		last_order_error = ORDER_ERROR_NOT_ACTIVE
		return false
	if not complete_current_order(order):
		return false

	credits += settlement.total_reward
	station_upgrade_ids[station_upgrade_id] = true
	for settlement_flag: StringName in settlement_flags:
		if not settlement_flag.is_empty():
			set_story_flag(settlement_flag)
	destination_id = &""
	cargo_id = &""
	progress_changed.emit(credits)
	persistent_state_changed.emit()
	return true


func has_completed_order(order_id: StringName) -> bool:
	return not order_id.is_empty() and completed_order_ids.get(order_id, false)


func get_credits() -> int:
	return credits


func has_station_upgrade(upgrade_id: StringName) -> bool:
	return not upgrade_id.is_empty() and station_upgrade_ids.get(upgrade_id, false)


func get_active_order_run_state() -> OrderRunState:
	if current_order_id.is_empty():
		return null
	if order_run_state == null or order_run_state.order_id != current_order_id:
		order_run_state = OrderRunState.new()
		order_run_state.reset(current_order_id)
	return order_run_state


func get_order_entry_style() -> StringName:
	return &"" if order_run_state == null else order_run_state.entry_style


func has_order_entry_style(style: StringName) -> bool:
	return (
		not style.is_empty()
		and get_order_entry_style() == style
	)


func equip_ship_module(module: ShipModuleDefinition) -> bool:
	last_loadout_error = &""
	if module == null or module.id.is_empty():
		last_loadout_error = LOADOUT_ERROR_INVALID_MODULE
		return false
	var slot_id: StringName = ShipLoadoutRules.get_configuration_slot_id(module)
	if slot_id.is_empty() or not ShipLoadoutRules.is_valid_slot_id(slot_id):
		last_loadout_error = LOADOUT_ERROR_INVALID_MODULE
		return false
	if ship_configuration.get(slot_id, &"") == module.id:
		return true
	ship_configuration[slot_id] = module.id
	_invalidate_departure_confirmation()
	ship_configuration_changed.emit()
	persistent_state_changed.emit()
	return true


func unequip_ship_module(module: ShipModuleDefinition) -> bool:
	last_loadout_error = &""
	if module == null or module.id.is_empty():
		last_loadout_error = LOADOUT_ERROR_INVALID_MODULE
		return false
	var slot_id: StringName = ShipLoadoutRules.get_configuration_slot_id(module)
	if slot_id.is_empty() or not ShipLoadoutRules.is_valid_slot_id(slot_id):
		last_loadout_error = LOADOUT_ERROR_INVALID_MODULE
		return false
	if ship_configuration.get(slot_id, &"") != module.id:
		last_loadout_error = LOADOUT_ERROR_MODULE_NOT_EQUIPPED
		return false
	ship_configuration[slot_id] = &""
	_invalidate_departure_confirmation()
	ship_configuration_changed.emit()
	persistent_state_changed.emit()
	return true


func is_ship_module_equipped(module_id: StringName) -> bool:
	return ShipLoadoutRules.is_module_equipped(ship_configuration, module_id)


func has_ship_capability(
	capability_tag: StringName,
	module_catalog: Array[ShipModuleDefinition]
) -> bool:
	return ShipLoadoutRules.has_capability(
		ship_configuration,
		module_catalog,
		capability_tag
	)


func get_missing_required_modules(order: OrderDefinition) -> Array[ShipModuleDefinition]:
	return ShipLoadoutRules.get_missing_required_modules(order, ship_configuration)


func get_departure_confirmation_error(order: OrderDefinition) -> StringName:
	if order == null or order.id.is_empty():
		return LOADOUT_ERROR_MISSING_DATA
	if current_order_id != order.id:
		return LOADOUT_ERROR_ORDER_NOT_ACCEPTED
	if not get_missing_required_modules(order).is_empty():
		return LOADOUT_ERROR_MISSING_REQUIRED_MODULES
	return &""


func can_confirm_departure(order: OrderDefinition) -> bool:
	return get_departure_confirmation_error(order).is_empty()


func confirm_departure(order: OrderDefinition) -> bool:
	last_loadout_error = get_departure_confirmation_error(order)
	if not last_loadout_error.is_empty():
		return false
	if departure_confirmed:
		return true
	departure_confirmed = true
	departure_readiness_changed.emit(true)
	persistent_state_changed.emit()
	return true


func is_departure_confirmed_for_order(order: OrderDefinition) -> bool:
	return order != null and current_order_id == order.id and departure_confirmed


func get_travel_start_error(
	order: OrderDefinition,
	requested_destination_id: StringName
) -> StringName:
	if (
		order == null
		or order.id.is_empty()
		or order.destination_planet == null
		or order.destination_planet.id.is_empty()
		or requested_destination_id.is_empty()
	):
		return TRAVEL_ERROR_MISSING_DATA
	if current_order_id != order.id:
		return TRAVEL_ERROR_ORDER_NOT_ACTIVE
	if not departure_confirmed:
		return TRAVEL_ERROR_DEPARTURE_NOT_CONFIRMED
	if (
		requested_destination_id != order.destination_planet.id
		or destination_id != order.destination_planet.id
	):
		return TRAVEL_ERROR_DESTINATION_NOT_ALLOWED
	if travel_state == TravelState.COMPLETED:
		return TRAVEL_ERROR_ALREADY_COMPLETED
	if travel_state in [TravelState.DEPARTURE, TravelState.CRUISE, TravelState.APPROACH]:
		return TRAVEL_ERROR_ALREADY_STARTED
	return &""


func confirm_travel_destination(
	order: OrderDefinition,
	requested_destination_id: StringName
) -> bool:
	last_travel_error = get_travel_start_error(order, requested_destination_id)
	if not last_travel_error.is_empty():
		return false
	if travel_state == TravelState.DESTINATION_CONFIRMED:
		if travel_destination_id == requested_destination_id:
			return true
		last_travel_error = TRAVEL_ERROR_INVALID_TRANSITION
		return false
	travel_destination_id = requested_destination_id
	_set_travel_state(TravelState.DESTINATION_CONFIRMED)
	return true


func begin_travel(order: OrderDefinition, requested_destination_id: StringName) -> bool:
	last_travel_error = get_travel_start_error(order, requested_destination_id)
	if not last_travel_error.is_empty():
		return false
	if travel_state == TravelState.IDLE:
		if not confirm_travel_destination(order, requested_destination_id):
			return false
	if (
		travel_state != TravelState.DESTINATION_CONFIRMED
		or travel_destination_id != requested_destination_id
	):
		last_travel_error = TRAVEL_ERROR_INVALID_TRANSITION
		return false
	last_travel_error = &""
	_set_travel_state(TravelState.DEPARTURE)
	return true


func advance_travel_state(next_state: TravelState) -> bool:
	last_travel_error = &""
	var expected_state: TravelState = TravelState.IDLE
	match travel_state:
		TravelState.DEPARTURE:
			expected_state = TravelState.CRUISE
		TravelState.CRUISE:
			expected_state = TravelState.APPROACH
		TravelState.APPROACH:
			expected_state = TravelState.COMPLETED
		_:
			last_travel_error = TRAVEL_ERROR_INVALID_TRANSITION
			return false
	if next_state != expected_state:
		last_travel_error = TRAVEL_ERROR_INVALID_TRANSITION
		return false
	_set_travel_state(next_state)
	if travel_state == TravelState.COMPLETED:
		mark_travel_seen(travel_destination_id)
	return true


func complete_travel() -> bool:
	last_travel_error = &""
	if travel_state not in [
		TravelState.DEPARTURE,
		TravelState.CRUISE,
		TravelState.APPROACH,
	]:
		last_travel_error = TRAVEL_ERROR_INVALID_TRANSITION
		return false
	_set_travel_state(TravelState.COMPLETED)
	mark_travel_seen(travel_destination_id)
	return true


func mark_travel_seen(travel_destination: StringName) -> void:
	if travel_destination.is_empty():
		return
	set_story_flag(_get_travel_seen_flag(travel_destination))


func has_seen_travel(travel_destination: StringName) -> bool:
	return (
		not travel_destination.is_empty()
		and has_story_flag(_get_travel_seen_flag(travel_destination))
	)


func set_story_flag(flag_id: StringName, enabled: bool = true) -> void:
	if flag_id.is_empty():
		return
	var previous_value: bool = story_flags.get(flag_id, false)
	if previous_value == enabled:
		return
	if enabled:
		story_flags[flag_id] = true
	else:
		story_flags.erase(flag_id)
	persistent_state_changed.emit()


func has_story_flag(flag_id: StringName) -> bool:
	return story_flags.get(flag_id, false)


func mark_dialogue_line_read(sequence_id: StringName, line_id: StringName) -> void:
	if sequence_id.is_empty() or line_id.is_empty():
		return
	var read_id: StringName = _get_dialogue_read_id(sequence_id, line_id)
	if read_dialogue_ids.get(read_id, false):
		return
	read_dialogue_ids[read_id] = true
	persistent_state_changed.emit()


func has_read_dialogue_line(sequence_id: StringName, line_id: StringName) -> bool:
	return read_dialogue_ids.get(_get_dialogue_read_id(sequence_id, line_id), false)


func _get_dialogue_read_id(sequence_id: StringName, line_id: StringName) -> StringName:
	return StringName("%s/%s" % [sequence_id, line_id])


func _get_travel_seen_flag(travel_destination: StringName) -> StringName:
	return StringName("travel_seen/%s" % travel_destination)


func _has_required_order_data(order: OrderDefinition) -> bool:
	if (
		order == null
		or order.id.is_empty()
		or order.display_name_key.is_empty()
		or order.sender == null
		or order.sender.id.is_empty()
		or order.recipient == null
		or order.recipient.id.is_empty()
		or order.destination_planet == null
		or order.destination_planet.id.is_empty()
		or order.cargo == null
		or order.cargo.id.is_empty()
		or order.customer_history_keys.is_empty()
	):
		return false
	for module: ShipModuleDefinition in order.required_modules:
		if module == null or module.id.is_empty():
			return false
	return true


func _invalidate_departure_confirmation() -> void:
	last_loadout_error = &""
	if not departure_confirmed:
		return
	departure_confirmed = false
	if travel_state in [TravelState.IDLE, TravelState.DESTINATION_CONFIRMED]:
		_reset_travel_state()
	departure_readiness_changed.emit(false)


func _set_travel_state(next_state: TravelState) -> void:
	travel_state = next_state
	travel_state_changed.emit(travel_state, travel_destination_id)


func _reset_travel_state(emit_change: bool = true) -> void:
	travel_state = TravelState.IDLE
	travel_destination_id = &""
	last_travel_error = &""
	if emit_change:
		travel_state_changed.emit(travel_state, travel_destination_id)
