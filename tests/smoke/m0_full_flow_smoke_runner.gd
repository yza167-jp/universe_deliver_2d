extends SceneTree

const APP_SCENE_PATH: String = "res://scenes/app/app.tscn"
const TEST_SAVE_PATH: String = "user://t054_full_flow.json"
const TEST_TEMP_PATH: String = "user://t054_full_flow.tmp"
const TEST_BACKUP_PATH: String = "user://t054_full_flow.backup.json"
const TEST_REJECTED_PATH: String = "user://t054_full_flow.invalid.json"
const MAX_DIALOGUE_LINES: int = 24

var _failures: PackedStringArray = []
var _stage_history: PackedInt32Array = []
var _original_locale: String = ""
var _original_automatic_saves: bool = false
var _game_state: GameStateModel
var _scene_router: SceneRouterService
var _save_service: SaveServiceModel
var _app: UniverseDeliverApp


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_scene_router = root.get_node_or_null("SceneRouter") as SceneRouterService
	_save_service = root.get_node_or_null("SaveService") as SaveServiceModel
	_check(_game_state != null, "M0 flow requires GameState.")
	_check(_scene_router != null, "M0 flow requires SceneRouter.")
	_check(_save_service != null, "M0 flow requires SaveService.")
	if _game_state == null or _scene_router == null or _save_service == null:
		await _cleanup()
		_finish()
		return

	_original_automatic_saves = _save_service.automatic_saves_enabled
	_save_service.set_automatic_saves_enabled(true)
	_save_service.configure_storage_paths(
		TEST_SAVE_PATH,
		TEST_TEMP_PATH,
		TEST_BACKUP_PATH,
		TEST_REJECTED_PATH
	)
	_remove_test_save_files()
	_game_state.reset_runtime_state()
	if not _scene_router.stage_changed.is_connected(_record_stage):
		_scene_router.stage_changed.connect(_record_stage)

	var main_menu: MainMenu = await _start_app()
	if main_menu == null:
		await _cleanup()
		_finish()
		return
	_check(main_menu.start_new_game(), "New Game could not enter the station.")
	await _wait_frames(3)
	_check_stage(SceneRouterService.Stage.STATION, "New Game")
	_check(
		_game_state.main_story_chapter.is_empty()
		and _game_state.unlocked_planet_ids.is_empty()
		and _game_state.planet_relation_values.is_empty()
		and _game_state.planet_permission_ids.is_empty()
		and _game_state.codex_entry_ids.is_empty()
		and _game_state.souvenir_ids.is_empty()
		and _game_state.completed_side_order_ids.is_empty()
		and _game_state.failed_side_order_ids.is_empty()
		and _game_state.station_state_level == 0
		and _game_state.ship_upgrade_ids.is_empty()
		and _game_state.revisit_state.is_empty()
		and _game_state.demo_ending_flags.is_empty()
		and _game_state.last_stable_station_state.is_empty(),
		"M0 New Game accidentally received M1 progress."
	)

	var station: StationHub = _get_active_scene() as StationHub
	if not await _complete_first_departure(station):
		await _cleanup()
		_finish()
		return
	_check_stage(SceneRouterService.Stage.COCKPIT, "Station departure")

	var cockpit: Cockpit = _get_active_scene() as Cockpit
	if not await _complete_cockpit_travel(cockpit):
		await _cleanup()
		_finish()
		return
	_check_stage(SceneRouterService.Stage.FLIGHT, "Cockpit travel", false)

	var route: RedSandFlight = _get_active_scene() as RedSandFlight
	if not await _complete_flight_with_retry(route):
		await _cleanup()
		_finish()
		return
	_check_stage(SceneRouterService.Stage.ARRIVAL, "Successful landing")

	var arrival: RedSandArrival = _get_active_scene() as RedSandArrival
	if not await _complete_arrival(arrival):
		await _cleanup()
		_finish()
		return
	_check_stage(SceneRouterService.Stage.RESULTS, "Arrival return beacon")

	var results: OrderResults = _get_active_scene() as OrderResults
	if not await _complete_results(results):
		await _cleanup()
		_finish()
		return
	_check_stage(SceneRouterService.Stage.STATION, "Results return")

	station = _get_active_scene() as StationHub
	if not await _complete_station_return(station):
		await _cleanup()
		_finish()
		return
	var settled_credits: int = _game_state.get_credits()
	_check(
		FileAccess.file_exists(TEST_SAVE_PATH),
		"Completed station return did not leave a primary save."
	)

	await _release_app()
	_game_state.reset_runtime_state()
	_check(
		_game_state.get_credits() == 0
		and not _game_state.has_completed_order(&"order_red_sand_m0"),
		"Restart fixture did not clear runtime progress."
	)

	main_menu = await _start_app()
	if main_menu == null:
		await _cleanup()
		_finish()
		return
	_check(main_menu.is_continue_button_enabled(), "Completed M0 save did not enable Continue.")
	_check(main_menu.continue_game(), "Continue could not restore the completed M0 save.")
	await _wait_frames(4)
	_check_stage(SceneRouterService.Stage.STATION, "Continue")
	station = _get_active_scene() as StationHub
	_check(station != null, "Continue did not instantiate the station.")
	_check(
		_game_state.get_credits() == settled_credits
		and settled_credits > 0
		and _game_state.has_completed_order(&"order_red_sand_m0")
		and _game_state.has_station_upgrade(
			M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
		)
		and _game_state.main_story_chapter
		== GameProgressData.RED_SAND_REVISIT_CHAPTER_ID
		and _game_state.has_story_flag(
			GameProgressData.RED_SAND_ORDER_COMPLETION_FLAG
		)
		and _game_state.unlocked_planet_ids
		== [GameProgressData.RED_SAND_PLANET_ID]
		and _game_state.souvenir_ids
		== [GameProgressData.RELAY_PLAQUE_SOUVENIR_ID]
		and not _game_state.unlocked_planet_ids.has(&"planet_white_noise")
		and not _game_state.ship_upgrade_ids.has(&"module_high_voltage_shielding"),
		"Continue lost M0 results or created invalid M1 unlocks."
	)
	if station != null:
		var departure: StationDepartureController = station.get_departure_controller()
		_check(
			departure != null
			and departure.get_flow_state()
			== StationDepartureController.FlowState.WAIT_FOR_ORDER
			and departure.get_objective_text().contains(
				"赤砂星屏蔽改装回访"
			),
			"Continued station did not bridge the completed first order into its revisit."
		)

	var expected_history: PackedInt32Array = PackedInt32Array([
		SceneRouterService.Stage.MAIN_MENU,
		SceneRouterService.Stage.STATION,
		SceneRouterService.Stage.COCKPIT,
		SceneRouterService.Stage.FLIGHT,
		SceneRouterService.Stage.ARRIVAL,
		SceneRouterService.Stage.RESULTS,
		SceneRouterService.Stage.STATION,
		SceneRouterService.Stage.MAIN_MENU,
		SceneRouterService.Stage.STATION,
	])
	_check(
		_stage_history == expected_history,
		"M0 stages did not remain linear across restart: %s" % _format_stage_history()
	)
	_check(not paused, "M0 flow left SceneTree paused after Continue.")
	_check_persistent_dialogue_closed("completed Continue")

	await _cleanup()
	_finish()


