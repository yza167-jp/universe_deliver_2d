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
	result.base_reward = maxi(order.reward_credits, 0)
	result.cargo_integrity = clampf(run_state.cargo_integrity, 0.0, MAX_CARGO_INTEGRITY)
	var payout_ratio: float = lerpf(
		MIN_MAIN_ORDER_PAYOUT_RATIO,
		1.0,
		result.cargo_integrity / MAX_CARGO_INTEGRITY
	)
	result.total_reward = maxi(roundi(float(result.base_reward) * payout_ratio), 0)
	result.cargo_adjustment = result.total_reward - result.base_reward
	result.entry_style = run_state.entry_style
	result.landing_result = run_state.landing_result
	result.narrative_result = (
		NARRATIVE_CARGO_SECURED
		if result.cargo_integrity >= SECURED_CARGO_THRESHOLD
		else NARRATIVE_CARGO_RECOVERED
	)
	return result
