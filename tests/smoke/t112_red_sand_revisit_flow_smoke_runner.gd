extends SceneTree

const APP_SCENE_PATH: String = "res://scenes/app/app.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTRACT_PATH: String = (
	"res://data/revisits/red_sand_revisit_contract.tres"
)
const TEST_SAVE_PATH: String = "user://t112_red_sand_revisit.json"
const TEST_TEMP_PATH: String = "user://t112_red_sand_revisit.tmp"
const TEST_BACKUP_PATH: String = "user://t112_red_sand_revisit.backup.json"
const TEST_REJECTED_PATH: String = "user://t112_red_sand_revisit.invalid.json"
const LOCAL_CHOICE_ID: StringName = &"keep_retrofit_record_local"
const REVISIT_CODEX_ID: StringName = (
	&"codex_cargo_relay_pattern_shielding_materials"
)

var _failures: PackedStringArray = []
var _original_locale: String = ""
var _original_tree_paused: bool = false
var _original_save_isolation: bool = false
var _original_automatic_saves: bool = false
var _original_settings_isolation: bool = false
var _app: UniverseDeliverApp
var _controller: M1DebugScenarioController
var _game_state: GameStateModel
var _scene_router: SceneRouterService
var _save_service: SaveServiceModel
var _settings_service: SettingsServiceModel
var _registry: GameDataRegistry
var _contract: RedSandRevisitContract


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	_original_tree_paused = paused
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_scene_router = root.get_node_or_null("SceneRouter") as SceneRouterService
	_save_service = root.get_node_or_null("SaveService") as SaveServiceModel
	_settings_service = root.get_node_or_null(
		"SettingsService"
	) as SettingsServiceModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_contract = load(CONTRACT_PATH) as RedSandRevisitContract
	_check(_game_state != null, "T-112 smoke requires GameState.")
	_check(_scene_router != null, "T-112 smoke requires SceneRouter.")
	_check(_save_service != null, "T-112 smoke requires SaveService.")
	_check(_settings_service != null, "T-112 smoke requires SettingsService.")
	_check(_registry != null, "T-112 smoke requires the M1 registry.")
	_check(_contract != null, "T-112 smoke requires the revisit contract.")
	if (
		_game_state == null
		or _scene_router == null
		or _save_service == null
		or _settings_service == null
		or _registry == null
		or _contract == null
	):
		await _cleanup()
		_finish()
		return

	_original_save_isolation = _save_service.isolated_debug_session
	_original_automatic_saves = _save_service.automatic_saves_enabled
	_original_settings_isolation = _settings_service.isolated_debug_session
	_game_state.reset_runtime_state()
	_save_service.set_isolated_debug_session(true)
	_save_service.reset_storage_access_count()
	_settings_service.set_isolated_debug_session(true)
	_settings_service.reset_storage_write_count()
	_remove_test_files()

	var app_scene: PackedScene = load(APP_SCENE_PATH) as PackedScene
	_app = app_scene.instantiate() as UniverseDeliverApp
	_check(_app != null, "T-112 App scene could not instantiate.")
	if _app == null:
		await _cleanup()
		_finish()
		return
	root.add_child(_app)
	await _wait_frames(3)

	var express_hud: ExpressOrderHUD = _app.get_node_or_null(
		"PersistentUI/ExpressOrderHUD"
	) as ExpressOrderHUD
	var status: M1DebugStatus = _app.get_node_or_null(
		"PersistentUI/M1DebugStatus"
	) as M1DebugStatus
	_check(express_hud != null, "T-112 App is missing ExpressOrderHUD.")
	_check(status != null, "T-112 App is missing M1DebugStatus.")
	if express_hud == null or status == null:
		await _cleanup()
		_finish()
		return

	_controller = M1DebugScenarioController.new()
	_controller.configure(
		_game_state,
		_registry,
		_scene_router,
		_app.scene_container,
		_save_service,
		_settings_service,
		express_hud,
		status
	)
	_check(
		_controller.start_scenario(
			M1DebugScenarioCatalog.SCENARIO_RED_SAND_REVISIT
		),
		"T-112 revisit scenario could not start: %s." % _controller.last_error
	)
	await _wait_frames(3)

	var route: RedSandFlight = _get_active_scene() as RedSandFlight
	if await _check_short_route(route):
		await _complete_route(route)
	var arrival: RedSandArrival = _get_active_scene() as RedSandArrival
	if await _complete_revisit_arrival(arrival):
		await _complete_results_and_return()
	var station: StationHub = _get_active_scene() as StationHub
	await _check_station_save_and_continue(station)

	await _cleanup()
	_finish()


