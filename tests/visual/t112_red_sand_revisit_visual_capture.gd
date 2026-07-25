extends SceneTree

const APP_SCENE_PATH: String = "res://scenes/app/app.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CAPTURE_DIRECTORY: String = "res://.omx/artifacts/t112_red_sand_revisit"
const LOCAL_CHOICE_ID: StringName = &"keep_retrofit_record_local"

var _app: UniverseDeliverApp
var _controller: M1DebugScenarioController
var _game_state: GameStateModel
var _scene_router: SceneRouterService
var _save_service: SaveServiceModel
var _settings_service: SettingsServiceModel
var _original_locale: String = ""
var _original_save_isolation: bool = false
var _original_settings_isolation: bool = false


func _initialize() -> void:
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_scene_router = root.get_node_or_null("SceneRouter") as SceneRouterService
	_save_service = root.get_node_or_null("SaveService") as SaveServiceModel
	_settings_service = root.get_node_or_null(
		"SettingsService"
	) as SettingsServiceModel
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	if (
		_game_state == null
		or _scene_router == null
		or _save_service == null
		or _settings_service == null
		or registry == null
	):
		printerr("[t112-visual] Runtime dependencies are unavailable.")
		await _cleanup()
		quit(1)
		return
	_original_save_isolation = _save_service.isolated_debug_session
	_original_settings_isolation = _settings_service.isolated_debug_session
	_game_state.reset_runtime_state()
	_save_service.set_isolated_debug_session(true)
	_settings_service.set_isolated_debug_session(true)

	var app_scene: PackedScene = load(APP_SCENE_PATH) as PackedScene
	_app = app_scene.instantiate() as UniverseDeliverApp
	if _app == null:
		printerr("[t112-visual] App scene could not instantiate.")
		await _cleanup()
		quit(1)
		return
	root.add_child(_app)
	await _settle_frames(3)
	var express_hud: ExpressOrderHUD = _app.get_node_or_null(
		"PersistentUI/ExpressOrderHUD"
	) as ExpressOrderHUD
	var status: M1DebugStatus = _app.get_node_or_null(
		"PersistentUI/M1DebugStatus"
	) as M1DebugStatus
	if express_hud == null or status == null:
		printerr("[t112-visual] Persistent debug UI is unavailable.")
		await _cleanup()
		quit(1)
		return
	_controller = M1DebugScenarioController.new()
	_controller.configure(
		_game_state,
		registry,
		_scene_router,
		_app.scene_container,
		_save_service,
		_settings_service,
		express_hud,
		status
	)
	if not _controller.start_scenario(
		M1DebugScenarioCatalog.SCENARIO_RED_SAND_REVISIT
	):
		printerr(
			"[t112-visual] Revisit scenario could not start: %s."
			% _controller.last_error
		)
		await _cleanup()
		quit(1)
		return
	await _settle_frames(3)
	var route: RedSandFlight = _get_active_scene() as RedSandFlight
	if route == null:
		printerr("[t112-visual] Revisit route did not instantiate.")
		await _cleanup()
		quit(1)
		return
	route.close_controls_help()
	_controller.stop_scenario()
	var ship: FlightLabShip = route.get_flight_ship()
	ship.position.x = route.route_origin_x + 28600.0
	ship.position.y = 212.0 + route.get_surface_frame_offset_y()
	ship.velocity = Vector2.ZERO
	route.advance_route_state()
	route._process(0.0)
	await _settle_frames(3)
	if not _save_frame("revisit_service_lane.png"):
		await _cleanup()
		quit(1)
		return

	if not _scene_router.debug_switch_to_stage(
		SceneRouterService.Stage.ARRIVAL
	):
		printerr("[t112-visual] Could not enter revisit arrival.")
		await _cleanup()
		quit(1)
		return
	await _settle_frames(4)
	var arrival: RedSandArrival = _get_active_scene() as RedSandArrival
	var dialogue_ui: DialogueUI = (
		arrival.get_dialogue_ui() if arrival != null else null
	)
	if arrival == null or dialogue_ui == null or not arrival.is_revisit():
		printerr("[t112-visual] Revisit arrival or dialogue is unavailable.")
		await _cleanup()
		quit(1)
		return
	if (
		dialogue_ui.skip_dialogue_sequence()
		!= DialogueRuntime.SequenceSkipResult.STOPPED_AT_CHOICE
	):
		printerr("[t112-visual] Revisit record choice was not reachable.")
		await _cleanup()
		quit(1)
		return
	await _settle_frames(2)
	if not _save_frame("revisit_record_choice.png"):
		await _cleanup()
		quit(1)
		return
	if (
		not dialogue_ui.select_choice(LOCAL_CHOICE_ID)
		or dialogue_ui.skip_dialogue_sequence()
		!= DialogueRuntime.SequenceSkipResult.FINISHED
	):
		printerr("[t112-visual] Revisit dialogue could not complete.")
		await _cleanup()
		quit(1)
		return
	await _settle_frames(2)
	var player: StationPlayer = arrival.get_station_player()
	player.global_position = Vector2(720.0, 292.0)
	await physics_frame
	await physics_frame
	await _settle_frames(2)
	if not _save_frame("revisit_repair_yard.png"):
		await _cleanup()
		quit(1)
		return

	await _cleanup()
	print(
		"[t112-visual] PASS: saved service lane, record choice, and "
		+ "changed repair-yard frames."
	)
	quit(0)


func _get_active_scene() -> Node:
	if _app == null or not is_instance_valid(_app):
		return null
	if _app.scene_container.get_child_count() != 1:
		return null
	return _app.scene_container.get_child(0)


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _save_frame(file_name: String) -> bool:
	var absolute_directory: String = ProjectSettings.globalize_path(
		CAPTURE_DIRECTORY
	)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		printerr("[t112-visual] Could not create capture directory.")
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("[t112-visual] Viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	if image.save_png(output_path) != OK:
		printerr("[t112-visual] Could not save %s." % output_path)
		return false
	print("[t112-visual] Saved %s" % output_path)
	return true


func _cleanup() -> void:
	if _controller != null:
		_controller.stop_scenario()
	if _app != null and is_instance_valid(_app):
		_app.queue_free()
		await _settle_frames(2)
	if _game_state != null:
		_game_state.reset_runtime_state()
	if _save_service != null:
		_save_service.set_isolated_debug_session(_original_save_isolation)
	if _settings_service != null:
		_settings_service.set_isolated_debug_session(
			_original_settings_isolation
		)
	paused = false
	TranslationServer.set_locale(_original_locale)
