extends SceneTree

const APP_SCENE_PATH: String = "res://scenes/app/app.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTRACT_PATH: String = (
	"res://data/settlements/white_noise_side_order_contract.tres"
)
const TEST_SAVE_PATH: String = "user://t126_white_noise_side_flow.json"
const TEST_TEMP_PATH: String = "user://t126_white_noise_side_flow.tmp"
const TEST_BACKUP_PATH: String = (
	"user://t126_white_noise_side_flow.backup.json"
)
const TEST_REJECTED_PATH: String = (
	"user://t126_white_noise_side_flow.invalid.json"
)

var _failures: PackedStringArray = []
var _original_locale: String = ""
var _game_state: GameStateModel
var _scene_router: SceneRouterService
var _save_service: SaveServiceModel
var _registry: GameDataRegistry
var _contract: WhiteNoiseSideOrderContract
var _app: UniverseDeliverApp


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_scene_router = root.get_node_or_null("SceneRouter") as SceneRouterService
	_save_service = root.get_node_or_null("SaveService") as SaveServiceModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_contract = load(CONTRACT_PATH) as WhiteNoiseSideOrderContract
	_check(_game_state != null, "T-126 smoke requires GameState.")
	_check(_scene_router != null, "T-126 smoke requires SceneRouter.")
	_check(_save_service != null, "T-126 smoke requires SaveService.")
	_check(_registry != null, "T-126 smoke requires the M1 registry.")
	_check(_contract != null, "T-126 smoke requires the side-order contract.")
	if (
		_game_state == null
		or _scene_router == null
		or _save_service == null
		or _registry == null
		or _contract == null
	):
		await _finish()
		return
	_save_service.set_automatic_saves_enabled(false)
	_save_service.set_isolated_debug_session(false)
	_save_service.configure_storage_paths(
		TEST_SAVE_PATH,
		TEST_TEMP_PATH,
		TEST_BACKUP_PATH,
		TEST_REJECTED_PATH
	)
	_remove_test_files()
	if not _prepare_post_mainline_state():
		await _finish()
		return
	var packed_app: PackedScene = load(APP_SCENE_PATH) as PackedScene
	_app = packed_app.instantiate() as UniverseDeliverApp
	_check(_app != null, "T-126 App scene did not instantiate.")
	if _app == null:
		await _finish()
		return
	root.add_child(_app)
	await _wait_frames(3)
	if not await _accept_and_configure_from_station():
		await _finish()
		return
	if not await _complete_cockpit_and_short_route():
		await _finish()
		return
	if not await _complete_arrival_choice():
		await _finish()
		return
	if not await _complete_results_and_return():
		await _finish()
		return
	await _check_save_and_continue()
	await _finish()


func _prepare_post_mainline_state() -> bool:
	_game_state.reset_runtime_state()
	_game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_CANOPY_WORLD
	_game_state.unlocked_planet_ids = [
		M1ProgressRules.PLANET_RED_SAND,
		M1ProgressRules.PLANET_WHITE_NOISE,
		M1ProgressRules.PLANET_CANOPY_WORLD,
	]
	_game_state.planet_permission_ids.append(
		M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
	)
	for completed_order_id: StringName in [
		M1CatalogModel.M0_ORDER_ID,
		M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT,
		&"order_m1_white_noise_archive_core",
	]:
		_game_state.completed_order_ids[completed_order_id] = true
		_game_state.order_states[
			completed_order_id
		] = GameStateModel.OrderStatus.COMPLETED
		_game_state.reward_applied_order_ids.append(completed_order_id)
	for story_flag: StringName in [
		M1ProgressRules.STORY_RED_SAND_SHIELDING_RETROFIT_COMPLETED,
		&"story_m1_white_noise_archive_core_completed",
		&"story_m1_white_noise_archive_terminal_updated",
		StationTutorialController.COMPLETION_FLAG,
		M0ProgressIds.STORY_RETURN_DIALOGUE_COMPLETED,
	]:
		_game_state.set_story_flag(story_flag)
	_game_state.unlock_station_state(
		StationStateRules.ARCHIVE_TERMINAL_ID
	)
	var shielding: ShipModuleDefinition = _registry.find_module(
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
	)
	if shielding == null:
		_check(false, "T-126 high-voltage shielding module is missing.")
		return false
	if not _game_state.ship_upgrade_ids.has(shielding.id):
		_game_state.ship_upgrade_ids.append(shielding.id)
	var prepared: bool = (
		_game_state.equip_ship_module(shielding)
		and _game_state.can_accept_order(_contract.order)
	)
	_check(
		prepared,
		"T-126 post-mainline state could not expose the optional order."
	)
	return prepared


