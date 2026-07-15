class_name GameStateModel
extends Node

## Session data that must outlive stage scenes; persistence is intentionally handled later.
signal runtime_state_reset
signal order_status_changed(order_id: StringName, status: OrderStatus)
signal ship_configuration_changed
signal departure_readiness_changed(confirmed: bool)

enum OrderStatus {
	NOT_ACCEPTED,
	ACCEPTED,
	COMPLETED,
}

const ORDER_ERROR_MISSING_DATA: StringName = &"missing_data"
const ORDER_ERROR_STORY_REQUIREMENT: StringName = &"story_requirement"
const ORDER_ERROR_ACTIVE_ORDER: StringName = &"active_order"
const ORDER_ERROR_ALREADY_ACCEPTED: StringName = &"already_accepted"
const ORDER_ERROR_ALREADY_COMPLETED: StringName = &"already_completed"
const ORDER_ERROR_NOT_ACTIVE: StringName = &"not_active"

const LOADOUT_ERROR_MISSING_DATA: StringName = &"missing_data"
const LOADOUT_ERROR_ORDER_NOT_ACCEPTED: StringName = &"order_not_accepted"
const LOADOUT_ERROR_MISSING_REQUIRED_MODULES: StringName = &"missing_required_modules"
const LOADOUT_ERROR_INVALID_MODULE: StringName = &"invalid_module"
const LOADOUT_ERROR_MODULE_NOT_EQUIPPED: StringName = &"module_not_equipped"

var current_order_id: StringName = &""
var destination_id: StringName = &""
var cargo_id: StringName = &""
var ship_configuration: Dictionary[StringName, StringName] = {}
var story_flags: Dictionary[StringName, bool] = {}
var read_dialogue_ids: Dictionary[StringName, bool] = {}
var completed_order_ids: Dictionary[StringName, bool] = {}
var last_order_error: StringName = &""
var departure_confirmed: bool = false
var last_loadout_error: StringName = &""


func _init() -> void:
	ship_configuration = ShipLoadoutRules.create_default_configuration()


func reset_runtime_state() -> void:
	current_order_id = &""
	destination_id = &""
	cargo_id = &""
	ship_configuration = ShipLoadoutRules.create_default_configuration()
	story_flags.clear()
	read_dialogue_ids.clear()
	completed_order_ids.clear()
	last_order_error = &""
	departure_confirmed = false
	last_loadout_error = &""
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
	departure_confirmed = false
	last_loadout_error = &""
	order_status_changed.emit(order.id, OrderStatus.ACCEPTED)
	departure_readiness_changed.emit(false)
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
	order_status_changed.emit(order.id, OrderStatus.COMPLETED)
	departure_readiness_changed.emit(false)
	return true


func has_completed_order(order_id: StringName) -> bool:
	return not order_id.is_empty() and completed_order_ids.get(order_id, false)


func equip_ship_module(module: ShipModuleDefinition) -> bool:
	last_loadout_error = &""
	if module == null or module.id.is_empty():
		last_loadout_error = LOADOUT_ERROR_INVALID_MODULE
		return false
	var slot_id: StringName = ShipLoadoutRules.get_slot_id(module.slot_type)
	if slot_id.is_empty():
		last_loadout_error = LOADOUT_ERROR_INVALID_MODULE
		return false
	if ship_configuration.get(slot_id, &"") == module.id:
		return true
	ship_configuration[slot_id] = module.id
	_invalidate_departure_confirmation()
	ship_configuration_changed.emit()
	return true


func unequip_ship_module(module: ShipModuleDefinition) -> bool:
	last_loadout_error = &""
	if module == null or module.id.is_empty():
		last_loadout_error = LOADOUT_ERROR_INVALID_MODULE
		return false
	var slot_id: StringName = ShipLoadoutRules.get_slot_id(module.slot_type)
	if slot_id.is_empty():
		last_loadout_error = LOADOUT_ERROR_INVALID_MODULE
		return false
	if ship_configuration.get(slot_id, &"") != module.id:
		last_loadout_error = LOADOUT_ERROR_MODULE_NOT_EQUIPPED
		return false
	ship_configuration[slot_id] = &""
	_invalidate_departure_confirmation()
	ship_configuration_changed.emit()
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
	return true


func is_departure_confirmed_for_order(order: OrderDefinition) -> bool:
	return order != null and current_order_id == order.id and departure_confirmed


func set_story_flag(flag_id: StringName, enabled: bool = true) -> void:
	story_flags[flag_id] = enabled


func has_story_flag(flag_id: StringName) -> bool:
	return story_flags.get(flag_id, false)


func mark_dialogue_line_read(sequence_id: StringName, line_id: StringName) -> void:
	read_dialogue_ids[_get_dialogue_read_id(sequence_id, line_id)] = true


func has_read_dialogue_line(sequence_id: StringName, line_id: StringName) -> bool:
	return read_dialogue_ids.get(_get_dialogue_read_id(sequence_id, line_id), false)


func _get_dialogue_read_id(sequence_id: StringName, line_id: StringName) -> StringName:
	return StringName("%s/%s" % [sequence_id, line_id])


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
	departure_readiness_changed.emit(false)