func _check_short_route(route: RedSandFlight) -> bool:
	_check(route != null, "T-112 did not instantiate the Red Sand flight scene.")
	if route == null:
		return false
	var ship: FlightLabShip = route.get_flight_ship()
	var hud: RedSandRouteHUD = route.get_route_hud()
	var course: RedSandLowFlightCourse = route.get_low_flight_course()
	var landmark: RedSandRevisitRouteLandmark = (
		route.get_revisit_route_landmark()
	)
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	_check(ship != null, "T-112 revisit ship is missing.")
	_check(hud != null, "T-112 revisit HUD is missing.")
	_check(course != null, "T-112 revisit course controller is missing.")
	_check(landmark != null, "T-112 changed-facility landmark is missing.")
	if ship == null or hud == null or course == null or landmark == null:
		return false
	route.close_controls_help()
	route.set_process(false)
	route.set_physics_process(false)
	ship.set_physics_process(false)
	_check(
		not paused
		and route.is_revisit_route()
		and is_equal_approx(
			route.get_route_distance(),
			_contract.route_entry_distance
		)
		and route.get_active_segment_index() == 5
		and ship.get_checkpoint_id() == _contract.route_entry_checkpoint_id
		and run_state != null
		and run_state.active_checkpoint_id
		== _contract.route_entry_checkpoint_id,
		"T-112 route did not start at its dedicated safe-lane checkpoint."
	)
	_check(
		ship.cargo_definition == _contract.order.cargo,
		"T-112 route did not carry the formal shielding-material cargo."
	)
	_check(
		not course.is_course_enabled()
		and not course.is_radar_active(),
		"T-112 route did not disable the repeated radar and obstacle course."
	)
	_check(
		landmark.is_landmark_enabled()
		and is_equal_approx(
			landmark.get_route_distance(),
			_contract.changed_facility_route_distance
		),
		"T-112 route did not expose its changed non-colliding facility landmark."
	)
	_check(
		hud.get_stage_text().contains("1/3")
		and hud.get_progress_text().contains("0%")
		and hud.get_instruction_text()
		== tr(_contract.get_stage_instruction_key(5)),
		"T-112 route HUD did not expose local 1/3 progress and safe-lane guidance."
	)
	for _frame_index: int in 6:
		route._physics_process(1.0 / 60.0)
		await physics_frame
	var altitude_provider: FlightAltitudeReferenceProvider = (
		route.get_altitude_reference_provider()
	)
	_check(
		route.is_surface_frame_acquired()
		and route.is_surface_frame_locked()
		and altitude_provider != null
		and altitude_provider.is_current_source_valid()
		and altitude_provider.has_numeric_altitude()
		and not route.has_altitude_invariant_violation(),
		"T-112 late route entry did not establish a valid canonical AGL reference."
	)

	ship.position += Vector2(620.0, 36.0)
	ship.velocity = Vector2(220.0, 80.0)
	ship.fuel = 4.0
	_check(
		route.restart_from_checkpoint()
		and is_equal_approx(
			route.get_route_distance(),
			_contract.route_entry_distance
		)
		and ship.get_checkpoint_id() == _contract.route_entry_checkpoint_id
		and ship.fuel >= 44.0
		and not ship.is_failed,
		"T-112 service-lane retry did not restore a viable checkpoint."
	)
	return true


