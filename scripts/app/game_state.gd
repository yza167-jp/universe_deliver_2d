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
	AVAILABLE,
	ACCEPTED,
	COMPLETED,
	FAILED,
	ABANDONED,
	ARCHIVED,
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
const ORDER_ERROR_ARCHIVED: StringName = &"archived"
const ORDER_ERROR_ARCHIVED_ONLY: StringName = &"archived_only"
const ORDER_ERROR_NOT_ACTIVE: StringName = &"not_active"
const ORDER_ERROR_INVALID_SETTLEMENT: StringName = &"invalid_settlement"
const ORDER_ERROR_INVALID_TRANSITION: StringName = &"invalid_order_transition"
const ORDER_ERROR_INVALID_REWARD: StringName = &"invalid_order_reward"
const ORDER_ERROR_INVALID_TIMING: StringName = &"invalid_order_timing"
const ORDER_ERROR_MAIN_CANNOT_ABANDON: StringName = &"main_order_cannot_abandon"
const ORDER_ERROR_MAIN_RETRY_REQUIRED: StringName = &"main_order_retry_required"
const ORDER_ERROR_RETRY_NOT_ALLOWED: StringName = &"retry_not_allowed"
const ORDER_ERROR_REGISTERED_ONLY: StringName = &"registered_only"
const ORDER_ERROR_PLANET_REGISTERED_ONLY: StringName = &"planet_registered_only"
const ORDER_ERROR_MISSING_ROUTE: StringName = &"missing_route"

const LOADOUT_ERROR_MISSING_DATA: StringName = &"missing_data"
const LOADOUT_ERROR_ORDER_NOT_ACCEPTED: StringName = &"order_not_accepted"
const LOADOUT_ERROR_MISSING_REQUIRED_MODULES: StringName = &"missing_required_modules"
const LOADOUT_ERROR_INVALID_MODULE: StringName = &"invalid_module"
const LOADOUT_ERROR_MODULE_NOT_EQUIPPED: StringName = &"module_not_equipped"
const LOADOUT_ERROR_ORDER_REGISTERED_ONLY: StringName = &"registered_only"
const LOADOUT_ERROR_PLANET_REGISTERED_ONLY: StringName = &"planet_registered_only"
const LOADOUT_ERROR_MISSING_ROUTE: StringName = &"missing_route"

const TRAVEL_ERROR_MISSING_DATA: StringName = &"missing_data"
const TRAVEL_ERROR_ORDER_NOT_ACTIVE: StringName = &"order_not_active"
const TRAVEL_ERROR_DEPARTURE_NOT_CONFIRMED: StringName = &"departure_not_confirmed"
const TRAVEL_ERROR_DESTINATION_NOT_ALLOWED: StringName = &"destination_not_allowed"
const TRAVEL_ERROR_ALREADY_STARTED: StringName = &"already_started"
const TRAVEL_ERROR_ALREADY_COMPLETED: StringName = &"already_completed"
const TRAVEL_ERROR_INVALID_TRANSITION: StringName = &"invalid_transition"
const TRAVEL_ERROR_ORDER_REGISTERED_ONLY: StringName = &"registered_only"
const TRAVEL_ERROR_PLANET_REGISTERED_ONLY: StringName = &"planet_registered_only"
const TRAVEL_ERROR_MISSING_ROUTE: StringName = &"missing_route"

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
	main_story_chapter = &""
	unlocked_planet_ids.clear()
	planet_relation_values.clear()
	planet_permission_ids.clear()
	codex_entry_ids.clear()
	souvenir_ids.clear()
	completed_side_order_ids.clear()
	failed_side_order_ids.clear()
	order_states.clear()
	reward_applied_order_ids.clear()
	station_state_level = 0
	ship_upgrade_ids.clear()
	revisit_state.clear()
	demo_ending_flags.clear()
	last_stable_station_state = &""
	if order_run_state == null:
		order_run_state = OrderRunState.new()
	else:
		order_run_state.reset()
	runtime_state_reset.emit()


func get_main_story_chapter() -> StringName:
	return main_story_chapter


func has_reached_main_story_chapter(chapter_id: StringName) -> bool:
	return M1ProgressRules.has_reached_chapter(main_story_chapter, chapter_id)