func _complete_first_departure(station: StationHub) -> bool:
	_check(station != null, "New Game did not instantiate StationHub.")
	if station == null:
		return false
	var tutorial: StationTutorialController = station.get_tutorial_controller()
	var player: StationPlayer = station.get_station_player()
	var lao_pi: LaoPiStation = station.get_lao_pi()
	var terminal_ui: OrderTerminalUI = station.get_order_terminal_ui()
	var loadout_ui: ShipLoadoutUI = station.get_ship_loadout_ui()
	var departure: StationDepartureController = station.get_departure_controller()
	var order_terminal: Interactable2D = station.get_node_or_null(
		"Interactables/OrderTerminal"
	) as Interactable2D
	var workbench: Interactable2D = station.get_node_or_null(
		"Interactables/ShipWorkbench"
	) as Interactable2D
	var cockpit_entry: Interactable2D = station.get_node_or_null(
		"Interactables/CockpitEntry"
	) as Interactable2D
	_check(
		tutorial != null
		and player != null
		and lao_pi != null
		and terminal_ui != null
		and loadout_ui != null
		and departure != null
		and order_terminal != null
		and workbench != null
		and cockpit_entry != null,
		"Station departure dependencies are incomplete."
	)
	if (
		tutorial == null
		or player == null
		or lao_pi == null
		or terminal_ui == null
		or loadout_ui == null
		or departure == null
		or order_terminal == null
		or workbench == null
		or cockpit_entry == null
	):
		return false
	var dialogue_ui: DialogueUI = tutorial.get_dialogue_ui()
	if dialogue_ui == null:
		_check(false, "Station tutorial could not resolve DialogueUI.")
		return false

	await _finish_station_dialogue(
		tutorial,
		dialogue_ui,
		&"dialogue_lao_pi_tutorial_intro"
	)
	player.position += Vector2(48.0, 0.0)
	await _wait_frames(2)
	await _finish_station_dialogue(
		tutorial,
		dialogue_ui,
		&"dialogue_lao_pi_tutorial_move_ack"
	)
	_check(lao_pi.interact(player), "Lao Pi tutorial interaction failed.")
	await _finish_station_dialogue(
		tutorial,
		dialogue_ui,
		&"dialogue_lao_pi_tutorial_interact_ack"
	)
	_check(order_terminal.interact(player), "Tutorial order-terminal interaction failed.")
	await _finish_station_dialogue(
		tutorial,
		dialogue_ui,
		&"dialogue_lao_pi_tutorial_complete"
	)
	await _wait_frames(2)
	_check(tutorial.is_tutorial_complete(), "Station tutorial did not complete.")
	_check(terminal_ui.visible, "Tutorial completion did not open the order terminal.")
	if not tutorial.is_tutorial_complete() or not terminal_ui.visible:
		return false

	_check(terminal_ui.accept_current_order(), "Red Sand order could not be accepted.")
	terminal_ui.close_terminal()
	await _wait_frames(1)
	await _finish_station_dialogue(
		tutorial,
		dialogue_ui,
		&"dialogue_lao_pi_order_accepted"
	)
	_check(workbench.interact(player), "Ship workbench could not open.")
	await _wait_frames(1)
	_check(
		loadout_ui.toggle_module_for_slot(ShipModuleDefinition.SlotType.UTILITY),
		"Asteroid laser could not be selected."
	)
	_check(
		loadout_ui.toggle_module_by_id(
			ShipLoadoutRules.SHIELD_BACKUP_POWER_MODULE_ID
		),
		"Shield backup power could not be selected independently."
	)
	_check(loadout_ui.confirm_departure(), "Ship loadout could not confirm departure.")
	loadout_ui.close_loadout()
	await _wait_frames(1)
	_check(
		departure.get_flow_state()
		== StationDepartureController.FlowState.READY_FOR_COCKPIT,
		"Confirmed order and loadout did not unlock the cockpit."
	)
	_check(cockpit_entry.interact(player), "Cockpit entrance interaction failed.")
	await _wait_frames(2)
	_check(departure.is_departure_gate_visible(), "Departure confirmation did not open.")
	_check(departure.enter_cockpit(), "Departure confirmation could not enter Cockpit.")
	await _wait_frames(3)
	_check_single_stage_scene("station-to-cockpit")
	_check_persistent_dialogue_closed("station-to-cockpit")
	return _scene_router.current_stage == SceneRouterService.Stage.COCKPIT