func _complete_route(route: RedSandFlight) -> bool:
	var ship: FlightLabShip = route.get_flight_ship()
	var hud: RedSandRouteHUD = route.get_route_hud()
	var landing_zone: RedSandLandingZone = route.get_landing_zone()
	if ship == null or hud == null or landing_zone == null:
		_check(false, "T-112 route completion dependencies are missing.")
		return false

	ship.position.x = route.route_origin_x + 30510.0
	route.advance_route_state()
	route._process(0.0)
	_check(
		route.get_active_segment_index() == 6
		and hud.get_stage_text().contains("2/3")
		and not route.get_low_flight_course().is_radar_active(),
		"T-112 preparation corridor did not become local stage 2/3 without radar."
	)

	ship.position.x = route.route_origin_x + 33010.0
	route.advance_route_state()
	route._process(0.0)
	_check(
		route.get_active_segment_index() == 7
		and hud.get_stage_text().contains("3/3")
		and ship.get_checkpoint_id()
		== route.get_active_segment().checkpoint_id,
		"T-112 final approach did not become local stage 3/3 with its safe checkpoint."
	)
	ship.position += Vector2(280.0, 44.0)
	ship.velocity = Vector2(240.0, 75.0)
	_check(
		route.restart_from_checkpoint()
		and ship.global_position == landing_zone.get_safe_checkpoint_position()
		and ship.velocity == landing_zone.get_safe_checkpoint_velocity(),
		"T-112 final-approach retry restored too close to the platform or with unsafe motion."
	)

	_touch_down(route, landing_zone, Vector2(80.0, 20.0), 0.0)
	_check(
		route.is_route_completed()
		and route.get_landing_result()
		== OrderRunState.LANDING_RESULT_SMOOTH,
		"T-112 safe short route did not complete a smooth landing."
	)
	var transition_delay: float = (
		ship.tuning.landing_arrival_transition_delay_seconds
		if ship.tuning != null
		else 0.0
	)
	route._process(transition_delay + 0.1)
	await _wait_frames(3)
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.ARRIVAL
		and _get_active_scene() is RedSandArrival,
		"T-112 landing did not enter the revisit arrival."
	)
	return _scene_router.current_stage == SceneRouterService.Stage.ARRIVAL


func _complete_revisit_arrival(arrival: RedSandArrival) -> bool:
	_check(arrival != null, "T-112 revisit arrival did not instantiate.")
	if arrival == null:
		return false
	await _wait_frames(3)
	var dialogue_ui: DialogueUI = arrival.get_dialogue_ui()
	_check(
		arrival.is_revisit()
		and arrival.is_main_dialogue_active()
		and dialogue_ui != null
		and arrival.get_interactables().size() == 4
		and arrival.get_cooling_equipment() != null
		and arrival.get_cooling_equipment().visible,
		"T-112 arrival did not expose the changed repair yard and revisit dialogue."
	)
	if dialogue_ui == null:
		return false
	_check(
		dialogue_ui.skip_dialogue_sequence()
		== DialogueRuntime.SequenceSkipResult.STOPPED_AT_CHOICE,
		"T-112 dialogue could not reach the local record choice."
	)
	_check(
		dialogue_ui.select_choice(LOCAL_CHOICE_ID),
		"T-112 local-record choice could not be selected."
	)
	_check(
		dialogue_ui.skip_dialogue_sequence()
		== DialogueRuntime.SequenceSkipResult.FINISHED,
		"T-112 dialogue could not finish after the local-record choice."
	)
	await _wait_frames(2)
	_check(
		_contract.is_delivery_ready(_game_state)
		and _game_state.has_story_flag(_contract.keep_local_record_flag)
		and not _game_state.has_story_flag(_contract.upload_full_record_flag)
		and arrival.is_exploration_unlocked(),
		"T-112 dialogue did not retain exactly one choice and delivery completion."
	)

	var player: StationPlayer = arrival.get_station_player()
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	_check(
		arrival.get_cooling_equipment().interact(player),
		"T-112 cooling equipment did not respond."
	)
	await process_frame
	_check(
		arrival.get_status_text().contains(
			tr("UI_M1_RED_SAND_REVISIT_COOLING_DETAIL")
		)
		and run_state != null
		and run_state.optional_trigger_ids.has(
			RedSandArrival.REVISIT_COOLING_INSPECTION_TRIGGER_ID
		),
		"T-112 cooling equipment did not expose its visible world change."
	)
	arrival.dismiss_status()
	_check(
		arrival.get_record_terminal().interact(player),
		"T-112 record terminal did not respond."
	)
	await process_frame
	_check(
		arrival.get_status_text().contains(
			tr("UI_M1_RED_SAND_REVISIT_RECORD_LOCAL")
		),
		"T-112 record terminal did not reflect the selected local branch."
	)
	arrival.dismiss_status()
	_check(
		arrival.get_return_beacon().interact(player),
		"T-112 completed revisit could not return for settlement."
	)
	await _wait_frames(3)
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.RESULTS
		and _get_active_scene() is OrderResults,
		"T-112 revisit arrival did not enter Results."
	)
	return _scene_router.current_stage == SceneRouterService.Stage.RESULTS