func _accept_and_configure_from_station() -> bool:
	_check(
		_scene_router.debug_switch_to_stage(
			SceneRouterService.Stage.STATION
		),
		"T-126 could not open the qualified station."
	)
	await _wait_frames(4)
	var station: StationHub = _get_active_scene() as StationHub
	_check(station != null, "T-126 station did not instantiate.")
	if station == null:
		return false
	var player: StationPlayer = station.get_station_player()
	var order_terminal: Interactable2D = station.get_node_or_null(
		"Interactables/OrderTerminal"
	) as Interactable2D
	var terminal: OrderTerminalUI = station.get_order_terminal_ui()
	_check(
		player != null
		and order_terminal != null
		and terminal != null
		and order_terminal.interact(player),
		"T-126 station order terminal could not open."
	)
	await _wait_frames(3)
	_check(
		terminal != null
		and terminal.select_order(_contract.order.id)
		and terminal.is_accept_enabled()
		and terminal.get_feedback_text().contains("自愿支线")
		and terminal.accept_current_order()
		and _game_state.current_order_id == _contract.order.id,
		"T-126 optional order was not clearly voluntary or could not be accepted."
	)
	if terminal == null or _game_state.current_order_id != _contract.order.id:
		return false
	terminal.close_terminal()
	await _wait_frames(2)
	var tutorial_dialogue: DialogueUI = (
		station.get_tutorial_controller().get_dialogue_ui()
	)
	if tutorial_dialogue != null and tutorial_dialogue.visible:
		tutorial_dialogue.skip_dialogue_sequence()
		await _wait_frames(2)

	var workbench: Interactable2D = station.get_node_or_null(
		"Interactables/ShipWorkbench"
	) as Interactable2D
	var loadout: ShipLoadoutUI = station.get_ship_loadout_ui()
	_check(
		workbench != null
		and loadout != null
		and workbench.interact(player),
		"T-126 ship configuration could not open."
	)
	await _wait_frames(3)
	_check(
		loadout != null
		and loadout.get_order_definition_id() == _contract.order.id
		and loadout.is_confirm_enabled()
		and loadout.confirm_departure()
		and _game_state.is_departure_confirmed_for_order(_contract.order),
		"T-126 loadout could not confirm the short side-order departure."
	)
	if (
		loadout == null
		or not _game_state.is_departure_confirmed_for_order(_contract.order)
	):
		return false
	loadout.close_loadout()
	await _wait_frames(2)

	var cockpit_entry: Interactable2D = station.get_node_or_null(
		"Interactables/CockpitEntry"
	) as Interactable2D
	var departure: StationDepartureController = (
		station.get_departure_controller()
	)
	_check(
		cockpit_entry != null
		and departure != null
		and cockpit_entry.interact(player)
		and departure.is_departure_gate_visible()
		and departure.enter_cockpit(),
		"T-126 confirmed station flow could not enter the cockpit."
	)
	await _wait_frames(4)
	return (
		_scene_router.current_stage == SceneRouterService.Stage.COCKPIT
		and _get_active_scene() is Cockpit
	)


