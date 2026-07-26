extends SceneTree

const APP_SCENE_PATH: String = "res://scenes/app/app.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTRACT_PATH: String = (
	"res://data/settlements/white_noise_settlement_contract.tres"
)
const TEST_SAVE_PATH: String = "user://t125_white_noise_main_flow.json"
const TEST_TEMP_PATH: String = "user://t125_white_noise_main_flow.tmp"
const TEST_BACKUP_PATH: String = (
	"user://t125_white_noise_main_flow.backup.json"
)
const TEST_REJECTED_PATH: String = (
	"user://t125_white_noise_main_flow.invalid.json"
)

var _failures: PackedStringArray = []
var _original_locale: String = ""
var _game_state: GameStateModel
var _scene_router: SceneRouterService
var _save_service: SaveServiceModel
var _registry: GameDataRegistry
var _contract: WhiteNoiseSettlementContract
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
	_contract = load(CONTRACT_PATH) as WhiteNoiseSettlementContract
	_check(_game_state != null, "T-125 smoke requires GameState.")
	_check(_scene_router != null, "T-125 smoke requires SceneRouter.")
	_check(_save_service != null, "T-125 smoke requires SaveService.")
	_check(_registry != null, "T-125 smoke requires the M1 registry.")
	_check(_contract != null, "T-125 smoke requires the settlement contract.")
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
	if not _prepare_formal_prerequisites():
		await _finish()
		return
	var packed_app: PackedScene = load(APP_SCENE_PATH) as PackedScene
	_app = packed_app.instantiate() as UniverseDeliverApp
	_check(_app != null, "T-125 App scene did not instantiate.")
	if _app == null:
		await _finish()
		return
	root.add_child(_app)
	await _wait_frames(3)
	if not await _accept_and_configure_from_station():
		await _finish()
		return
	if not await _complete_cockpit_and_route():
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


func _prepare_formal_prerequisites() -> bool:
	_game_state.reset_runtime_state()
	_game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	_game_state.unlocked_planet_ids = [
		M1ProgressRules.PLANET_RED_SAND,
		M1ProgressRules.PLANET_WHITE_NOISE,
	]
	for completed_order_id: StringName in [
		M1CatalogModel.M0_ORDER_ID,
		M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT,
	]:
		_game_state.completed_order_ids[completed_order_id] = true
		_game_state.order_states[
			completed_order_id
		] = GameStateModel.OrderStatus.COMPLETED
		_game_state.reward_applied_order_ids.append(completed_order_id)
	_game_state.story_flags[
		M1ProgressRules.STORY_RED_SAND_SHIELDING_RETROFIT_COMPLETED
	] = true
	_game_state.story_flags[
		&"story_m1_white_noise_cockpit_travel_completed"
	] = true
	_game_state.story_flags[
		StationTutorialController.COMPLETION_FLAG
	] = true
	_game_state.story_flags[
		M0ProgressIds.STORY_RETURN_DIALOGUE_COMPLETED
	] = true
	_game_state.unlock_station_state(
		StationStateRules.ARCHIVE_TERMINAL_ID
	)
	var shielding: ShipModuleDefinition = _registry.find_module(
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
	)
	if shielding == null:
		_check(false, "T-125 formal shielding module is missing.")
		return false
	_game_state.ship_upgrade_ids.append(shielding.id)
	var prepared: bool = (
		_game_state.equip_ship_module(shielding)
		and _game_state.can_accept_order(_contract.order)
	)
	_check(
		prepared,
		"T-125 formal White Noise prerequisites could not expose the order."
	)
	return prepared


func _accept_and_configure_from_station() -> bool:
	_check(
		_scene_router.debug_switch_to_stage(
			SceneRouterService.Stage.STATION
		),
		"T-125 could not open the qualified station."
	)
	await _wait_frames(4)
	var station: StationHub = _get_active_scene() as StationHub
	_check(station != null, "T-125 station did not instantiate.")
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
		"T-125 station order terminal could not open."
	)
	await _wait_frames(3)
	_check(
		terminal != null
		and terminal.get_selected_order_id() == _contract.order.id
		and terminal.is_accept_enabled()
		and terminal.accept_current_order()
		and _game_state.current_order_id == _contract.order.id,
		"T-125 formal White Noise order could not be accepted through the terminal."
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
		"T-125 ship configuration could not open."
	)
	await _wait_frames(3)
	_check(
		loadout != null
		and loadout.get_order_definition_id() == _contract.order.id
		and loadout.is_confirm_enabled()
		and loadout.confirm_departure()
		and _game_state.is_departure_confirmed_for_order(_contract.order),
		"T-125 formal loadout could not confirm departure."
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
		"T-125 confirmed station flow could not enter the cockpit."
	)
	await _wait_frames(4)
	return (
		_scene_router.current_stage == SceneRouterService.Stage.COCKPIT
		and _get_active_scene() is Cockpit
	)


