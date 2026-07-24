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
	game_state.credits = 47
	game_state.station_upgrade_ids[&"station_upgrade_test"] = true
	game_state.departure_confirmed = true
	game_state.travel_state = GameStateModel.TravelState.CRUISE
	game_state.travel_destination_id = &"planet_test"
	game_state.last_travel_error = GameStateModel.TRAVEL_ERROR_ALREADY_STARTED
	game_state.order_run_state.reset(&"order_test")
	game_state.order_run_state.entry_style = FlightStyleTracker.STYLE_DIVE
	game_state.order_run_state.record_landing_result(
		OrderRunState.LANDING_RESULT_ROUGH,
		6.0
	)
	game_state.main_story_chapter = &"chapter_m1_red_sand_revisit"
	game_state.unlocked_planet_ids = [&"planet_red_sand"]
	game_state.planet_relation_values[&"planet_red_sand"] = 1
	game_state.planet_permission_ids = [&"permission_test"]
	game_state.codex_entry_ids = [&"codex_test"]
	game_state.souvenir_ids = [&"souvenir_test"]
	game_state.completed_side_order_ids = [&"side_completed"]
	game_state.failed_side_order_ids = [&"side_failed"]
	game_state.station_state_level = 1
	game_state.ship_upgrade_ids = [&"module_test"]
	game_state.revisit_state[&"planet_red_sand"] = &"revisit_available"
	game_state.demo_ending_flags[&"ending_test"] = true
	game_state.last_stable_station_state = &"station_after_first_delivery"
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
	expect_true(
		game_state.ship_configuration
		== ShipLoadoutRules.create_default_configuration(),
		"Ship configuration must restore the fixed ship's safe defaults on reset.",
		failures
	)
	expect_true(game_state.story_flags.is_empty(), "Story flags must clear on reset.", failures)
	expect_true(game_state.read_dialogue_ids.is_empty(), "Read dialogue IDs must clear on reset.", failures)
	expect_true(game_state.completed_order_ids.is_empty(), "Completed orders must clear on reset.", failures)
	expect_true(game_state.get_credits() == 0, "Credits must clear on runtime reset.", failures)
	expect_true(
		game_state.station_upgrade_ids.is_empty(),
		"Station upgrades must clear on runtime reset.",
		failures
	)
	expect_true(not game_state.departure_confirmed, "Departure readiness must clear on reset.", failures)
	expect_true(
		game_state.travel_state == GameStateModel.TravelState.IDLE,
		"Travel state must return to idle on reset.",
		failures
	)
	expect_true(
		game_state.travel_destination_id.is_empty(),
		"Travel destination must clear on reset.",
		failures
	)
	expect_true(
		game_state.last_travel_error.is_empty(),
		"Travel errors must clear on reset.",
		failures
	)
	expect_true(
		game_state.order_run_state != null
		and game_state.order_run_state.order_id.is_empty()
		and game_state.get_order_entry_style().is_empty()
		and game_state.order_run_state.landing_result.is_empty()
		and is_zero_approx(game_state.order_run_state.landing_cargo_damage),
		"Order-run entry and landing results must clear on runtime reset.",
		failures
	)
	expect_true(
		game_state.main_story_chapter.is_empty()
		and game_state.unlocked_planet_ids.is_empty()
		and game_state.planet_relation_values.is_empty()
		and game_state.planet_permission_ids.is_empty()
		and game_state.codex_entry_ids.is_empty()
		and game_state.souvenir_ids.is_empty()
		and game_state.completed_side_order_ids.is_empty()
		and game_state.failed_side_order_ids.is_empty()
		and game_state.station_state_level == 0
		and game_state.ship_upgrade_ids.is_empty()
		and game_state.revisit_state.is_empty()
		and game_state.demo_ending_flags.is_empty()
		and game_state.last_stable_station_state.is_empty(),
		"M1 progress fields must return to safe New Game defaults.",
		failures
	)
	game_state.free()
	return failures
