extends SceneTree

const APP_SCENE_PATH: String = "res://scenes/app/app.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTRACT_PATH: String = (
	"res://data/revisits/red_sand_revisit_contract.tres"
)

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
	var contract: RedSandRevisitContract = load(
		CONTRACT_PATH
	) as RedSandRevisitContract
	_check(_game_state != null, "T-110 smoke requires GameState.")
	_check(_scene_router != null, "T-110 smoke requires SceneRouter.")
	_check(_save_service != null, "T-110 smoke requires SaveService.")
	_check(_settings_service != null, "T-110 smoke requires SettingsService.")
	_check(_registry != null, "T-110 smoke requires the M1 registry.")
	_check(contract != null, "T-110 smoke requires the revisit contract.")
	if (
		_game_state == null
		or _scene_router == null
		or _save_service == null
		or _settings_service == null
		or _registry == null
		or contract == null
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
	_check(_app != null, "T-110 App scene could not instantiate.")
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
	_check(express_hud != null, "T-110 App is missing ExpressOrderHUD.")
	_check(status != null, "T-110 App is missing M1DebugStatus.")
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
		"T-110 Red Sand revisit debug scenario could not start: %s."
		% _controller.last_error
	)
	await process_frame
	await process_frame

	_check_debug_snapshot()
	_check_playable_route_handoff(contract)
	_check(
		_save_service.get_storage_access_count() == 0
		and _settings_service.get_storage_write_count() == 0,
		"T-110 preview crossed its isolated storage boundary."
	)

	await _cleanup()
	_finish()


func _check_debug_snapshot() -> void:
	_check(
		_game_state.main_story_chapter
		== M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
		and _game_state.has_completed_order(
			GameDataValidator.M1_ACTUAL_M0_ORDER_ID
		)
		and _game_state.has_story_flag(&"story_red_sand_order_completed")
		and _game_state.get_revisit_state(
			M1ProgressRules.PLANET_RED_SAND
		) == M1ProgressRules.REVISIT_RED_SAND_MATERIALS_PENDING
		and _game_state.current_order_id
		== M1DebugScenarioCatalog.ORDER_RED_SAND_REVISIT
		and _game_state.get_order_status(
			M1DebugScenarioCatalog.ORDER_RED_SAND_REVISIT
		) == GameStateModel.OrderStatus.ACCEPTED
		and not _game_state.ship_upgrade_ids.has(
			M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
		),
		"T-110 handoff did not start after M0 with accepted materials and no reward."
	)


func _check_playable_route_handoff(contract: RedSandRevisitContract) -> void:
	var active_scene: Node = (
		_app.scene_container.get_child(0)
		if _app.scene_container.get_child_count() == 1
		else null
	)
	_check(
		active_scene is RedSandFlight,
		"T-110 handoff did not open the formal Red Sand short route."
	)
	if not active_scene is RedSandFlight:
		return
	var route: RedSandFlight = active_scene as RedSandFlight
	var order: OrderDefinition = contract.order
	_check(
		route.is_revisit_route() and order.is_playable(),
		"T-110 handoff did not use the playable revisit variant."
	)
	_check(
		is_equal_approx(route.get_route_distance(), contract.route_entry_distance),
		"T-110 handoff started at %.2f instead of %.2f m."
		% [route.get_route_distance(), contract.route_entry_distance]
	)
	_check(
		route.get_active_segment_index()
		== contract.source_route.get_segment_index(contract.route_entry_distance),
		"T-110 handoff opened the wrong reused route segment."
	)
	_check(
		route.get_flight_ship().get_checkpoint_id()
		== contract.route_entry_checkpoint_id,
		"T-110 handoff did not capture the dedicated revisit checkpoint."
	)
	_check(
		route.get_route_hud().get_stage_text().contains("1/3")
		and route.get_route_hud().get_instruction_text()
		== tr(contract.get_stage_instruction_key(5)),
		"T-110 handoff did not expose localized 1/3 revisit guidance: %s | %s."
		% [
			route.get_route_hud().get_stage_text(),
			route.get_route_hud().get_instruction_text(),
		]
	)
	_check(
		contract.arrival_dialogue != null
		and contract.optional_dialogue != null
		and contract.source_route != null
		and contract.source_route.id == &"route_red_sand_m0"
		and is_equal_approx(contract.get_route_distance(), 12000.0)
		and is_equal_approx(contract.nominal_route_seconds, 48.0),
		"T-110 preview could not load the dialogue and short-route outline."
	)


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
			"[t110-red-sand-revisit] PASS: post-M0 formal-order handoff, "
			+ "localized short-route entry, dialogue contract, and "
			+ "pre-reward state."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t110-red-sand-revisit] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