func get_next_main_story_chapter() -> StringName:
	var current_index: int = M1ProgressRules.get_chapter_index(main_story_chapter)
	if current_index < 0 or current_index + 1 >= M1ProgressRules.CHAPTER_SEQUENCE.size():
		return &""
	return M1ProgressRules.CHAPTER_SEQUENCE[current_index + 1]


func get_main_story_advance_reason(chapter_id: StringName) -> StringName:
	return M1ProgressRules.get_chapter_advance_reason(main_story_chapter, chapter_id)


func advance_main_story_chapter(chapter_id: StringName) -> ProgressChangeResult:
	var previous_chapter: StringName = main_story_chapter
	var reason: StringName = get_main_story_advance_reason(chapter_id)
	if reason == M1ProgressRules.REASON_ALREADY_CURRENT:
		return ProgressChangeResult.accepted(
			false,
			previous_chapter,
			main_story_chapter,
			reason
		)
	if not reason.is_empty():
		return ProgressChangeResult.rejected(
			reason,
			previous_chapter,
			main_story_chapter
		)
	main_story_chapter = chapter_id
	persistent_state_changed.emit()
	return ProgressChangeResult.accepted(
		true,
		previous_chapter,
		main_story_chapter
	)


func is_planet_unlocked(planet_id: StringName) -> bool:
	return (
		M1ProgressRules.is_known_planet(planet_id)
		and unlocked_planet_ids.has(planet_id)
	)


func get_planet_unlock_reason(
	planet_id: StringName,
	whitelist_context: Dictionary[StringName, bool] = {}
) -> StringName:
	if not M1ProgressRules.is_known_planet(planet_id):
		return M1ProgressRules.REASON_INVALID_PLANET
	if unlocked_planet_ids.has(planet_id):
		return M1ProgressRules.REASON_ALREADY_UNLOCKED
	return M1ProgressRules.evaluate_planet_unlock(
		planet_id,
		main_story_chapter,
		unlocked_planet_ids,
		ship_configuration,
		ship_upgrade_ids,
		planet_permission_ids,
		story_flags,
		completed_order_ids,
		whitelist_context
	)


func can_unlock_planet(
	planet_id: StringName,
	whitelist_context: Dictionary[StringName, bool] = {}
) -> bool:
	var reason: StringName = get_planet_unlock_reason(
		planet_id,
		whitelist_context
	)
	return (
		reason.is_empty()
		or reason == M1ProgressRules.REASON_ALREADY_UNLOCKED
	)


func unlock_planet(
	planet_id: StringName,
	whitelist_context: Dictionary[StringName, bool] = {}
) -> ProgressChangeResult:
	var reason: StringName = get_planet_unlock_reason(
		planet_id,
		whitelist_context
	)
	if reason == M1ProgressRules.REASON_ALREADY_UNLOCKED:
		return ProgressChangeResult.accepted(
			false,
			planet_id,
			planet_id,
			reason
		)
	if not reason.is_empty():
		return ProgressChangeResult.rejected(reason, &"", &"")
	unlocked_planet_ids.append(planet_id)
	persistent_state_changed.emit()
	return ProgressChangeResult.accepted(true, &"", planet_id)


func get_planet_relation(planet_id: StringName) -> int:
	if not M1ProgressRules.is_known_planet(planet_id):
		return 0
	return planet_relation_values.get(planet_id, 0)


func has_applied_planet_relation_event(
	planet_id: StringName,
	event_id: StringName
) -> bool:
	if (
		not M1ProgressRules.is_known_planet(planet_id)
		or not M1ProgressRules.is_stable_id(event_id)
	):
		return false
	return story_flags.get(
		M1ProgressRules.get_relation_event_flag(planet_id, event_id),
		false
	)


