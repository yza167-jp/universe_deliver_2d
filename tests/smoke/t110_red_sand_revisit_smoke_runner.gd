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
	_check_catalog_preview(contract)
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
		) == M1ProgressRules.REVISIT_RED_SAND_AVAILABLE
		and not _game_state.ship_upgrade_ids.has(
			M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
		),
		"T-110 preview did not start after M0 and before retrofit rewards."
	)


func _check_catalog_preview(contract: RedSandRevisitContract) -> void:
	var active_scene: Node = (
		_app.scene_container.get_child(0)
		if _app.scene_container.get_child_count() == 1
		else null
	)
	_check(
		active_scene is M1DebugCatalogView,
		"T-110 preview did not open the isolated catalog scene."
	)
	if not active_scene is M1DebugCatalogView:
		return
	var terminal: OrderTerminalUI = (
		active_scene as M1DebugCatalogView
	).get_order_terminal()
	var order: OrderDefinition = contract.order
	_check(
		terminal != null
		and terminal.visible
		and terminal.get_selected_order_id() == order.id
		and not terminal.is_accept_enabled()
		and terminal.get_order_name_text() == tr(order.display_name_key)
		and terminal.get_cargo_text().contains(tr(order.cargo.display_name_key))
		and terminal.get_relation_reward_text().contains("+1")
		and order.content_readiness
		== OrderDefinition.ContentReadiness.REGISTERED_ONLY,
		"T-110 preview did not expose the focused, localized, locked revisit packet."
	)
	_check(
		contract.arrival_dialogue != null
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
			"[t110-red-sand-revisit] PASS: post-M0 isolated preview, "
			+ "focused localized packet, dialogue, route outline, and "
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
