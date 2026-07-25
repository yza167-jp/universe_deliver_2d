extends ProjectTestSuite

const TIDAL_EXPRESS_ORDER_PATH: String = (
	"res://data/orders/side_tidal_beacon_before_eye.tres"
)
const M0_ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"
const TEST_ROUTE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	var registered_order: OrderDefinition = load(
		TIDAL_EXPRESS_ORDER_PATH
	) as OrderDefinition
	expect_true(
		registered_order != null,
		"T-108 express order packet must load.",
		failures
	)
	if registered_order == null:
		return failures
	_test_registered_only_boundary(registered_order, failures)
	_test_timing_curve_and_statuses(registered_order, failures)
	_test_settlement_order_and_single_multiplier(registered_order, failures)
	_test_on_time_relation_bonus_is_idempotent(registered_order, failures)
	_test_save_restore_and_retry_state(registered_order, failures)
	_test_non_express_contract(failures)
	return failures


func _test_registered_only_boundary(
	order: OrderDefinition,
	failures: Array[String]
) -> void:
	expect_true(
		order.content_readiness == OrderDefinition.ContentReadiness.REGISTERED_ONLY
		and order.destination_planet != null
		and order.destination_planet.content_readiness
		== PlanetDefinition.ContentReadiness.REGISTERED_ONLY,
		"The Tidal express side order and planet must remain REGISTERED_ONLY.",
		failures
	)


func _test_timing_curve_and_statuses(
	order: OrderDefinition,
	failures: Array[String]
) -> void:
	expect_true(
		is_equal_approx(M1OrderRules.get_reward_ratio(order, 120.0), 1.0)
		and M1OrderRules.get_timing_status(order, 120.0)
		== M1OrderRules.TIMING_STATUS_FULL_REWARD,
		"Completing at the target must retain the full express payout.",
		failures
	)
	expect_true(
		is_equal_approx(M1OrderRules.get_reward_ratio(order, 150.0), 0.75)
		and M1OrderRules.get_timing_status(order, 150.0)
		== M1OrderRules.TIMING_STATUS_GRACE,
		"The middle of grace must linearly reduce payout to 75 percent.",
		failures
	)
	expect_true(
		is_equal_approx(M1OrderRules.get_reward_ratio(order, 180.0), 0.5)
		and is_equal_approx(M1OrderRules.get_reward_ratio(order, 600.0), 0.5)
		and M1OrderRules.get_timing_status(order, 180.0)
		== M1OrderRules.TIMING_STATUS_FLOOR,
		"Grace expiry must hold the configured floor without hard failure.",
		failures
	)
	expect_true(
		M1OrderRules.get_timing_status(order, 40.0, true)
		== M1OrderRules.TIMING_STATUS_PAUSED
		and M1OrderRules.format_duration(0.0) == "00:00"
		and M1OrderRules.format_duration(119.2) == "01:59"
		and M1OrderRules.format_duration(119.2, true) == "02:00",
		"Pause status and mm:ss formatting must be deterministic.",
		failures
	)


func _test_settlement_order_and_single_multiplier(
	registered_order: OrderDefinition,
	failures: Array[String]
) -> void:
	var order: OrderDefinition = _make_playable_fixture(registered_order)
	var game_state: GameStateModel = GameStateModel.new()
	expect_true(
		game_state.accept_order(order),
		"Playable express settlement fixture must accept.",
		failures
	)
	var run_state: OrderRunState = game_state.get_active_order_run_state()
	run_state.cargo_integrity = 50.0
	run_state.elapsed_time = 150.0
	var result: OrderSettlementResult = OrderSettlementCalculator.calculate(
		order,
		run_state
	)
	expect_true(
		result != null
		and result.base_reward == 120
		and result.cargo_adjusted_reward == 96
		and result.cargo_adjustment == -24
		and is_equal_approx(result.reward_ratio, 0.75)
		and result.time_adjustment == -24
		and result.total_reward == 72
		and result.timing_status == M1OrderRules.TIMING_STATUS_GRACE,
		"Settlement order must be 120 base -> 96 cargo -> 72 timing.",
		failures
	)
	expect_true(
		game_state.settle_current_order(order, result, &"")
		and game_state.get_credits() == 72
		and game_state.get_planet_relation(order.planet_id) == 1,
		"The final 72-credit result must be committed without a second timing multiplier.",
		failures
	)
	expect_true(
		not game_state.settle_current_order(order, result, &"")
		and game_state.last_order_error == GameStateModel.ORDER_ERROR_ALREADY_COMPLETED
		and game_state.get_credits() == 72
		and game_state.get_planet_relation(order.planet_id) == 1,
		"Repeated settlement must not duplicate express credits or relation rewards.",
		failures
	)
	game_state.free()