func change_planet_relation(
	planet_id: StringName,
	delta: int,
	unique_event_id: StringName
) -> ProgressChangeResult:
	var previous_value: int = get_planet_relation(planet_id)
	if not M1ProgressRules.is_known_planet(planet_id):
		return ProgressChangeResult.rejected(
			M1ProgressRules.REASON_INVALID_PLANET,
			previous_value,
			previous_value
		)
	if not M1ProgressRules.is_stable_id(unique_event_id):
		return ProgressChangeResult.rejected(
			M1ProgressRules.REASON_INVALID_RELATION_EVENT,
			previous_value,
			previous_value
		)
	if has_applied_planet_relation_event(planet_id, unique_event_id):
		return ProgressChangeResult.accepted(
			false,
			previous_value,
			previous_value,
			M1ProgressRules.REASON_ALREADY_APPLIED
		)
	var next_value: int = M1ProgressRules.clamp_relation(previous_value + delta)
	if next_value == previous_value:
		return ProgressChangeResult.accepted(
			false,
			previous_value,
			previous_value,
			M1ProgressRules.REASON_RELATION_AT_LIMIT
		)
	_store_planet_relation(planet_id, next_value)
	story_flags[
		M1ProgressRules.get_relation_event_flag(planet_id, unique_event_id)
	] = true
	persistent_state_changed.emit()
	return ProgressChangeResult.accepted(true, previous_value, next_value)


## Reserved for validated migration, debug setup, and bounded internal corrections.
func set_planet_relation(
	planet_id: StringName,
	value: int
) -> ProgressChangeResult:
	var previous_value: int = get_planet_relation(planet_id)
	if not M1ProgressRules.is_known_planet(planet_id):
		return ProgressChangeResult.rejected(
			M1ProgressRules.REASON_INVALID_PLANET,
			previous_value,
			previous_value
		)
	var next_value: int = M1ProgressRules.clamp_relation(value)
	if next_value == previous_value:
		return ProgressChangeResult.accepted(
			false,
			previous_value,
			previous_value,
			M1ProgressRules.REASON_ALREADY_CURRENT
		)
	_store_planet_relation(planet_id, next_value)
	persistent_state_changed.emit()
	return ProgressChangeResult.accepted(true, previous_value, next_value)


func has_permission(permission_id: StringName) -> bool:
	return (
		M1ProgressRules.is_known_permission(permission_id)
		and planet_permission_ids.has(permission_id)
	)


func grant_permission(permission_id: StringName) -> ProgressChangeResult:
	if not M1ProgressRules.is_known_permission(permission_id):
		return ProgressChangeResult.rejected(
			M1ProgressRules.REASON_INVALID_PERMISSION,
			&"",
			&""
		)
	if planet_permission_ids.has(permission_id):
		return ProgressChangeResult.accepted(
			false,
			permission_id,
			permission_id,
			M1ProgressRules.REASON_ALREADY_GRANTED
		)
	planet_permission_ids.append(permission_id)
	persistent_state_changed.emit()
	return ProgressChangeResult.accepted(true, &"", permission_id)


func has_codex_entry(entry_id: StringName) -> bool:
	return (
		M1ProgressRules.is_valid_codex_entry_id(entry_id)
		and codex_entry_ids.has(entry_id)
	)


func unlock_codex_entry(entry_id: StringName) -> ProgressChangeResult:
	if not M1ProgressRules.is_valid_codex_entry_id(entry_id):
		return ProgressChangeResult.rejected(
			M1ProgressRules.REASON_INVALID_CODEX_ENTRY,
			&"",
			&""
		)
	if codex_entry_ids.has(entry_id):
		return ProgressChangeResult.accepted(
			false,
			entry_id,
			entry_id,
			M1ProgressRules.REASON_ALREADY_PRESENT
		)
	codex_entry_ids.append(entry_id)
	persistent_state_changed.emit()
	return ProgressChangeResult.accepted(true, &"", entry_id)


func has_souvenir(souvenir_id: StringName) -> bool:
	return (
		M1ProgressRules.is_valid_souvenir_id(souvenir_id)
		and souvenir_ids.has(souvenir_id)
	)


func add_souvenir(souvenir_id: StringName) -> ProgressChangeResult:
	if not M1ProgressRules.is_valid_souvenir_id(souvenir_id):
		return ProgressChangeResult.rejected(
			M1ProgressRules.REASON_INVALID_SOUVENIR,
			&"",
			&""
		)
	if souvenir_ids.has(souvenir_id):
		return ProgressChangeResult.accepted(
			false,
			souvenir_id,
			souvenir_id,
			M1ProgressRules.REASON_ALREADY_PRESENT
		)
	souvenir_ids.append(souvenir_id)
	persistent_state_changed.emit()
	return ProgressChangeResult.accepted(true, &"", souvenir_id)