func _complete_cockpit_travel(cockpit: Cockpit) -> bool:
	_check(cockpit != null, "Cockpit stage did not instantiate.")
	if cockpit == null:
		return false
	var travel_audio: AudioStreamPlayer = cockpit.get_node_or_null(
		"TravelAudioPlayer"
	) as AudioStreamPlayer
	var radio_audio: AudioStreamPlayer = cockpit.get_radio_audio_player()
	_check(
		cockpit.activate_hotspot(&"navigation_screen"),
		"Navigation could not open for the confirmed order."
	)
	await _wait_frames(1)
	_check(cockpit.start_configured_travel(), "Navigation could not start travel.")
	var controller: TravelSequenceController = cockpit.get_travel_controller()
	var dialogue_ui: DialogueUI = cockpit.get_dialogue_ui()
	_check(controller != null and dialogue_ui != null, "Cockpit travel dependencies are missing.")
	if controller == null or dialogue_ui == null:
		return false
	controller.set_process(false)
	controller.advance_travel(controller.departure_duration + 0.1)
	await _wait_frames(2)
	_check(
		cockpit.get_active_dialogue_id() == &"dialogue_lao_pi_travel_main",
		"Cruise did not start the required Lao Pi dialogue."
	)
	_check(
		dialogue_ui.skip_dialogue_sequence()
		== DialogueRuntime.SequenceSkipResult.FINISHED,
		"Required cockpit dialogue could not finish."
	)
	await _wait_frames(1)
	controller.advance_travel(controller.cruise_duration + 0.1)
	controller.advance_travel(controller.approach_duration + 0.1)
	_check(
		travel_audio != null
		and not travel_audio.playing
		and travel_audio.stream == null
		and radio_audio != null
		and not radio_audio.playing
		and radio_audio.stream == null,
		"Cockpit audio survived the stage transition."
	)
	await _wait_frames(3)
	_check_single_stage_scene("cockpit-to-flight")
	_check_persistent_dialogue_closed("cockpit-to-flight")
	return _scene_router.current_stage == SceneRouterService.Stage.FLIGHT