func _complete_cockpit_and_short_route() -> bool:
	var cockpit: Cockpit = _get_active_scene() as Cockpit
	_check(cockpit != null, "T-126 cockpit did not instantiate.")
	if cockpit == null:
		return false
	_check(
		cockpit.activate_hotspot(&"company_terminal")
		and cockpit.get_device_panel_body().contains("可选返件")
		and cockpit.close_active_modal()
		and cockpit.activate_hotspot(&"cargo_indicator")
		and cockpit.get_device_panel_body().contains("记忆盒")
		and cockpit.close_active_modal(),
		"T-126 cockpit did not expose independent company and cargo context."
	)
	var travel: TravelSequenceController = cockpit.get_travel_controller()
	_check(
		cockpit.start_configured_travel() and travel != null,
		"T-126 side-order cockpit travel could not start."
	)
	if travel == null:
		return false
	travel.advance_travel(travel.departure_duration + 0.1)
	await _wait_frames(2)
	var dialogue_ui: DialogueUI = cockpit.get_dialogue_ui()
	_check(
		cockpit.is_dialogue_active()
		and cockpit.get_active_dialogue_id()
		== _contract.cockpit_travel_main_dialogue.id
		and dialogue_ui != null,
		"T-126 cruise did not start its independent required dialogue."
	)
	if dialogue_ui == null:
		return false
	_check(
		dialogue_ui.skip_dialogue_sequence()
		== DialogueRuntime.SequenceSkipResult.FINISHED
		and _game_state.has_story_flag(
			_contract.cockpit_travel_completion_flag
		),
		"T-126 required cockpit dialogue did not complete its own flag."
	)
	await _wait_frames(2)
	travel.advance_travel(travel.cruise_duration + 0.1)
	travel.advance_travel(travel.approach_duration + 0.1)
	await _wait_frames(3)
	var route: WhiteNoiseFlight = _get_active_scene() as WhiteNoiseFlight
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.FLIGHT
		and route != null
		and route.scene_file_path == _contract.flight_scene_path
		and route.is_side_order_route()
		and route.get_active_segment_index()
		== _contract.route_start_segment_index
		and is_equal_approx(
			route.get_route_start_distance(),
			_contract.route_start_distance
		)
		and route.get_route_distance()
		>= _contract.route_start_distance
		and route.get_route_distance()
		< _contract.route_start_distance + 200.0
		and route.get_remaining_route_distance() <= 17000.0
		and route.get_overall_progress() < 0.02,
		(
			"T-126 cockpit did not enter the reused 17 km route window: "
			+ "side=%s segment=%d start=%.2f route=%.2f remaining=%.2f "
			+ "progress=%.4f."
		) % [
			route.is_side_order_route() if route != null else false,
			route.get_active_segment_index() if route != null else -1,
			route.get_route_start_distance() if route != null else -1.0,
			route.get_route_distance() if route != null else -1.0,
			route.get_remaining_route_distance() if route != null else -1.0,
			route.get_overall_progress() if route != null else -1.0,
		]
	)
	if route == null:
		return false
	route.set_process(false)
	var ship: FlightLabShip = route.get_flight_ship()
	ship.set_physics_process(false)
	var visuals: WhiteNoiseRouteVisuals = route.get_route_visuals()
	_check(
		route.debug_set_route_state(
			visuals.get_landing_contact_distance() + 4.0
		),
		"T-126 could not stage the side-order landing."
	)
	ship.position.y = visuals.get_landing_pad_y() - 12.0
	ship.velocity = Vector2(42.0, 12.0)
	ship.rotation = deg_to_rad(3.0)
	route._process(0.0)
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	_check(
		route.is_route_completed()
		and run_state != null
		and run_state.order_id == _contract.order.id
		and is_equal_approx(run_state.cargo_integrity, 94.0)
		and route.is_arrival_transition_pending(),
		"T-126 landing did not retain the side-order run state."
	)
	route._process(2.0)
	await _wait_frames(3)
	var arrival: WhiteNoiseArrival = _get_active_scene() as WhiteNoiseArrival
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.ARRIVAL
		and arrival != null
		and arrival.scene_file_path == _contract.arrival_scene_path,
		"T-126 short route did not reuse the bounded White Noise arrival."
	)
	return arrival != null