func get_revisit_state(planet_id: StringName) -> StringName:
	if not M1ProgressRules.is_known_planet(planet_id):
		return &""
	return revisit_state.get(planet_id, &"")


func set_revisit_state(
	planet_id: StringName,
	state_id: StringName
) -> ProgressChangeResult:
	var previous_state: StringName = get_revisit_state(planet_id)
	if not M1ProgressRules.is_known_planet(planet_id):
		return ProgressChangeResult.rejected(
			M1ProgressRules.REASON_INVALID_PLANET,
			previous_state,
			previous_state
		)
	if not M1ProgressRules.is_valid_revisit_state_id(state_id):
		return ProgressChangeResult.rejected(
			M1ProgressRules.REASON_INVALID_REVISIT_STATE,
			previous_state,
			previous_state
		)
	if previous_state == state_id:
		return ProgressChangeResult.accepted(
			false,
			previous_state,
			previous_state,
			M1ProgressRules.REASON_ALREADY_CURRENT
		)
	revisit_state[planet_id] = state_id
	persistent_state_changed.emit()
	return ProgressChangeResult.accepted(true, previous_state, state_id)


func get_order_status(order_id: StringName) -> OrderStatus:
	if order_id.is_empty():
		return OrderStatus.AVAILABLE
	if current_order_id == order_id:
		return OrderStatus.ACCEPTED
	if order_states.has(order_id):
		return int(order_states.get(order_id, OrderStatus.AVAILABLE))
	if has_completed_order(order_id):
		return OrderStatus.COMPLETED
	if failed_side_order_ids.has(order_id):
		return OrderStatus.FAILED
	return OrderStatus.AVAILABLE


func get_order_acceptance_error(order: OrderDefinition) -> StringName:
	if not _has_required_order_data(order):
		return ORDER_ERROR_MISSING_DATA
	if order.repeat_policy == OrderDefinition.RepeatPolicy.ARCHIVED_ONLY:
		return ORDER_ERROR_ARCHIVED_ONLY
	var status: OrderStatus = get_order_status(order.id)
	match status:
		OrderStatus.ACCEPTED:
			return ORDER_ERROR_ALREADY_ACCEPTED
		OrderStatus.COMPLETED:
			return ORDER_ERROR_ALREADY_COMPLETED
		OrderStatus.ARCHIVED:
			return ORDER_ERROR_ARCHIVED
		OrderStatus.FAILED, OrderStatus.ABANDONED:
			if order.repeat_policy != OrderDefinition.RepeatPolicy.REPEATABLE:
				return ORDER_ERROR_RETRY_NOT_ALLOWED
	if not current_order_id.is_empty():
		return ORDER_ERROR_ACTIVE_ORDER
	var content_error: StringName = _get_order_content_readiness_error(order)
	if not content_error.is_empty():
		return content_error
	var unlock_error: StringName = M1OrderRules.get_unlock_error(
		order,
		main_story_chapter,
		unlocked_planet_ids,
		planet_permission_ids,
		ship_configuration,
		ship_upgrade_ids
	)
	if not unlock_error.is_empty():
		return unlock_error
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
	destination_id = order.planet_id
	cargo_id = order.cargo.id
	order_states[order.id] = OrderStatus.ACCEPTED
	failed_side_order_ids.erase(order.id)
	order_run_state.reset(order.id)
	departure_confirmed = false
	last_loadout_error = &""
	_reset_travel_state(false)
	order_status_changed.emit(order.id, OrderStatus.ACCEPTED)
	departure_readiness_changed.emit(false)
	persistent_state_changed.emit()
	return true


## Compatibility entry used by M0 tests and direct flows; rewards still use the unified ledger.
func complete_current_order(order: OrderDefinition) -> bool:
	return complete_order(order)


