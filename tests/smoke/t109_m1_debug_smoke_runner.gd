extends SceneTree

const APP_SCENE_PATH: String = "res://scenes/app/app.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

var _failures: PackedStringArray = []
var _original_locale: String = ""
var _app: UniverseDeliverApp
var _controller: M1DebugScenarioController
var _game_state: GameStateModel
var _scene_router: SceneRouterService
var _save_service: SaveServiceModel
var _settings_service: SettingsServiceModel
var _registry: GameDataRegistry


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_scene_router = root.get_node_or_null("SceneRouter") as SceneRouterService
	_save_service = root.get_node_or_null("SaveService") as SaveServiceModel
	_settings_service = root.get_node_or_null(
		"SettingsService"
	) as SettingsServiceModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_check(_game_state != null, "T-109 smoke requires GameState.")
	_check(_scene_router != null, "T-109 smoke requires SceneRouter.")
	_check(_save_service != null, "T-109 smoke requires SaveService.")
	_check(_settings_service != null, "T-109 smoke requires SettingsService.")
	_check(_registry != null, "T-109 smoke requires the M1 registry.")
	if (
		_game_state == null
		or _scene_router == null
		or _save_service == null
		or _settings_service == null
		or _registry == null
	):
		_finish()
		return

	_game_state.reset_runtime_state()
	_save_service.set_isolated_debug_session(true)
	_save_service.reset_storage_access_count()
	_settings_service.set_isolated_debug_session(true)
	_settings_service.reset_storage_write_count()

	var app_scene: PackedScene = load(APP_SCENE_PATH) as PackedScene
	_app = app_scene.instantiate() as UniverseDeliverApp
	_check(_app != null, "T-109 App scene could not instantiate.")
	if _app == null:
		_finish()
		return
	root.add_child(_app)
	await process_frame
	await process_frame

	var express_hud: ExpressOrderHUD = _app.get_node_or_null(
		"PersistentUI/ExpressOrderHUD"
	) as ExpressOrderHUD
	var status: M1DebugStatus = _app.get_node_or_null(
		"PersistentUI/M1DebugStatus"
	) as M1DebugStatus
	_check(express_hud != null, "T-109 App is missing ExpressOrderHUD.")
	_check(status != null, "T-109 App is missing the compact debug status.")
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
	for scenario_id: StringName in M1DebugScenarioCatalog.get_scenario_ids():
		await _exercise_scenario(scenario_id, status, express_hud)

	_check(
		_save_service.get_storage_access_count() == 0,
		"M1 scenarios accessed normal progress storage."
	)
	_check(
		_settings_service.get_storage_write_count() == 0,
		"M1 scenarios wrote player settings."
	)
	_check(
		_registry.find_order(
			M1DebugScenarioCatalog.ORDER_TIDAL_EXPRESS
		).content_readiness
		== OrderDefinition.ContentReadiness.REGISTERED_ONLY
		and _registry.find_planet(
			M1ProgressRules.PLANET_TIDAL_ARCHIPELAGO
		).content_readiness
		== PlanetDefinition.ContentReadiness.REGISTERED_ONLY,
		"The isolated express fixture mutated formal registered content."
	)

	await _cleanup()
	_finish()


func _exercise_scenario(
	scenario_id: StringName,
	status: M1DebugStatus,
	express_hud: ExpressOrderHUD
) -> void:
	var started: bool = _controller.start_scenario(scenario_id)
	_check(
		started,
		"Scenario %s failed to start: %s." % [
			scenario_id,
			_controller.last_error,
		]
	)
	if not started:
		return
	var initial_signature: String = (
		_controller.get_initial_state_signature()
	)
	var first_definition: M1DebugScenarioDefinition = (
		_controller.get_definition()
	)
	await process_frame
	await process_frame

	_check(
		first_definition != null
		and _scene_router.current_stage == first_definition.target_stage,
		"Scenario %s opened the wrong Stage." % scenario_id
	)
	_check(
		status.visible
		and status.get_scenario_text().contains(String(scenario_id))
		and status.get_context_text().contains(
			String(first_definition.chapter_id)
		)
		and status.get_context_text().contains(
			String(first_definition.focus_planet_id)
		)
		and status.get_isolation_text().contains("自动存档已关闭")
		and VIEWPORT_RECT.encloses(status.get_global_rect()),
		"Scenario %s status is missing context, isolation, or 640x360 bounds."
		% scenario_id
	)
	_check_target_scene(scenario_id, first_definition, express_hud)
	_check(
		_save_service.get_storage_access_count() == 0
		and _settings_service.get_storage_write_count() == 0,
		"Scenario %s crossed its storage isolation boundary." % scenario_id
	)

	_game_state.credits += 91
	_game_state.set_planet_relation(first_definition.focus_planet_id, -2)
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	if run_state != null:
		run_state.elapsed_time = 84.0
	_check(
		_controller.reset_scenario(),
		"Scenario %s failed to reset: %s." % [
			scenario_id,
			_controller.last_error,
		]
	)
	_check(
		_runtime_signature() == initial_signature,
		"Scenario %s reset did not restore its exact initial snapshot."
		% scenario_id
	)
	_check(
		_controller.start_scenario(scenario_id)
		and _controller.get_initial_state_signature() == initial_signature,
		"Repeated application of scenario %s was not deterministic."
		% scenario_id
	)