func _complete_arrival_choice() -> bool:
	var arrival: WhiteNoiseArrival = _get_active_scene() as WhiteNoiseArrival
	if arrival == null:
		_check(false, "T-126 arrival scene is unavailable.")
		return false
	await _wait_frames(3)
	var dialogue_ui: DialogueUI = arrival.get_dialogue_ui()
	_check(
		dialogue_ui != null
		and arrival.get_landing_feedback_text().contains("记忆盒"),
		"T-126 did not start its side-order arrival presentation."
	)
	if dialogue_ui == null:
		return false
	_check(
		dialogue_ui.skip_dialogue_sequence()
		== DialogueRuntime.SequenceSkipResult.STOPPED_AT_CHOICE,
		"T-126 arrival did not stop at the private-return choice."
	)
	_check(
		dialogue_ui.select_choice(&"returned_memory_anonymous_index"),
		"T-126 could not choose the anonymous index."
	)
	_check(
		dialogue_ui.skip_dialogue_sequence()
		== DialogueRuntime.SequenceSkipResult.FINISHED,
		"T-126 selected dialogue did not rejoin the shared return."
	)
	await _wait_frames(3)
	_check(
		arrival.is_exploration_unlocked()
		and arrival.get_objective_text().contains("归还条款")
		and _contract.is_delivery_ready(_game_state),
		"T-126 choice did not unlock the common return path."
	)
	arrival._on_index_terminal_interacted(null)
	_check(
		arrival.get_status_text().contains("匿名容器"),
		"T-126 choice did not produce immediate authorization feedback."
	)
	arrival._on_return_lift_interacted(null)
	await _wait_frames(3)
	var results: OrderResults = _get_active_scene() as OrderResults
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.RESULTS
		and results != null,
		"T-126 return lift did not enter settlement."
	)
	return results != null


func _complete_results_and_return() -> bool:
	var results: OrderResults = _get_active_scene() as OrderResults
	if results == null:
		return false
	_check(
		results.is_settlement_committed()
		and _game_state.has_completed_order(_contract.order.id)
		and _game_state.completed_side_order_ids.has(_contract.order.id)
		and _game_state.get_planet_relation(
			M1ProgressRules.PLANET_WHITE_NOISE
		) == 1
		and _game_state.demo_ending_flags.get(
			_contract.ending_flag_id,
			&""
		) == _contract.anonymous_index_ending_value
		and results.get_station_change_text().contains("图鉴")
		and results.get_next_step_text().contains("穹林星"),
		"T-126 settlement omitted optional-choice or mainline-safety feedback."
	)
	_check(
		results.present_settlement()
		and _game_state.reward_applied_order_ids.count(
			_contract.order.id
		) == 1,
		"T-126 results re-entry duplicated the side-order reward."
	)
	_check(
		results.return_to_station(),
		"T-126 results could not return to the station."
	)
	await _wait_frames(3)
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.STATION
		and _get_active_scene() is StationHub
		and _game_state.main_story_chapter
		== M1ProgressRules.CHAPTER_M1_CANOPY_WORLD
		and _game_state.is_planet_unlocked(
			M1ProgressRules.PLANET_CANOPY_WORLD
		),
		"T-126 station return blocked or regressed the Canopy mainline."
	)
	return _get_active_scene() is StationHub


func _check_save_and_continue() -> void:
	var credits_before_save: int = _game_state.get_credits()
	_check(
		_save_service.save_progress(),
		"T-126 completed side flow could not save: %s."
		% _save_service.last_error
	)
	_game_state.reset_runtime_state()
	await _wait_frames(2)
	_check(
		not _game_state.has_completed_order(_contract.order.id),
		"T-126 save fixture did not clear runtime state before Continue."
	)
	_check(
		_save_service.load_progress(),
		"T-126 completed side flow could not Continue: %s."
		% _save_service.last_error
	)
	await _wait_frames(2)
	_check(
		_game_state.has_completed_order(_contract.order.id)
		and _game_state.get_credits() == credits_before_save
		and _game_state.main_story_chapter
		== M1ProgressRules.CHAPTER_M1_CANOPY_WORLD
		and _game_state.demo_ending_flags.get(
			_contract.ending_flag_id,
			&""
		) == _contract.anonymous_index_ending_value,
		"T-126 Continue lost the optional choice or mainline eligibility."
	)


func _get_active_scene() -> Node:
	if _app == null or _app.scene_container.get_child_count() != 1:
		return null
	return _app.scene_container.get_child(0)


func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _remove_test_files() -> void:
	for path: String in [
		TEST_SAVE_PATH,
		TEST_TEMP_PATH,
		TEST_BACKUP_PATH,
		TEST_REJECTED_PATH,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	_remove_test_files()
	if _app != null and is_instance_valid(_app):
		_app.queue_free()
		await _wait_frames(3)
	if _game_state != null:
		_game_state.reset_runtime_state()
	if _save_service != null:
		_save_service.reset_storage_paths()
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[t126-white-noise-side] PASS: voluntary acceptance, reused "
			+ "17 km route, private-return choice, settlement, station, "
			+ "save, and Continue."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t126-white-noise-side] FAIL: %s" % failure)
	quit(1)
