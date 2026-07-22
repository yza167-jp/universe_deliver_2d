extends ProjectTestSuite

const ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"


func run() -> Array[String]:
	var failures: Array[String] = []
	var order: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	expect_true(order != null, "Red Sand settlement order must load.", failures)
	if order == null:
		return failures

	_test_reward_boundaries(order, failures)
	_test_settlement_commit(order, failures)
	_test_invalid_settlement_is_atomic(order, failures)
	return failures


func _test_reward_boundaries(
	order: OrderDefinition,
	failures: Array[String]
) -> void:
	var full_result: OrderSettlementResult = _calculate(order, 100.0)
	var half_result: OrderSettlementResult = _calculate(order, 50.0)
	var zero_result: OrderSettlementResult = _calculate(order, 0.0)
	var recovered_result: OrderSettlementResult = _calculate(order, 79.0)
	var clamped_result: OrderSettlementResult = _calculate(order, 180.0)
	expect_true(
		full_result != null
		and full_result.total_reward == 100
		and full_result.cargo_adjustment == 0,
		"Intact cargo must receive the full configured reward.",
		failures
	)
	expect_true(
		half_result != null and half_result.total_reward == 80,
		"Half-integrity cargo must interpolate to an 80-percent payout.",
		failures
	)
	expect_true(
		zero_result != null
		and zero_result.total_reward == 60
		and zero_result.total_reward >= 0,
		"A poor main-order result must retain the 60-percent progression-safe payout.",
		failures
	)
	expect_true(
		recovered_result != null
		and recovered_result.narrative_result
		== OrderSettlementCalculator.NARRATIVE_CARGO_RECOVERED,
		"Cargo below 80 percent must use the recoverable-damage narrative.",
		failures
	)
	expect_true(
		clamped_result != null and clamped_result.total_reward == 100,
		"Out-of-range cargo values must not award more than the base reward.",
		failures
	)


func _test_settlement_commit(
	order: OrderDefinition,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	expect_true(game_state.accept_order(order), "Settlement fixture order must be accepted.", failures)
	var run_state: OrderRunState = game_state.get_active_order_run_state()
	run_state.cargo_integrity = 54.0
	run_state.entry_style = FlightStyleTracker.STYLE_GLIDE
	run_state.record_landing_result(OrderRunState.LANDING_RESULT_ROUGH, 4.0)
	var result: OrderSettlementResult = OrderSettlementCalculator.calculate(order, run_state)
	var settlement_flags: Array[StringName] = [
		M0ProgressIds.STORY_FIRST_DELIVERY_SETTLED,
		M0ProgressIds.STORY_RETURN_DIALOGUE_PENDING,
	]
	expect_true(
		game_state.settle_current_order(
			order,
			result,
			M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY,
			settlement_flags
		),
		"A valid active order must settle exactly once.",
		failures
	)
	expect_true(
		result != null and result.total_reward == 82 and game_state.get_credits() == 82,
		"Poor cargo must reduce, but still grant, the deterministic credit payout.",
		failures
	)
	expect_true(
		game_state.has_completed_order(order.id)
		and game_state.has_story_flag(&"story_red_sand_order_completed")
		and game_state.has_story_flag(M0ProgressIds.STORY_FIRST_DELIVERY_SETTLED),
		"Settlement must retain the main completion and narrative progress flags.",
		failures
	)
	expect_true(
		game_state.has_station_upgrade(
			M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
		)
		and game_state.has_story_flag(M0ProgressIds.STORY_RETURN_DIALOGUE_PENDING),
		"Settlement must unlock the deterministic station display and return dialogue.",
		failures
	)
	expect_true(
		game_state.current_order_id.is_empty()
		and game_state.destination_id.is_empty()
		and game_state.cargo_id.is_empty(),
		"Settlement must clear the active delivery slot after retaining its result.",
		failures
	)
	expect_true(
		not game_state.settle_current_order(
			order,
			result,
			M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY,
			settlement_flags
		)
		and game_state.last_order_error == GameStateModel.ORDER_ERROR_ALREADY_COMPLETED
		and game_state.get_credits() == 82,
		"Repeated settlement must not duplicate credits or station progress.",
		failures
	)
	game_state.free()


func _test_invalid_settlement_is_atomic(
	order: OrderDefinition,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	game_state.accept_order(order)
	var invalid_result: OrderSettlementResult = OrderSettlementResult.new()
	invalid_result.order_id = &"order_mismatch"
	invalid_result.total_reward = 999
	expect_true(
		not game_state.settle_current_order(
			order,
			invalid_result,
			M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
		)
		and game_state.last_order_error == GameStateModel.ORDER_ERROR_INVALID_SETTLEMENT,
		"A mismatched settlement payload must be rejected.",
		failures
	)
	expect_true(
		game_state.current_order_id == order.id
		and not game_state.has_completed_order(order.id)
		and game_state.get_credits() == 0,
		"Rejected settlement must leave the active order and progress unchanged.",
		failures
	)
	game_state.free()


func _calculate(order: OrderDefinition, cargo_integrity: float) -> OrderSettlementResult:
	var run_state: OrderRunState = OrderRunState.new()
	run_state.reset(order.id)
	run_state.cargo_integrity = cargo_integrity
	return OrderSettlementCalculator.calculate(order, run_state)