func _complete_flight_with_retry(route: RedSandFlight) -> bool:
	_check(route != null, "Flight stage did not instantiate RedSandFlight.")
	if route == null:
		return false
	await _wait_frames(2)
	_check(route.is_controls_help_open() and paused, "Flight help did not pause the route.")
	_check(route.close_controls_help(), "Flight help could not close.")
	_check(not paused, "Closing Flight help did not resume the route.")
	route.set_process(false)
	route.set_physics_process(false)
	var flight_ship: FlightLabShip = route.get_flight_ship()
	var landing_zone: RedSandLandingZone = route.get_landing_zone()
	var definition: FlightRouteDefinition = route.get_route_definition()
	var feedback: RedSandEnvironmentFeedback = route.get_environment_feedback()
	_check(
		flight_ship != null
		and landing_zone != null
		and definition != null
		and feedback != null,
		"Flight retry dependencies are missing."
	)
	if (
		flight_ship == null
		or landing_zone == null
		or definition == null
		or feedback == null
	):
		return false
	_check(
		flight_ship.is_shield_backup_power_enabled(),
		"Installed shield backup power did not propagate into the flight ship."
	)
	flight_ship.shield = 80.0
	flight_ship.velocity = Vector2.ZERO
	flight_ship.integrate_motion(0.0, 0.0, 0.0, 1.0)
	_check(
		flight_ship.shield > 80.0
		and is_equal_approx(
			flight_ship.get_shield_regeneration_rate(),
			flight_ship.tuning.shield_regeneration_per_second
		),
		"Idle installed backup power did not regenerate the shield."
	)
	flight_ship.shield = 80.0
	flight_ship.integrate_motion(1.0, 0.0, 0.0, 0.25, 1.0)
	_check(
		is_equal_approx(flight_ship.shield, 80.0),
		"Shield backup power regenerated while Boost was active."
	)
	flight_ship.shield = 100.0
	flight_ship.velocity = Vector2.ZERO
	flight_ship.set_physics_process(false)
	var final_segment: FlightRouteSegment = definition.segments[-1]
	flight_ship.position = Vector2(
		route.route_origin_x + final_segment.start_distance + 1.0,
		-80.0
	)
	flight_ship.velocity = Vector2(125.0, 4.0)
	_check(route.advance_route_state(), "Flight could not reach final approach.")
	for _sync_frame: int in range(5):
		await physics_frame
		route._physics_process(0.0)
	route._process(0.0)
	_check(
		route.get_active_segment_index() == definition.segments.size() - 1,
		"Flight did not enter Stage 8."
	)

	_touch_down(route, landing_zone, Vector2(220.0, 92.0), deg_to_rad(4.0))
	_check(
		flight_ship.is_failed
		and route.is_retry_pending()
		and not route.is_route_completed(),
		"Unsafe touchdown did not enter the retry flow."
	)
	var retry_delay: float = flight_ship.tuning.failure_retry_delay_seconds
	route._process(retry_delay + 0.1)
	_check(
		not flight_ship.is_failed
		and not route.is_retry_pending()
		and flight_ship.position == landing_zone.get_safe_checkpoint_position(),
		"Automatic retry did not restore the final-approach checkpoint."
	)

	var ambience_audio: AudioStreamPlayer = feedback.get_ambience_audio()
	var music_audio: AudioStreamPlayer = feedback.get_music_audio()
	var radar_audio: AudioStreamPlayer = feedback.get_radar_pulse_audio()
	_touch_down(route, landing_zone, Vector2(130.0, 55.0), deg_to_rad(14.0))
	_check(
		route.is_route_completed()
		and route.get_landing_result() == OrderRunState.LANDING_RESULT_ROUGH,
		"Recoverable retry did not complete a rough landing."
	)
	var arrival_delay: float = flight_ship.tuning.landing_arrival_transition_delay_seconds
	route._process(arrival_delay + 0.1)
	_check(
		ambience_audio != null
		and not ambience_audio.playing
		and music_audio != null
		and not music_audio.playing
		and radar_audio != null
		and not radar_audio.playing,
		"Flight environment audio survived the stage transition."
	)
	await _wait_frames(3)
	_check_single_stage_scene("flight-to-arrival")
	_check(not paused, "Flight-to-Arrival transition left SceneTree paused.")
	return _scene_router.current_stage == SceneRouterService.Stage.ARRIVAL