func _complete_results_and_return() -> bool:
	var results: OrderResults = _get_active_scene() as OrderResults
	_check(results != null, "T-112 Results scene did not instantiate.")
	if results == null:
		return false
	await _wait_frames(2)
	var shielding: ShipModuleDefinition = _registry.find_module(
		_contract.auto_equip_module_id
	)
	var codex_entry: CodexCatalogEntry = _find_codex_entry(REVISIT_CODEX_ID)
	_check(
		results.is_settlement_committed()
		and _game_state.has_completed_order(_contract.order.id)
		and _game_state.has_applied_order_reward(_contract.order.id)
		and _game_state.get_planet_relation(M1ProgressRules.PLANET_RED_SAND) == 3
		and shielding != null
		and _game_state.has_ship_module(shielding.id)
		and _game_state.is_ship_module_equipped(shielding.id)
		and _game_state.has_station_state(StationStateRules.ARCHIVE_TERMINAL_ID)
		and _game_state.get_revisit_state(M1ProgressRules.PLANET_RED_SAND)
		== _contract.completed_state_id
		and _game_state.main_story_chapter
		== M1ProgressRules.CHAPTER_M1_WHITE_NOISE
		and _game_state.is_planet_unlocked(
			M1ProgressRules.PLANET_WHITE_NOISE
		)
		and codex_entry != null
		and codex_entry.description_key
		== CodexCatalogModel.RED_SAND_LOCAL_DESCRIPTION_KEY,
		"T-112 Results did not atomically apply choice, relation, module, archive, revisit, chapter, White Noise navigation, and codex rewards."
	)
	_check(
		results.get_station_change_text().contains("档案")
		and results.get_next_step_text().contains("白噪"),
		"T-112 Results did not explain the station change and next chapter."
	)
	_check(
		_save_service.get_storage_access_count() == 0
		and _settings_service.get_storage_write_count() == 0,
		"T-112 debug route crossed its isolated storage boundary."
	)
	_check(results.return_to_station(), "T-112 Results could not return to Station.")
	await _wait_frames(4)
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.STATION
		and _get_active_scene() is StationHub,
		"T-112 Results did not return to Station."
	)
	return _scene_router.current_stage == SceneRouterService.Stage.STATION


