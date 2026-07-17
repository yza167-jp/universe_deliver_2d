extends ProjectTestSuite

const ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"


func run() -> Array[String]:
	var failures: Array[String] = []
	var order: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	expect_true(order != null, "Red Sand order must load for travel tests.", failures)
	if order == null:
		return failures
	_test_game_state_transitions(order, failures)
	_test_sequence_controller(order, failures)
	_test_seen_travel_skip(order, failures)
	return failures


func _test_game_state_transitions(
	order: OrderDefinition,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var destination: StringName = order.destination_planet.id
	expect_true(
		not game_state.begin_travel(order, destination)
		and game_state.last_travel_error == GameStateModel.TRAVEL_ERROR_ORDER_NOT_ACTIVE,
		"Travel must be blocked before the order is accepted.",
		failures
	)
	expect_true(game_state.accept_order(order), "Travel test order must be accepted.", failures)
	expect_true(
		not game_state.begin_travel(order, destination)
		and game_state.last_travel_error
		== GameStateModel.TRAVEL_ERROR_DEPARTURE_NOT_CONFIRMED,
		"Travel must be blocked before station preflight confirmation.",
		failures
	)
	expect_true(game_state.confirm_departure(order), "Default loadout must pass preflight.", failures)
	expect_true(
		not game_state.begin_travel(order, &"planet_not_on_order")
		and game_state.last_travel_error
		== GameStateModel.TRAVEL_ERROR_DESTINATION_NOT_ALLOWED,
		"Travel must reject destinations outside the active order.",
		failures
	)
	expect_true(
		game_state.travel_state == GameStateModel.TravelState.IDLE,
		"Rejected destinations must not mutate the travel state.",
		failures
	)
	expect_true(
		game_state.begin_travel(order, destination)
		and game_state.travel_state == GameStateModel.TravelState.DEPARTURE
		and game_state.travel_destination_id == destination,
		"A valid destination confirmation must begin the departure phase.",
		failures
	)
	expect_true(
		not game_state.begin_travel(order, destination)
		and game_state.last_travel_error == GameStateModel.TRAVEL_ERROR_ALREADY_STARTED,
		"Departure cannot be triggered twice while travel is active.",
		failures
	)
	expect_true(
		not game_state.advance_travel_state(GameStateModel.TravelState.APPROACH)
		and game_state.travel_state == GameStateModel.TravelState.DEPARTURE,
		"Travel phases must not skip the required sequential transition.",
		failures
	)
	expect_true(
		game_state.advance_travel_state(GameStateModel.TravelState.CRUISE)
		and game_state.advance_travel_state(GameStateModel.TravelState.APPROACH)
		and game_state.advance_travel_state(GameStateModel.TravelState.COMPLETED),
		"Travel must support departure, cruise, approach, and completion in order.",
		failures
	)
	expect_true(
		game_state.has_seen_travel(destination),
		"Completing a travel route must record it as previously seen.",
		failures
	)
	expect_true(
		not game_state.begin_travel(order, destination)
		and game_state.last_travel_error == GameStateModel.TRAVEL_ERROR_ALREADY_COMPLETED,
		"A completed route must not replay departure from the same order state.",
		failures
	)
	expect_true(
		game_state.complete_current_order(order)
		and game_state.travel_state == GameStateModel.TravelState.IDLE
		and game_state.travel_destination_id.is_empty()
		and game_state.has_seen_travel(destination),
		"Order settlement must clear travel runtime state without losing the seen-route flag.",
		failures
	)
	game_state.reset_runtime_state()
	expect_true(
		not game_state.has_seen_travel(destination),
		"Starting a new runtime must clear previous-session travel flags.",
		failures
	)
	game_state.free()


func _test_sequence_controller(
	order: OrderDefinition,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var controller: TravelSequenceController = TravelSequenceController.new()
	game_state.accept_order(order)
	game_state.confirm_departure(order)
	controller.departure_duration = 0.1
	controller.cruise_duration = 0.2
	controller.approach_duration = 0.1
	expect_true(
		controller.configure(game_state, order),
		"Travel controller must accept a valid state and order.",
		failures
	)
	expect_true(
		controller.start_travel(order.destination_planet.id),
		"Travel controller must start the configured route.",
		failures
	)
	expect_true(
		not controller.can_skip(),
		"The first main-route travel must not expose skip.",
		failures
	)
	controller.advance_travel(0.11)
	expect_true(
		controller.get_phase() == GameStateModel.TravelState.CRUISE,
		"The controller must advance from departure to cruise.",
		failures
	)
	controller.advance_travel(0.21)
	expect_true(
		controller.get_phase() == GameStateModel.TravelState.APPROACH,
		"The controller must advance from cruise to approach.",
		failures
	)
	controller.advance_travel(0.11)
	expect_true(
		not controller.is_running()
		and controller.get_phase() == GameStateModel.TravelState.COMPLETED
		and is_equal_approx(controller.get_total_progress(), 1.0),
		"The controller must finish after all three tunable durations.",
		failures
	)
	controller.free()
	game_state.free()


func _test_seen_travel_skip(
	order: OrderDefinition,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var controller: TravelSequenceController = TravelSequenceController.new()
	var destination: StringName = order.destination_planet.id
	game_state.accept_order(order)
	game_state.confirm_departure(order)
	game_state.mark_travel_seen(destination)
	controller.configure(game_state, order)
	controller.start_travel(destination)
	expect_true(
		controller.can_skip(),
		"A previously seen route must expose skip while travel is active.",
		failures
	)
	expect_true(
		controller.skip_travel()
		and game_state.travel_state == GameStateModel.TravelState.COMPLETED
		and not controller.is_running(),
		"Skipping a seen route must complete travel without breaking state.",
		failures
	)
	controller.free()
	game_state.free()
