class_name OrderSettlementCalculator
extends RefCounted

const MIN_MAIN_ORDER_PAYOUT_RATIO: float = 0.60
const MAX_CARGO_INTEGRITY: float = 100.0
const SECURED_CARGO_THRESHOLD: float = 80.0
const NARRATIVE_CARGO_SECURED: StringName = &"cargo_secured"
const NARRATIVE_CARGO_RECOVERED: StringName = &"cargo_recovered"


static func calculate(
	order: OrderDefinition,
	run_state: OrderRunState
) -> OrderSettlementResult:
	if order == null or order.id.is_empty() or run_state == null:
		return null
	if run_state.order_id != order.id:
		return null

	var result: OrderSettlementResult = OrderSettlementResult.new()
	result.order_id = order.id
	result.base_reward = maxi(order.credit_reward, 0)
	result.cargo_integrity = clampf(run_state.cargo_integrity, 0.0, MAX_CARGO_INTEGRITY)
	var cargo_payout_ratio: float = lerpf(
		MIN_MAIN_ORDER_PAYOUT_RATIO,
		1.0,
		result.cargo_integrity / MAX_CARGO_INTEGRITY
	)
	result.cargo_adjusted_reward = maxi(
		roundi(float(result.base_reward) * cargo_payout_ratio),
		0
	)
	result.cargo_adjustment = result.cargo_adjusted_reward - result.base_reward
	result.is_express = order.is_express
	result.elapsed_time = maxf(run_state.elapsed_time, 0.0)
	result.target_seconds = maxf(order.target_seconds, 0.0)
	result.reward_ratio = M1OrderRules.get_reward_ratio(
		order,
		result.elapsed_time
	)
	result.timing_status = M1OrderRules.get_timing_status(
		order,
		result.elapsed_time
	)
	result.total_reward = maxi(
		roundi(float(result.cargo_adjusted_reward) * result.reward_ratio),
		0
	)
	result.time_adjustment = result.total_reward - result.cargo_adjusted_reward
	result.earned_on_time_relation_bonus = (
		order.is_express
		and order.relation_bonus_on_time > 0
		and M1OrderRules.is_on_time(order, result.elapsed_time)
	)
	result.on_time_relation_bonus = (
		order.relation_bonus_on_time
		if result.earned_on_time_relation_bonus
		else 0
	)
	result.entry_style = run_state.entry_style
	result.landing_result = run_state.landing_result
	result.narrative_result = (
		NARRATIVE_CARGO_SECURED
		if result.cargo_integrity >= SECURED_CARGO_THRESHOLD
		else NARRATIVE_CARGO_RECOVERED
	)
	return result