func _check_target_scene(
	scenario_id: StringName,
	definition: M1DebugScenarioDefinition,
	express_hud: ExpressOrderHUD
) -> void:
	var active_scene: Node = (
		_app.scene_container.get_child(0)
		if _app.scene_container.get_child_count() == 1
		else null
	)
	_check(active_scene != null, "Scenario %s has no one active scene." % scenario_id)
	if active_scene == null:
		return
	if definition.preview_only:
		_check(
			active_scene is M1DebugCatalogView,
			"Preview scenario %s did not open the catalog view." % scenario_id
		)
		var catalog_view: M1DebugCatalogView = (
			active_scene as M1DebugCatalogView
		)
		if catalog_view != null:
			var terminal: OrderTerminalUI = catalog_view.get_order_terminal()
			_check(
				terminal != null
				and terminal.visible
				and terminal.get_selected_order_id()
				== definition.catalog_focus_order_id
				and not terminal.is_accept_enabled(),
				"Preview scenario %s did not focus a locked registered order."
				% scenario_id
			)
	elif scenario_id == M1DebugScenarioCatalog.SCENARIO_LOW_ALTITUDE_DROP:
		_check(
			active_scene is DeliveryLab
			and _game_state.current_order_id.is_empty(),
			"Low-altitude scenario must open Delivery Lab without accepting formal content."
		)
	elif scenario_id == M1DebugScenarioCatalog.SCENARIO_EXPRESS_ORDER:
		var fixture: OrderDefinition = _controller.get_express_fixture()
		_check(
			active_scene is FlightLab
			and fixture != null
			and fixture.id == M1DebugScenarioCatalog.DEBUG_EXPRESS_ORDER_ID
			and _game_state.current_order_id == fixture.id
			and express_hud.has_active_express_order()
			and express_hud.is_timing_visible(),
			"Express scenario did not open Flight Lab with one isolated timed fixture."
		)
	elif scenario_id == M1DebugScenarioCatalog.SCENARIO_RED_SAND_REVISIT:
		var revisit_route: RedSandFlight = active_scene as RedSandFlight
		_check(
			revisit_route != null
			and revisit_route.is_revisit_route()
			and _game_state.current_order_id
			== M1DebugScenarioCatalog.ORDER_RED_SAND_REVISIT
			and _game_state.get_order_status(
				M1DebugScenarioCatalog.ORDER_RED_SAND_REVISIT
			) == GameStateModel.OrderStatus.ACCEPTED
			and _game_state.get_revisit_state(
				M1ProgressRules.PLANET_RED_SAND
			) == M1ProgressRules.REVISIT_RED_SAND_MATERIALS_PENDING,
			"Red Sand revisit scenario did not open its formal accepted short route."
		)


func _runtime_signature() -> String:
	var progress: GameProgressData = GameProgressData.capture(_game_state)
	if not progress.is_valid():
		return "INVALID:%s" % progress.validation_error
	progress.last_saved_at_unix = 0
	progress.build_version = M1DebugScenarioController.DEBUG_BUILD_VERSION
	return JSON.stringify(progress.to_dictionary())


func _cleanup() -> void:
	if _controller != null:
		_controller.stop_scenario()
	if _app != null and is_instance_valid(_app):
		_app.queue_free()
		await process_frame
	_game_state.reset_runtime_state()
	_save_service.set_isolated_debug_session(false)
	_settings_service.set_isolated_debug_session(false)
	TranslationServer.set_locale(_original_locale)


func _finish() -> void:
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[t109-m1-debug] PASS: six deterministic scenarios, exact reset, "
			+ "catalog/lab targets, compact status, save isolation, and "
			+ "registered-only guards."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t109-m1-debug] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