func _complete_cockpit_and_route() -> bool:
	var cockpit: Cockpit = _get_active_scene() as Cockpit
	_check(cockpit != null, "T-125 cockpit did not instantiate.")
	if cockpit == null:
		return false
	var travel: TravelSequenceController = cockpit.get_travel_controller()
	_check(
		cockpit.start_configured_travel() and travel != null,
		"T-125 formal cockpit travel could not start."
	)
	if travel == null:
		return false
	travel.advance_travel(20.0)
	await _wait_frames(3)
	var route: WhiteNoiseFlight = _get_active_scene() as WhiteNoiseFlight
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.FLIGHT
		and route != null
		and route.scene_file_path == _contract.flight_scene_path,
		"T-125 cockpit did not route to the dedicated White Noise scene."
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
		"T-125 could not stage the final White Noise landing."
	)
	ship.position.y = visuals.get_landing_pad_y() - 12.0
	ship.velocity = Vector2(42.0, 12.0)
	ship.rotation = deg_to_rad(3.0)
	route._process(0.0)
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	_check(
		route.is_route_completed()
		and route.get_landing_result()
		== OrderRunState.LANDING_RESULT_ROUGH
		and run_state != null
		and run_state.landing_result
		== OrderRunState.LANDING_RESULT_ROUGH
		and is_equal_approx(run_state.cargo_integrity, 94.0)
		and route.is_arrival_transition_pending(),
		"T-125 landing did not retain result and resources for settlement."
	)
	route._process(2.0)
	await _wait_frames(3)
	var arrival: WhiteNoiseArrival = _get_active_scene() as WhiteNoiseArrival
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.ARRIVAL
		and arrival != null
		and arrival.scene_file_path == _contract.arrival_scene_path,
		"T-125 route did not enter the dedicated White Noise arrival."
	)
	return arrival != null


func _complete_arrival_choice() -> bool:
	var arrival: WhiteNoiseArrival = _get_active_scene() as WhiteNoiseArrival
	if arrival == null:
		_check(false, "T-125 arrival scene is unavailable.")
		return false
	await _wait_frames(3)
	var dialogue_ui: DialogueUI = arrival.get_dialogue_ui()
	_check(dialogue_ui != null, "T-125 arrival dialogue UI is missing.")
	if dialogue_ui == null:
		return false
	_check(
		dialogue_ui.skip_dialogue_sequence()
		== DialogueRuntime.SequenceSkipResult.STOPPED_AT_CHOICE,
		"T-125 arrival did not stop at the mandatory local choice."
	)
	_check(
		dialogue_ui.select_choice(&"local_shared_custody"),
		"T-125 could not choose local shared custody."
	)
	_check(
		dialogue_ui.skip_dialogue_sequence()
		== DialogueRuntime.SequenceSkipResult.FINISHED,
		"T-125 selected dialogue did not rejoin the shared return."
	)
	await _wait_frames(3)
	_check(
		arrival.is_exploration_unlocked()
		and _contract.is_delivery_ready(_game_state),
		"T-125 choice did not unlock the common return path."
	)
	arrival._on_return_lift_interacted(null)
	await _wait_frames(3)
	var results: OrderResults = _get_active_scene() as OrderResults
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.RESULTS
		and results != null,
		"T-125 return lift did not enter settlement."
	)
	return results != null


func _complete_results_and_return() -> bool:
	var results: OrderResults = _get_active_scene() as OrderResults
	if results == null:
		return false
	_check(
		results.is_settlement_committed()
		and _game_state.has_completed_order(_contract.order.id)
		and _game_state.is_planet_unlocked(
			M1ProgressRules.PLANET_CANOPY_WORLD
		)
		and _game_state.planet_permission_ids.has(
			M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
		)
		and _game_state.has_codex_entry(
			_contract.local_custody_codex.id
		)
		and _game_state.has_souvenir(
			&"souvenir_white_noise_frost_index"
		)
		and _game_state.demo_ending_flags.get(
			_contract.ending_flag_id,
			&""
		) == _contract.local_custody_ending_value
		and results.get_station_change_text().contains("白噪索引")
		and results.get_next_step_text().contains("穹林星"),
		"T-125 results omitted choice, growth, or next-mainline feedback."
	)
	_check(
		results.present_settlement()
		and _game_state.reward_applied_order_ids.count(
			_contract.order.id
		) == 1,
		"T-125 results re-entry duplicated the reward ledger."
	)
	_check(
		results.return_to_station(),
		"T-125 results could not return to the station."
	)
	await _wait_frames(3)
	var station: StationHub = _get_active_scene() as StationHub
	var presenter: StationStatePresenter = (
		station.get_station_state_presenter()
		if station != null
		else null
	)
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.STATION
		and station != null
		and presenter != null
		and presenter.is_archive_terminal_white_noise_synced()
		and presenter.get_archive_terminal_label_text().contains(
			"白噪索引已同步"
		),
		"T-125 station did not expose the updated archive terminal."
	)
	return station != null and presenter != null


func _check_save_and_continue() -> void:
	var credits_before_save: int = _game_state.get_credits()
	_check(
		_save_service.save_progress(),
		"T-125 completed flow could not save: %s." % _save_service.last_error
	)
	_game_state.reset_runtime_state()
	await _wait_frames(2)
	_check(
		not _game_state.has_completed_order(_contract.order.id),
		"T-125 save fixture did not clear runtime state before Continue."
	)
	_check(
		_save_service.load_progress(),
		"T-125 completed flow could not Continue: %s."
		% _save_service.last_error
	)
	await _wait_frames(2)
	var station: StationHub = _get_active_scene() as StationHub
	var presenter: StationStatePresenter = (
		station.get_station_state_presenter()
		if station != null
		else null
	)
	_check(
		_game_state.has_completed_order(_contract.order.id)
		and _game_state.get_credits() == credits_before_save
		and _game_state.is_planet_unlocked(
			M1ProgressRules.PLANET_CANOPY_WORLD
		)
		and _game_state.revisit_state.get(
			M1ProgressRules.PLANET_WHITE_NOISE,
			&""
		) == _contract.revisit_state_id
		and _game_state.demo_ending_flags.get(
			_contract.ending_flag_id,
			&""
		) == _contract.local_custody_ending_value
		and presenter != null
		and presenter.is_archive_terminal_white_noise_synced(),
		"T-125 Continue lost progression or duplicated the settled reward."
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
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute_path)


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
			"[t125-white-noise-flow] PASS: formal cockpit route, landing, "
			+ "archive choice, atomic settlement, station growth, save, and Continue."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t125-white-noise-flow] FAIL: %s" % failure)
	quit(1)