func _check_station_save_and_continue(station: StationHub) -> void:
	_check(station != null, "T-112 returned Station did not instantiate.")
	if station == null:
		return
	var presenter: StationStatePresenter = station.get_station_state_presenter()
	var archive_root: Node2D = (
		presenter.get_state_root(StationStateRules.ARCHIVE_TERMINAL_ID)
		if presenter != null
		else null
	)
	_check(
		presenter != null
		and presenter.is_state_root_visible(
			StationStateRules.ARCHIVE_TERMINAL_ID
		)
		and archive_root != null
		and archive_root.get_node_or_null("Cabinet") != null
		and archive_root.get_node_or_null("Screen") != null,
		"T-112 returned Station did not show the minimum archive-terminal growth."
	)

	_controller.stop_scenario()
	_save_service.set_isolated_debug_session(false)
	_save_service.set_automatic_saves_enabled(false)
	_save_service.configure_storage_paths(
		TEST_SAVE_PATH,
		TEST_TEMP_PATH,
		TEST_BACKUP_PATH,
		TEST_REJECTED_PATH
	)
	_remove_test_files()
	_check(
		_save_service.save_progress(),
		"T-112 completed revisit could not save: %s." % _save_service.last_error
	)
	_game_state.reset_runtime_state()
	await process_frame
	_check(
		not _game_state.has_completed_order(_contract.order.id)
		and presenter != null
		and not presenter.is_state_root_visible(
			StationStateRules.ARCHIVE_TERMINAL_ID
		),
		"T-112 restart fixture did not clear runtime progress and station visuals."
	)
	_check(
		_save_service.load_progress(),
		"T-112 completed revisit could not continue: %s." % _save_service.last_error
	)
	await _wait_frames(2)
	_check(
		_game_state.has_completed_order(_contract.order.id)
		and _game_state.is_ship_module_equipped(
			_contract.auto_equip_module_id
		)
		and _game_state.has_story_flag(_contract.keep_local_record_flag)
		and not _game_state.has_story_flag(_contract.upload_full_record_flag)
		and _game_state.get_revisit_state(M1ProgressRules.PLANET_RED_SAND)
		== _contract.completed_state_id
		and presenter != null
		and presenter.is_state_root_visible(
			StationStateRules.ARCHIVE_TERMINAL_ID
		),
		"T-112 Continue did not restore the exact branch, module, revisit, and station state."
	)


func _touch_down(
	route: RedSandFlight,
	landing_zone: RedSandLandingZone,
	velocity: Vector2,
	pitch_radians: float
) -> void:
	var ship: FlightLabShip = route.get_flight_ship()
	ship.global_position = landing_zone.global_position + Vector2(
		0.0,
		landing_zone.get_touchdown_center_y() - 2.0
	)
	ship.velocity = velocity
	ship.rotation = pitch_radians
	route._physics_process(1.0 / 60.0)
	ship.global_position.y = (
		landing_zone.global_position.y
		+ landing_zone.get_touchdown_center_y()
		+ 1.0
	)
	route._physics_process(1.0 / 60.0)


func _find_codex_entry(entry_id: StringName) -> CodexCatalogEntry:
	for entry: CodexCatalogEntry in CodexCatalogModel.build_catalog(
		_registry,
		_game_state
	):
		if entry.id == entry_id:
			return entry
	return null


func _get_active_scene() -> Node:
	if _app == null or not is_instance_valid(_app):
		return null
	if _app.scene_container.get_child_count() != 1:
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


func _cleanup() -> void:
	if _controller != null:
		_controller.stop_scenario()
	if _app != null and is_instance_valid(_app):
		_app.queue_free()
		await _wait_frames(2)
	if _game_state != null:
		_game_state.reset_runtime_state()
	_remove_test_files()
	if _save_service != null:
		_save_service.reset_storage_paths()
		_save_service.set_isolated_debug_session(_original_save_isolation)
		_save_service.set_automatic_saves_enabled(_original_automatic_saves)
	if _settings_service != null:
		_settings_service.set_isolated_debug_session(
			_original_settings_isolation
		)
	paused = _original_tree_paused
	TranslationServer.set_locale(_original_locale)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"[t112-red-sand-revisit-flow] PASS: short safe route, changed "
			+ "facility, checkpoint retry, Iya/Lao Pi choice, atomic rewards, "
			+ "station growth, save, restart, and Continue."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t112-red-sand-revisit-flow] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