func complete_order(
	order: OrderDefinition,
	requested_credit_reward: int = -1,
	station_upgrade_id: StringName = &"",
	additional_flags: Array[StringName] = []
) -> bool:
	last_order_error = &""
	if not _has_required_order_data(order):
		last_order_error = ORDER_ERROR_MISSING_DATA
		return false
	if (
		get_order_status(order.id) == OrderStatus.COMPLETED
		or has_applied_order_reward(order.id)
	):
		last_order_error = ORDER_ERROR_ALREADY_COMPLETED
		return false
	if (
		current_order_id != order.id
		or get_order_status(order.id) != OrderStatus.ACCEPTED
	):
		last_order_error = ORDER_ERROR_NOT_ACTIVE
		return false
	if requested_credit_reward < -1 or not _has_valid_order_rewards(order):
		last_order_error = ORDER_ERROR_INVALID_REWARD
		return false

	var base_credit_reward: int = (
		order.credit_reward
		if requested_credit_reward < 0
		else requested_credit_reward
	)
	var elapsed_seconds: float = (
		0.0
		if order_run_state == null
		else order_run_state.elapsed_time
	)
	var reward_ratio: float = M1OrderRules.get_reward_ratio(order, elapsed_seconds)
	var final_credit_reward: int = maxi(
		roundi(float(base_credit_reward) * reward_ratio),
		0
	)
	var relation_rewards: Dictionary[StringName, int] = order.relation_rewards.duplicate()
	if (
		order.is_express
		and order.relation_bonus_on_time > 0
		and M1OrderRules.is_on_time(order, elapsed_seconds)
	):
		relation_rewards[order.planet_id] = (
			relation_rewards.get(order.planet_id, 0)
			+ order.relation_bonus_on_time
		)

	credits += final_credit_reward
	for planet_id: StringName in relation_rewards:
		var previous_relation: int = get_planet_relation(planet_id)
		_store_planet_relation(
			planet_id,
			M1ProgressRules.clamp_relation(
				previous_relation + relation_rewards.get(planet_id, 0)
			)
		)
		var relation_event_id: StringName = StringName("reward_%s" % order.id)
		story_flags[
			M1ProgressRules.get_relation_event_flag(planet_id, relation_event_id)
		] = true
	for permission_id: StringName in order.permission_rewards:
		if not planet_permission_ids.has(permission_id):
			planet_permission_ids.append(permission_id)
	for entry_id: StringName in order.codex_rewards:
		if not codex_entry_ids.has(entry_id):
			codex_entry_ids.append(entry_id)
	for souvenir_id: StringName in order.souvenir_rewards:
		if not souvenir_ids.has(souvenir_id):
			souvenir_ids.append(souvenir_id)
	completed_order_ids[order.id] = true
	if order.order_type == OrderDefinition.OrderType.SIDE:
		if not completed_side_order_ids.has(order.id):
			completed_side_order_ids.append(order.id)
		failed_side_order_ids.erase(order.id)
	if not reward_applied_order_ids.has(order.id):
		reward_applied_order_ids.append(order.id)
	for completion_flag: StringName in order.completion_flags:
		if not completion_flag.is_empty():
			story_flags[completion_flag] = true
	for additional_flag: StringName in additional_flags:
		if not additional_flag.is_empty():
			story_flags[additional_flag] = true
	if not station_upgrade_id.is_empty():
		station_upgrade_ids[station_upgrade_id] = true
	order_states[order.id] = OrderStatus.COMPLETED
	_clear_active_order_context()
	order_status_changed.emit(order.id, OrderStatus.COMPLETED)
	departure_readiness_changed.emit(false)
	progress_changed.emit(credits)
	persistent_state_changed.emit()
	return true


func fail_order(order: OrderDefinition) -> bool:
	last_order_error = &""
	if not _has_required_order_data(order):
		last_order_error = ORDER_ERROR_MISSING_DATA
		return false
	if current_order_id != order.id or get_order_status(order.id) != OrderStatus.ACCEPTED:
		last_order_error = ORDER_ERROR_INVALID_TRANSITION
		return false
	if order.is_mainline():
		last_order_error = ORDER_ERROR_MAIN_RETRY_REQUIRED
		return false
	order_states[order.id] = OrderStatus.FAILED
	if not failed_side_order_ids.has(order.id):
		failed_side_order_ids.append(order.id)
	_clear_active_order_context()
	order_status_changed.emit(order.id, OrderStatus.FAILED)
	departure_readiness_changed.emit(false)
	persistent_state_changed.emit()
	return true