func _complete_arrival(arrival: RedSandArrival) -> bool:
	_check(arrival != null, "Arrival stage did not instantiate.")
	if arrival == null:
		return false
	await _wait_frames(2)
	var dialogue_ui: DialogueUI = arrival.get_dialogue_ui()
	_check(
		dialogue_ui != null and arrival.is_main_dialogue_active(),
		"Arrival main dialogue did not start."
	)
	if dialogue_ui == null:
		return false
	_check(
		dialogue_ui.skip_dialogue_sequence()
		== DialogueRuntime.SequenceSkipResult.FINISHED,
		"Arrival main dialogue could not finish."
	)
	await _wait_frames(1)
	_check(arrival.is_exploration_unlocked(), "Arrival exploration did not unlock.")
	var beacon: Interactable2D = arrival.get_return_beacon()
	_check(
		beacon != null and beacon.interact(arrival.get_station_player()),
		"Arrival return beacon could not enter Results."
	)
	await _wait_frames(3)
	_check_single_stage_scene("arrival-to-results")
	_check_persistent_dialogue_closed("arrival-to-results")
	return _scene_router.current_stage == SceneRouterService.Stage.RESULTS


func _complete_results(results: OrderResults) -> bool:
	_check(results != null, "Results stage did not instantiate.")
	if results == null:
		return false
	await _wait_frames(3)
	_check(
		results.is_settlement_committed()
		and _game_state.has_completed_order(&"order_red_sand_m0")
		and _game_state.get_credits() > 0,
		"Results did not commit the completed first order."
	)
	_check(
		FileAccess.file_exists(TEST_SAVE_PATH),
		"Stable Results stage did not autosave."
	)
	_check(results.return_to_station(), "Results could not return to Station.")
	await _wait_frames(4)
	_check_single_stage_scene("results-to-station")
	return _scene_router.current_stage == SceneRouterService.Stage.STATION


func _complete_station_return(station: StationHub) -> bool:
	_check(station != null, "Returned Station did not instantiate.")
	if station == null:
		return false
	var tutorial: StationTutorialController = station.get_tutorial_controller()
	var return_state: StationReturnStateController = station.get_return_state_controller()
	_check(
		tutorial != null
		and return_state != null
		and return_state.is_first_delivery_display_visible(),
		"Returned Station did not expose the completed-delivery state."
	)
	if tutorial == null or return_state == null:
		return false
	var dialogue_ui: DialogueUI = tutorial.get_dialogue_ui()
	_check(
		dialogue_ui != null
		and tutorial.get_active_dialogue_id()
		== &"dialogue_lao_pi_first_delivery_return",
		"Returned Station did not start Lao Pi's first-delivery response."
	)
	if dialogue_ui == null:
		return false
	_check(
		dialogue_ui.skip_dialogue_sequence()
		== DialogueRuntime.SequenceSkipResult.FINISHED,
		"Lao Pi return dialogue could not finish."
	)
	await _wait_frames(3)
	_check(
		_game_state.has_story_flag(M0ProgressIds.STORY_RETURN_DIALOGUE_COMPLETED)
		and not _game_state.has_story_flag(M0ProgressIds.STORY_RETURN_DIALOGUE_PENDING),
		"Station return dialogue completion did not persist."
	)
	_check_persistent_dialogue_closed("returned station")
	return true


func _finish_station_dialogue(
	tutorial: StationTutorialController,
	dialogue_ui: DialogueUI,
	expected_dialogue_id: StringName
) -> void:
	_check(
		tutorial.get_active_dialogue_id() == expected_dialogue_id,
		"Expected station dialogue was not active: %s" % expected_dialogue_id
	)
	var remaining_lines: int = MAX_DIALOGUE_LINES
	while tutorial.get_active_dialogue_id() == expected_dialogue_id and remaining_lines > 0:
		dialogue_ui.quick_show_current_line()
		_check(
			dialogue_ui.continue_dialogue(),
			"Station dialogue could not advance: %s" % expected_dialogue_id
		)
		remaining_lines -= 1
		await process_frame
	_check(
		remaining_lines > 0,
		"Station dialogue exceeded its line limit: %s" % expected_dialogue_id
	)


