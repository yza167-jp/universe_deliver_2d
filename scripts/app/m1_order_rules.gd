class_name M1OrderRules
extends RefCounted

## Stateless M1 order gates and express-time math.

const REASON_INVALID_CONDITION: StringName = &"invalid_unlock_condition"
const REASON_ARCHIVED_ONLY: StringName = &"archived_only"
const TIMING_STATUS_NONE: StringName = &""
const TIMING_STATUS_FULL_REWARD: StringName = &"full_reward"
const TIMING_STATUS_GRACE: StringName = &"grace"
const TIMING_STATUS_FLOOR: StringName = &"floor"
const TIMING_STATUS_PAUSED: StringName = &"paused"


static func get_unlock_error(
	order: OrderDefinition,
	current_chapter_id: StringName,
	unlocked_planet_ids: Array[StringName],
	planet_permission_ids: Array[StringName],
	ship_configuration: Dictionary[StringName, StringName],
	ship_upgrade_ids: Array[StringName]
) -> StringName:
	if order == null:
		return REASON_INVALID_CONDITION
	if (
		not order.required_chapter.is_empty()
		and not M1ProgressRules.has_reached_chapter(
			current_chapter_id,
			order.required_chapter
		)
	):
		return M1ProgressRules.REASON_REQUIRED_CHAPTER
	for condition: OrderUnlockCondition in order.unlock_conditions:
		if condition == null or condition.reference_id.is_empty():
			return REASON_INVALID_CONDITION
		match condition.condition_type:
			OrderUnlockCondition.ConditionType.PLANET_UNLOCKED:
				if (
					not M1ProgressRules.is_known_planet(condition.reference_id)
					or not unlocked_planet_ids.has(condition.reference_id)
				):
					return M1ProgressRules.REASON_REQUIRED_PLANET
			OrderUnlockCondition.ConditionType.PERMISSION_GRANTED:
				if (
					not M1ProgressRules.is_known_permission(condition.reference_id)
					or not planet_permission_ids.has(condition.reference_id)
				):
					return M1ProgressRules.REASON_REQUIRED_PERMISSION
			OrderUnlockCondition.ConditionType.MODULE_AVAILABLE:
				if (
					not ship_upgrade_ids.has(condition.reference_id)
					and not ShipLoadoutRules.is_module_equipped(
						ship_configuration,
						condition.reference_id
					)
				):
					return M1ProgressRules.REASON_REQUIRED_MODULE
			_:
				return REASON_INVALID_CONDITION
	return &""


static func is_timing_paused(
	dialogue_open: bool,
	help_open: bool,
	game_paused: bool
) -> bool:
	return dialogue_open or help_open or game_paused


static func advance_elapsed_time(
	current_seconds: float,
	delta: float,
	is_express: bool,
	timing_paused: bool
) -> float:
	var safe_current: float = maxf(current_seconds, 0.0)
	if not is_express or timing_paused:
		return safe_current
	return safe_current + maxf(delta, 0.0)


static func is_on_time(order: OrderDefinition, elapsed_seconds: float) -> bool:
	if order == null or not order.is_express:
		return true
	return maxf(elapsed_seconds, 0.0) <= order.target_seconds


static func get_reward_ratio(
	order: OrderDefinition,
	elapsed_seconds: float
) -> float:
	if order == null or not order.is_express:
		return 1.0
	var minimum_ratio: float = clampf(order.minimum_reward_ratio, 0.0, 1.0)
	var safe_elapsed: float = maxf(elapsed_seconds, 0.0)
	if safe_elapsed <= order.target_seconds:
		return 1.0
	if order.grace_seconds <= 0.0:
		return minimum_ratio
	var overtime_progress: float = clampf(
		(safe_elapsed - order.target_seconds) / order.grace_seconds,
		0.0,
		1.0
	)
	return lerpf(1.0, minimum_ratio, overtime_progress)


static func get_timing_status(
	order: OrderDefinition,
	elapsed_seconds: float,
	timing_paused: bool = false
) -> StringName:
	if order == null or not order.is_express:
		return TIMING_STATUS_NONE
	if timing_paused:
		return TIMING_STATUS_PAUSED
	var safe_elapsed: float = maxf(elapsed_seconds, 0.0)
	if safe_elapsed <= order.target_seconds:
		return TIMING_STATUS_FULL_REWARD
	if safe_elapsed < order.target_seconds + order.grace_seconds:
		return TIMING_STATUS_GRACE
	return TIMING_STATUS_FLOOR


static func format_duration(
	seconds: float,
	round_up: bool = false
) -> String:
	var safe_seconds: float = maxf(seconds, 0.0)
	var whole_seconds: int = (
		ceili(safe_seconds)
		if round_up
		else floori(safe_seconds)
	)
	return "%02d:%02d" % [whole_seconds / 60, whole_seconds % 60]