func abandon_order(order: OrderDefinition) -> bool:
	last_order_error = &""
	if not _has_required_order_data(order):
		last_order_error = ORDER_ERROR_MISSING_DATA
		return false
	if order.is_mainline():
		last_order_error = ORDER_ERROR_MAIN_CANNOT_ABANDON
		return false
	if current_order_id != order.id or get_order_status(order.id) != OrderStatus.ACCEPTED:
		last_order_error = ORDER_ERROR_INVALID_TRANSITION
		return false
	order_states[order.id] = OrderStatus.ABANDONED
	_clear_active_order_context()
	order_status_changed.emit(order.id, OrderStatus.ABANDONED)
	departure_readiness_changed.emit(false)
	persistent_state_changed.emit()
	return true


func archive_order(order: OrderDefinition) -> bool:
	last_order_error = &""
	if not _has_required_order_data(order):
		last_order_error = ORDER_ERROR_MISSING_DATA
		return false
	if order.repeat_policy != OrderDefinition.RepeatPolicy.ARCHIVED_ONLY:
		last_order_error = ORDER_ERROR_INVALID_TRANSITION
		return false
	var status: OrderStatus = get_order_status(order.id)
	if status not in [
		OrderStatus.AVAILABLE,
		OrderStatus.FAILED,
		OrderStatus.ABANDONED,
	]:
		last_order_error = ORDER_ERROR_INVALID_TRANSITION
		return false
	order_states[order.id] = OrderStatus.ARCHIVED
	order_status_changed.emit(order.id, OrderStatus.ARCHIVED)
	persistent_state_changed.emit()
	return true


func advance_active_order_time(
	order: OrderDefinition,
	delta: float,
	dialogue_open: bool = false,
	help_open: bool = false,
	game_paused: bool = false
) -> bool:
	last_order_error = &""
	if (
		not _has_required_order_data(order)
		or current_order_id != order.id
		or get_order_status(order.id) != OrderStatus.ACCEPTED
	):
		last_order_error = ORDER_ERROR_NOT_ACTIVE
		return false
	if not is_finite(delta) or delta < 0.0:
		last_order_error = ORDER_ERROR_INVALID_TIMING
		return false
	var timing_paused: bool = M1OrderRules.is_timing_paused(
		dialogue_open,
		help_open,
		game_paused
	)
	order_run_state.elapsed_time = M1OrderRules.advance_elapsed_time(
		order_run_state.elapsed_time,
		delta,
		order.is_express,
		timing_paused
	)
	return true


func get_active_order_reward_ratio(order: OrderDefinition) -> float:
	if (
		order == null
		or current_order_id != order.id
		or order_run_state == null
	):
		return 1.0
	return M1OrderRules.get_reward_ratio(order, order_run_state.elapsed_time)


## Commits the one-way M0 result through the same unified reward ledger.
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
	var credits_before: int = credits
	if not complete_order(
		order,
		settlement.total_reward,
		station_upgrade_id,
		settlement_flags
	):
		return false
	settlement.total_reward = credits - credits_before
	return true


func has_completed_order(order_id: StringName) -> bool:
	return not order_id.is_empty() and completed_order_ids.get(order_id, false)


func has_applied_order_reward(order_id: StringName) -> bool:
	return not order_id.is_empty() and reward_applied_order_ids.has(order_id)


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
	var content_error: StringName = _get_order_content_readiness_error(order)
	if not content_error.is_empty():
		return content_error
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
	if (
		requested_destination_id != order.destination_planet.id
		or destination_id != order.destination_planet.id
	):
		return TRAVEL_ERROR_DESTINATION_NOT_ALLOWED
	var content_error: StringName = _get_order_content_readiness_error(order)
	if not content_error.is_empty():
		return content_error
	if not departure_confirmed:
		return TRAVEL_ERROR_DEPARTURE_NOT_CONFIRMED
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


func _get_order_content_readiness_error(
	order: OrderDefinition
) -> StringName:
	if order == null:
		return ORDER_ERROR_MISSING_DATA
	if not order.is_playable():
		return ORDER_ERROR_REGISTERED_ONLY
	var planet: PlanetDefinition = order.destination_planet
	if planet == null:
		return ORDER_ERROR_MISSING_DATA
	if not planet.is_playable():
		return ORDER_ERROR_PLANET_REGISTERED_ONLY
	if (
		planet.flight_scene_path.is_empty()
		or not ResourceLoader.exists(planet.flight_scene_path)
	):
		return ORDER_ERROR_MISSING_ROUTE
	return &""


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