func _touch_down(
	route: RedSandFlight,
	landing_zone: RedSandLandingZone,
	velocity: Vector2,
	pitch_radians: float
) -> void:
	var flight_ship: FlightLabShip = route.get_flight_ship()
	flight_ship.global_position = landing_zone.global_position + Vector2(
		0.0,
		landing_zone.get_touchdown_center_y() - 2.0
	)
	flight_ship.velocity = velocity
	flight_ship.rotation = pitch_radians
	route._physics_process(1.0 / 60.0)
	flight_ship.global_position.y = (
		landing_zone.global_position.y
		+ landing_zone.get_touchdown_center_y()
		+ 1.0
	)
	route._physics_process(1.0 / 60.0)


func _start_app() -> MainMenu:
	var app_scene: PackedScene = load(APP_SCENE_PATH) as PackedScene
	_check(app_scene != null, "App scene could not load.")
	if app_scene == null:
		return null
	_app = app_scene.instantiate() as UniverseDeliverApp
	_check(_app != null, "App scene root is not UniverseDeliverApp.")
	if _app == null:
		return null
	root.add_child(_app)
	await _wait_frames(3)
	_check_single_stage_scene("App startup")
	return _get_active_scene() as MainMenu


func _get_active_scene() -> Node:
	if _app == null or not is_instance_valid(_app):
		return null
	if _app.scene_container.get_child_count() != 1:
		return null
	return _app.scene_container.get_child(0)


func _check_stage(
	expected_stage: int,
	context: String,
	expect_unpaused: bool = true
) -> void:
	_check(
		_scene_router.current_stage == expected_stage,
		"%s ended at %s instead of %s."
		% [
			context,
			SceneRouterService.get_stage_name(_scene_router.current_stage),
			SceneRouterService.get_stage_name(expected_stage),
		]
	)
	_check_single_stage_scene(context)
	if expect_unpaused:
		_check(not paused, "%s left SceneTree paused." % context)


func _check_single_stage_scene(context: String) -> void:
	_check(
		_app != null
		and is_instance_valid(_app)
		and _app.scene_container.get_child_count() == 1,
		"%s did not retain exactly one stage scene." % context
	)


func _check_persistent_dialogue_closed(context: String) -> void:
	var dialogue_ui: DialogueUI = (
		_app.get_node_or_null("PersistentUI/DialogueUI") as DialogueUI
		if _app != null and is_instance_valid(_app)
		else null
	)
	_check(
		dialogue_ui != null and not dialogue_ui.visible,
		"%s left the persistent DialogueUI visible." % context
	)


func _record_stage(_previous_stage: int, current_stage: int) -> void:
	_stage_history.append(current_stage)


func _format_stage_history() -> String:
	var names: PackedStringArray = []
	for stage: int in _stage_history:
		names.append(SceneRouterService.get_stage_name(stage))
	return " -> ".join(names)


func _wait_frames(frame_count: int) -> void:
	for _frame: int in range(maxi(frame_count, 0)):
		await process_frame


func _release_app() -> void:
	if _app == null or not is_instance_valid(_app):
		_app = null
		return
	_app.queue_free()
	await _wait_frames(2)
	_app = null
	_check(not paused, "Releasing App left SceneTree paused.")


func _cleanup() -> void:
	await _release_app()
	if _scene_router != null and _scene_router.stage_changed.is_connected(_record_stage):
		_scene_router.stage_changed.disconnect(_record_stage)
	if _game_state != null:
		_game_state.reset_runtime_state()
	_remove_test_save_files()
	if _save_service != null:
		_save_service.reset_storage_paths()
		_save_service.set_automatic_saves_enabled(_original_automatic_saves)
	TranslationServer.set_locale(_original_locale)


func _remove_test_save_files() -> void:
	for path: String in [
		TEST_SAVE_PATH,
		TEST_TEMP_PATH,
		TEST_BACKUP_PATH,
		TEST_REJECTED_PATH,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish() -> void:
	if _failures.is_empty():
		print(
			"[m0-full-flow] PASS: New Game, first departure, travel, failed landing retry, "
			+ "arrival, settlement, station return, autosave, and Continue."
		)
		quit(0)
		return
	printerr("[m0-full-flow] FAILED with %d error(s):" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
