extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameStateModel = GameStateModel.new()

	game_state.current_order_id = &"order_test"
	game_state.destination_id = &"planet_test"
	game_state.cargo_id = &"cargo_test"
	game_state.ship_configuration[&"utility"] = &"module_test"
	game_state.set_story_flag(&"story_test")
	game_state.mark_dialogue_line_read(&"dialogue_test", &"line_test")
	game_state.completed_order_ids[&"order_completed_test"] = true
	expect_true(game_state.has_story_flag(&"story_test"), "Story flag must be readable.", failures)
	expect_true(
		game_state.has_read_dialogue_line(&"dialogue_test", &"line_test"),
		"Read dialogue state must be readable.",
		failures
	)
	game_state.reset_runtime_state()

	expect_true(game_state.current_order_id.is_empty(), "Order ID must clear on reset.", failures)
	expect_true(game_state.destination_id.is_empty(), "Destination ID must clear on reset.", failures)
	expect_true(game_state.cargo_id.is_empty(), "Cargo ID must clear on reset.", failures)
	expect_true(game_state.ship_configuration.is_empty(), "Ship configuration must clear on reset.", failures)
	expect_true(game_state.story_flags.is_empty(), "Story flags must clear on reset.", failures)
	expect_true(game_state.read_dialogue_ids.is_empty(), "Read dialogue IDs must clear on reset.", failures)
	expect_true(game_state.completed_order_ids.is_empty(), "Completed orders must clear on reset.", failures)
	game_state.free()
	return failures