func _store_planet_relation(planet_id: StringName, value: int) -> void:
	if value == 0:
		planet_relation_values.erase(planet_id)
	else:
		planet_relation_values[planet_id] = value


func _get_dialogue_read_id(sequence_id: StringName, line_id: StringName) -> StringName:
	return StringName("%s/%s" % [sequence_id, line_id])


func _get_travel_seen_flag(travel_destination: StringName) -> StringName:
	return StringName("travel_seen/%s" % travel_destination)


func _has_required_order_data(order: OrderDefinition) -> bool:
	if (
		order == null
		or order.id.is_empty()
		or not M1ProgressRules.is_stable_id(order.id)
		or order.display_name_key.is_empty()
		or order.order_type < OrderDefinition.OrderType.MAIN
		or order.order_type > OrderDefinition.OrderType.REVISIT
		or order.repeat_policy < OrderDefinition.RepeatPolicy.UNIQUE
		or order.repeat_policy > OrderDefinition.RepeatPolicy.ARCHIVED_ONLY
		or order.sender == null
		or order.sender.id.is_empty()
		or order.recipient == null
		or order.recipient.id.is_empty()
		or order.destination_planet == null
		or order.destination_planet.id.is_empty()
		or not M1ProgressRules.is_known_planet(order.planet_id)
		or order.destination_planet.id != order.planet_id
		or not M1ProgressRules.is_stable_id(order.destination_id)
		or order.cargo == null
		or order.cargo.id.is_empty()
		or order.customer_history_keys.is_empty()
		or order.delivery_type < OrderDefinition.DeliveryType.LANDING
		or order.delivery_type > OrderDefinition.DeliveryType.LOW_ALTITUDE_DROP
		or (
			not order.required_chapter.is_empty()
			and not M1ProgressRules.is_known_chapter(order.required_chapter)
		)
		or (
			order.is_mainline()
			and order.repeat_policy != OrderDefinition.RepeatPolicy.UNIQUE
		)
	):
		return false
	if order.is_express:
		if (
			not is_finite(order.target_seconds)
			or order.target_seconds <= 0.0
			or not is_finite(order.grace_seconds)
			or order.grace_seconds < 0.0
			or not is_finite(order.minimum_reward_ratio)
			or order.minimum_reward_ratio < 0.0
			or order.minimum_reward_ratio > 1.0
			or order.relation_bonus_on_time < 0
		):
			return false
	elif (
		not is_zero_approx(order.target_seconds)
		or not is_zero_approx(order.grace_seconds)
		or not is_equal_approx(order.minimum_reward_ratio, 1.0)
		or order.relation_bonus_on_time != 0
	):
		return false
	for condition: OrderUnlockCondition in order.unlock_conditions:
		if (
			condition == null
			or condition.reference_id.is_empty()
			or condition.condition_type < OrderUnlockCondition.ConditionType.PLANET_UNLOCKED
			or condition.condition_type > OrderUnlockCondition.ConditionType.MODULE_AVAILABLE
		):
			return false
	for module: ShipModuleDefinition in order.required_modules:
		if module == null or module.id.is_empty():
			return false
	return _has_valid_order_rewards(order)


func _has_valid_order_rewards(order: OrderDefinition) -> bool:
	if order == null or order.credit_reward < 0:
		return false
	for planet_id: StringName in order.relation_rewards:
		if (
			not M1ProgressRules.is_known_planet(planet_id)
			or order.relation_rewards.get(planet_id, 0) == 0
		):
			return false
	for permission_id: StringName in order.permission_rewards:
		if not M1ProgressRules.is_known_permission(permission_id):
			return false
	for entry_id: StringName in order.codex_rewards:
		if not M1ProgressRules.is_valid_codex_entry_id(entry_id):
			return false
	for souvenir_id: StringName in order.souvenir_rewards:
		if not M1ProgressRules.is_valid_souvenir_id(souvenir_id):
			return false
	return true


func _clear_active_order_context() -> void:
	current_order_id = &""
	destination_id = &""
	cargo_id = &""
	departure_confirmed = false
	last_loadout_error = &""
	_reset_travel_state(false)


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
