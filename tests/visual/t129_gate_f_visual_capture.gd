extends SceneTree

const APP_SCENE_PATH: String = "res://scenes/app/app.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const MAIN_CONTRACT_PATH: String = (
	"res://data/settlements/white_noise_settlement_contract.tres"
)
const SIDE_CONTRACT_PATH: String = (
	"res://data/settlements/white_noise_side_order_contract.tres"
)
const CAPTURE_DIRECTORY: String = "res://.omx/artifacts/t129_gate_f"

var _original_locale: String = ""
var _game_state: GameStateModel
var _scene_router: SceneRouterService
var _save_service: SaveServiceModel
var _settings_service: SettingsServiceModel
var _registry: GameDataRegistry
var _main_contract: WhiteNoiseSettlementContract
var _side_contract: WhiteNoiseSideOrderContract
var _app: UniverseDeliverApp
var _controller: M1DebugScenarioController


func _initialize() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_scene_router = root.get_node_or_null("SceneRouter") as SceneRouterService
	_save_service = root.get_node_or_null("SaveService") as SaveServiceModel
	_settings_service = root.get_node_or_null(
		"SettingsService"
	) as SettingsServiceModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_main_contract = load(
		MAIN_CONTRACT_PATH
	) as WhiteNoiseSettlementContract
	_side_contract = load(
		SIDE_CONTRACT_PATH
	) as WhiteNoiseSideOrderContract
	if (
		_game_state == null
		or _scene_router == null
		or _save_service == null
		or _settings_service == null
		or _registry == null
		or _main_contract == null
		or _side_contract == null
	):
		_fail("Gate F visual runtime data is unavailable.")
		return
	_game_state.reset_runtime_state()
	_save_service.set_isolated_debug_session(true)
	_save_service.set_automatic_saves_enabled(false)
	_settings_service.set_isolated_debug_session(true)
	var packed_app: PackedScene = load(APP_SCENE_PATH) as PackedScene
	_app = packed_app.instantiate() as UniverseDeliverApp
	if _app == null:
		_fail("Gate F visual App could not instantiate.")
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
		_fail("Gate F visual App is missing persistent UI.")
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
	if not _controller.start_scenario(
		M1DebugScenarioCatalog.SCENARIO_GATE_F
	):
		_fail("Gate F visual scenario could not start.")
		return
	await _settle_frames(5)
	if not _save_frame("01_post_revisit_station_start.png"):
		return
	if not await _capture_order_terminal(
		_main_contract.order.id,
		"02_white_noise_main_ready.png",
		false
	):
		return
	if (
		not _settle_main_for_optional()
		or not _scene_router.debug_switch_to_stage_scene(
			SceneRouterService.Stage.STATION,
			M1DebugScenarioCatalog.STATION_SCENE_PATH
		)
	):
		_fail("Gate F visual optional-order handoff could not be staged.")
		return
	await _settle_frames(5)
	if not await _capture_order_terminal(
		_side_contract.order.id,
		"03_returned_memory_optional_ready.png",
		true
	):
		return
	await _cleanup()
	print(
		"[t129-gate-f-visual] PASS: saved Gate F station, main-order, "
		+ "and voluntary side-order frames."
	)
	quit(0)


func _capture_order_terminal(
	order_id: StringName,
	file_name: String,
	expects_voluntary_feedback: bool
) -> bool:
	var station: StationHub = _get_active_scene() as StationHub
	var terminal: OrderTerminalUI = (
		station.get_order_terminal_ui()
		if station != null
		else null
	)
	if (
		terminal == null
		or not terminal.open_terminal()
		or not terminal.select_order(order_id)
		or not terminal.is_accept_enabled()
		or (
			expects_voluntary_feedback
			and not terminal.get_feedback_text().contains("自愿支线")
		)
	):
		_fail("Gate F visual order terminal could not stage %s." % order_id)
		return false
	await _settle_frames(3)
	var saved: bool = _save_frame(file_name)
	terminal.close_terminal()
	await _settle_frames(2)
	return saved


func _settle_main_for_optional() -> bool:
	if not _game_state.accept_order(_main_contract.order):
		return false
	_game_state.set_story_flag(
		_main_contract.arrival_contract.main_dialogue_completion_flag
	)
	_game_state.set_story_flag(
		_main_contract.arrival_contract.choice_recorded_flag
	)
	_game_state.set_story_flag(
		_main_contract.arrival_contract.keep_sealed_flag
	)
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	var settlement: OrderSettlementResult = (
		OrderSettlementCalculator.calculate(_main_contract.order, run_state)
	)
	return (
		settlement != null
		and _game_state.settle_current_order(
			_main_contract.order,
			settlement,
			&"",
			_main_contract.get_settlement_flags(),
			_main_contract.get_choice_relation_rewards(_game_state),
			[],
			_main_contract.get_choice_codex_rewards(_game_state),
			_main_contract.get_demo_ending_flags(_game_state)
		)
	)


func _get_active_scene() -> Node:
	if _app == null or _app.scene_container.get_child_count() != 1:
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
		_fail("Could not create the Gate F capture directory.")
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Gate F viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	if image.save_png(output_path) != OK:
		_fail("Could not save %s." % output_path)
		return false
	print("[t129-gate-f-visual] Saved %s" % output_path)
	return true


func _cleanup() -> void:
	if _controller != null:
		_controller.stop_scenario()
	if _app != null and is_instance_valid(_app):
		_app.queue_free()
		await _settle_frames(3)
	if _game_state != null:
		_game_state.reset_runtime_state()
	if _save_service != null:
		_save_service.set_isolated_debug_session(false)
	if _settings_service != null:
		_settings_service.set_isolated_debug_session(false)
	TranslationServer.set_locale(_original_locale)


func _fail(message: String) -> void:
	printerr("[t129-gate-f-visual] FAIL: %s" % message)
	if _controller != null:
		_controller.stop_scenario()
	if _app != null and is_instance_valid(_app):
		_app.queue_free()
	if _game_state != null:
		_game_state.reset_runtime_state()
	if _save_service != null:
		_save_service.set_isolated_debug_session(false)
	if _settings_service != null:
		_settings_service.set_isolated_debug_session(false)
	TranslationServer.set_locale(_original_locale)
	quit(1)