func _test_on_time_relation_bonus_is_idempotent(
	registered_order: OrderDefinition,
	failures: Array[String]
) -> void:
	var order: OrderDefinition = _make_playable_fixture(registered_order)
	var game_state: GameStateModel = GameStateModel.new()
	game_state.accept_order(order)
	var run_state: OrderRunState = game_state.get_active_order_run_state()
	run_state.elapsed_time = 90.0
	var result: OrderSettlementResult = OrderSettlementCalculator.calculate(
		order,
		run_state
	)
	expect_true(
		result != null
		and result.earned_on_time_relation_bonus
		and result.on_time_relation_bonus == 1
		and game_state.settle_current_order(order, result, &"")
		and game_state.get_credits() == 120
		and game_state.get_planet_relation(order.planet_id) == 2,
		"On-time completion must grant the configured relation bonus exactly once.",
		failures
	)
	var captured: GameProgressData = GameProgressData.capture(game_state)
	var restored: GameStateModel = GameStateModel.new()
	expect_true(
		captured.is_valid()
		and captured.apply_to(restored)
		and restored.get_credits() == 120
		and restored.get_planet_relation(order.planet_id) == 2
		and restored.has_applied_order_reward(order.id)
		and not restored.complete_order(order)
		and restored.get_credits() == 120
		and restored.get_planet_relation(order.planet_id) == 2,
		"Reloading a completed express order must preserve its reward ledger.",
		failures
	)
	game_state.free()
	restored.free()


func _test_save_restore_and_retry_state(
	registered_order: OrderDefinition,
	failures: Array[String]
) -> void:
	var order: OrderDefinition = _make_playable_fixture(registered_order)
	var source: GameStateModel = GameStateModel.new()
	source.accept_order(order)
	source.advance_active_order_time(order, 47.5)
	source.order_run_state.active_checkpoint_id = &"checkpoint_express_test"
	source.order_run_state.reset_entry_result()
	expect_true(
		is_equal_approx(source.order_run_state.elapsed_time, 47.5),
		"Checkpoint-style entry reset must not clear express elapsed time.",
		failures
	)
	var captured: GameProgressData = GameProgressData.capture(source)
	var restored: GameStateModel = GameStateModel.new()
	expect_true(
		captured.is_valid()
		and captured.apply_to(restored)
		and restored.current_order_id == order.id
		and is_equal_approx(restored.order_run_state.elapsed_time, 47.5)
		and restored.order_run_state.active_checkpoint_id
		== &"checkpoint_express_test",
		"Save/load must retain active express elapsed time and checkpoint state.",
		failures
	)
	source.free()
	restored.free()


func _test_non_express_contract(failures: Array[String]) -> void:
	var order: OrderDefinition = load(M0_ORDER_PATH) as OrderDefinition
	var run_state: OrderRunState = OrderRunState.new()
	run_state.reset(order.id)
	run_state.elapsed_time = 999.0
	var result: OrderSettlementResult = OrderSettlementCalculator.calculate(
		order,
		run_state
	)
	expect_true(
		result != null
		and not result.is_express
		and result.timing_status == M1OrderRules.TIMING_STATUS_NONE
		and is_equal_approx(result.reward_ratio, 1.0)
		and result.time_adjustment == 0
		and not result.earned_on_time_relation_bonus
		and result.on_time_relation_bonus == 0,
		"Non-express settlement must not expose or apply timing adjustments.",
		failures
	)


func _make_playable_fixture(
	registered_order: OrderDefinition
) -> OrderDefinition:
	var order: OrderDefinition = registered_order.duplicate(true) as OrderDefinition
	var planet: PlanetDefinition = (
		registered_order.destination_planet.duplicate(true) as PlanetDefinition
	)
	order.content_readiness = OrderDefinition.ContentReadiness.PLAYABLE
	order.required_chapter = &""
	order.unlock_conditions.clear()
	order.story_requirements.clear()
	planet.content_readiness = PlanetDefinition.ContentReadiness.PLAYABLE
	planet.flight_scene_path = TEST_ROUTE_PATH
	planet.required_story_flags.clear()
	order.destination_planet = planet
	return order
