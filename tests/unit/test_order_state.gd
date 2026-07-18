extends ProjectTestSuite

const ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"

var _status_events: Array[GameStateModel.OrderStatus] = []


func run() -> Array[String]:
	var failures: Array[String] = []
	var order: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	var game_state: GameStateModel = GameStateModel.new()
	_status_events.clear()
	game_state.order_status_changed.connect(_on_order_status_changed)

	expect_true(
		game_state.get_order_status(order.id) == GameStateModel.OrderStatus.NOT_ACCEPTED,
		"Main order must begin as not accepted.",
		failures
	)
	expect_true(game_state.can_accept_order(order), "Valid main order must be acceptable.", failures)
	expect_true(game_state.accept_order(order), "Valid main order must be accepted.", failures)
	expect_true(
		game_state.current_order_id == order.id
		and game_state.destination_id == order.destination_planet.id
		and game_state.cargo_id == order.cargo.id,
		"Accepting an order must write stable IDs into GameState.",
		failures
	)
	expect_true(
		game_state.get_active_order_run_state() != null
		and game_state.get_active_order_run_state().order_id == order.id
		and game_state.get_order_entry_style().is_empty(),
		"Accepting an order must initialize its clean order-run result.",
		failures
	)
	expect_true(
		game_state.get_order_status(order.id) == GameStateModel.OrderStatus.ACCEPTED,
		"Accepted order must expose its accepted state.",
		failures
	)
	expect_true(
		not game_state.accept_order(order)
		and game_state.last_order_error == GameStateModel.ORDER_ERROR_ALREADY_ACCEPTED,
		"An accepted main order must not be accepted again.",
		failures
	)

	var other_order: OrderDefinition = order.duplicate(true) as OrderDefinition
	other_order.id = &"order_other_main"
	expect_true(
		game_state.get_order_acceptance_error(other_order)
		== GameStateModel.ORDER_ERROR_ACTIVE_ORDER,
		"Only one order may be active at a time.",
		failures
	)
	expect_true(
		not game_state.has_method("cancel_order") and not game_state.has_method("abandon_order"),
		"Main-order state must not expose an accidental cancellation transition.",
		failures
	)

	game_state.order_run_state.entry_style = FlightStyleTracker.STYLE_BALANCED
	expect_true(
		game_state.complete_current_order(order),
		"The active order must support the future completion transition.",
		failures
	)
	expect_true(
		game_state.get_order_entry_style() == FlightStyleTracker.STYLE_BALANCED,
		"Completing an order must retain its run result for settlement dialogue.",
		failures
	)
	expect_true(
		game_state.get_order_status(order.id) == GameStateModel.OrderStatus.COMPLETED,
		"Completed order must expose its completed state.",
		failures
	)
	expect_true(
		game_state.current_order_id.is_empty()
		and game_state.has_story_flag(&"story_red_sand_order_completed"),
		"Completion must clear the active slot and apply Resource-defined flags.",
		failures
	)
	expect_true(
		not game_state.accept_order(order)
		and game_state.last_order_error == GameStateModel.ORDER_ERROR_ALREADY_COMPLETED,
		"A completed main order must not return to the available state.",
		failures
	)
	expect_true(
		_status_events == [
			GameStateModel.OrderStatus.ACCEPTED,
			GameStateModel.OrderStatus.COMPLETED,
		],
		"Order state signals must follow the one-way transition order.",
		failures
	)

	game_state.reset_runtime_state()
	var missing_data_order: OrderDefinition = OrderDefinition.new()
	missing_data_order.id = &"order_missing_data"
	missing_data_order.display_name_key = &"ORDER_RED_SAND_M0_NAME"
	expect_true(
		not game_state.can_accept_order(missing_data_order)
		and game_state.get_order_acceptance_error(missing_data_order)
		== GameStateModel.ORDER_ERROR_MISSING_DATA,
		"Missing required order data must disable acceptance.",
		failures
	)

	var gated_order: OrderDefinition = order.duplicate(true) as OrderDefinition
	gated_order.id = &"order_story_gated"
	var story_requirements: Array[StringName] = [&"story_order_gate"]
	gated_order.story_requirements = story_requirements
	expect_true(
		game_state.get_order_acceptance_error(gated_order)
		== GameStateModel.ORDER_ERROR_STORY_REQUIREMENT,
		"Unmet Resource-defined story requirements must block acceptance.",
		failures
	)
	game_state.set_story_flag(&"story_order_gate")
	expect_true(
		game_state.accept_order(gated_order),
		"Meeting the story requirement must unlock the order.",
		failures
	)
	game_state.free()
	return failures


func _on_order_status_changed(
	_order_id: StringName,
	status: GameStateModel.OrderStatus
) -> void:
	_status_events.append(status)
