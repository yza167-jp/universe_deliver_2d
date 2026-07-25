class_name M1OrderRules
extends RefCounted

## Stateless M1 order gates and express-time math.

const REASON_INVALID_CONDITION: StringName = &"invalid_unlock_condition"
const REASON_ARCHIVED_ONLY: StringName = &"archived_only"


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
