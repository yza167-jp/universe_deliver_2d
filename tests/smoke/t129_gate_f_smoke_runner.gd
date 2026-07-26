extends SceneTree

const APP_SCENE_PATH: String = "res://scenes/app/app.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const MAIN_CONTRACT_PATH: String = (
	"res://data/settlements/white_noise_settlement_contract.tres"
)
const SIDE_CONTRACT_PATH: String = (
	"res://data/settlements/white_noise_side_order_contract.tres"
)
const MAIN_TRAVEL_DIALOGUE_ID: StringName = (
	&"dialogue_m1_white_noise_travel_main"
)

var _failures: PackedStringArray = []
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
	_main_contract = load(
		MAIN_CONTRACT_PATH
	) as WhiteNoiseSettlementContract
	_side_contract = load(
		SIDE_CONTRACT_PATH
	) as WhiteNoiseSideOrderContract
	_check(_game_state != null, "Gate F smoke requires GameState.")
	_check(_scene_router != null, "Gate F smoke requires SceneRouter.")
	_check(_save_service != null, "Gate F smoke requires SaveService.")
	_check(_settings_service != null, "Gate F smoke requires SettingsService.")
	_check(_registry != null, "Gate F smoke requires the M1 registry.")
	_check(_main_contract != null, "Gate F smoke requires the main contract.")
	_check(_side_contract != null, "Gate F smoke requires the side contract.")
	if (
		_game_state == null
		or _scene_router == null
		or _save_service == null
		or _settings_service == null
		or _registry == null
		or _main_contract == null
		or _side_contract == null
	):
		await _finish()
		return

	_game_state.reset_runtime_state()
	_save_service.set_isolated_debug_session(true)
	_save_service.set_automatic_saves_enabled(false)
	_save_service.reset_storage_access_count()
	_settings_service.set_isolated_debug_session(true)
	_settings_service.reset_storage_write_count()
	var packed_app: PackedScene = load(APP_SCENE_PATH) as PackedScene
	_app = packed_app.instantiate() as UniverseDeliverApp
	_check(_app != null, "Gate F App scene could not instantiate.")
	if _app == null:
		await _finish()
		return
	root.add_child(_app)
	await _wait_frames(3)

	var express_hud: ExpressOrderHUD = _app.get_node_or_null(
		"PersistentUI/ExpressOrderHUD"
	) as ExpressOrderHUD
	var status: M1DebugStatus = _app.get_node_or_null(
		"PersistentUI/M1DebugStatus"
	) as M1DebugStatus
	_check(express_hud != null, "Gate F App is missing ExpressOrderHUD.")
	_check(status != null, "Gate F App is missing M1DebugStatus.")
	if express_hud == null or status == null:
		await _finish()
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
			M1DebugScenarioCatalog.SCENARIO_GATE_F
		),
		"Gate F scenario could not start: %s." % _controller.last_error
	)
	if _controller.get_definition() == null:
		await _finish()
		return
	var initial_signature: String = _controller.get_initial_state_signature()
	await _wait_frames(4)
	if not await _enter_main_route_from_station():
		await _finish()
		return

	_check(
		_controller.reset_scenario()
		and _controller.get_initial_state_signature() == initial_signature,
		"Gate F F6-equivalent reset did not restore the exact start."
	)
	await _wait_frames(4)
	_check(
		_settle_main_for_optional()
		and _scene_router.debug_switch_to_stage_scene(
			SceneRouterService.Stage.STATION,
			M1DebugScenarioCatalog.STATION_SCENE_PATH
		),
		"Gate F could not stage the post-main optional-order handoff."
	)
	await _wait_frames(4)
	_check_optional_order_ui()
	_check(
		_save_service.get_storage_access_count() == 0
		and _settings_service.get_storage_write_count() == 0,
		"Gate F crossed its isolated save or settings boundary."
	)
	await _finish()


func _enter_main_route_from_station() -> bool:
	var station: StationHub = _get_active_scene() as StationHub
	_check(station != null, "Gate F did not open the qualified station.")
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
		"Gate F order terminal could not open."
	)
	await _wait_frames(3)
	_check(
		terminal != null
		and terminal.get_selected_order_id() == _main_contract.order.id
		and terminal.is_accept_enabled()
		and terminal.accept_current_order(),
		"Gate F did not expose the formal White Noise main order."
	)
	if terminal == null or _game_state.current_order_id != _main_contract.order.id:
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
		"Gate F loadout could not open."
	)
	await _wait_frames(3)
	_check(
		loadout != null
		and loadout.get_order_definition_id() == _main_contract.order.id
		and loadout.is_confirm_enabled()
		and loadout.confirm_departure(),
		"Gate F loadout did not retain the installed high-voltage shielding."
	)
	if (
		loadout == null
		or not _game_state.is_departure_confirmed_for_order(
			_main_contract.order
		)
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
		and departure.enter_cockpit(),
		"Gate F station could not enter the White Noise cockpit."
	)
	await _wait_frames(4)
	var cockpit: Cockpit = _get_active_scene() as Cockpit
	_check(cockpit != null, "Gate F cockpit did not instantiate.")
	if cockpit == null:
		return false
	var travel: TravelSequenceController = cockpit.get_travel_controller()
	_check(
		cockpit.start_configured_travel() and travel != null,
		"Gate F cockpit travel could not start."
	)
	if travel == null:
		return false
	travel.advance_travel(travel.departure_duration + 0.1)
	await _wait_frames(2)
	var dialogue_ui: DialogueUI = cockpit.get_dialogue_ui()
	_check(
		dialogue_ui != null
		and cockpit.get_active_dialogue_id()
		== MAIN_TRAVEL_DIALOGUE_ID,
		"Gate F did not pause for the White Noise required travel dialogue."
	)
	if dialogue_ui == null:
		return false
	_check(
		dialogue_ui.skip_dialogue_sequence()
		== DialogueRuntime.SequenceSkipResult.FINISHED,
		"Gate F required travel dialogue could not finish."
	)
	await _wait_frames(2)
	travel.advance_travel(travel.cruise_duration + 0.1)
	travel.advance_travel(travel.approach_duration + 0.1)
	await _wait_frames(4)
	var route: WhiteNoiseFlight = _get_active_scene() as WhiteNoiseFlight
	_check(
		route != null
		and not route.is_side_order_route()
		and route.get_active_segment_index() == 0
		and route.get_flight_ship().is_high_voltage_shielding_enabled(),
		"Gate F cockpit did not enter the shielded full White Noise route."
	)
	return route != null


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


func _check_optional_order_ui() -> void:
	var station: StationHub = _get_active_scene() as StationHub
	var terminal: OrderTerminalUI = (
		station.get_order_terminal_ui()
		if station != null
		else null
	)
	_check(
		station != null
		and terminal != null
		and terminal.open_terminal()
		and terminal.select_order(_side_contract.order.id)
		and terminal.is_accept_enabled()
		and terminal.get_feedback_text().contains("自愿支线")
		and _game_state.can_accept_order(_side_contract.order)
		and _game_state.is_planet_unlocked(
			M1ProgressRules.PLANET_CANOPY_WORLD
		),
		"Gate F did not expose the voluntary returned-memory order after the main result."
	)


func _get_active_scene() -> Node:
	if _app == null or _app.scene_container.get_child_count() != 1:
		return null
	return _app.scene_container.get_child(0)


func _wait_frames(count: int) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _controller != null:
		_controller.stop_scenario()
	if _app != null and is_instance_valid(_app):
		_app.queue_free()
		await process_frame
	if _game_state != null:
		_game_state.reset_runtime_state()
	if _save_service != null:
		_save_service.set_isolated_debug_session(false)
	if _settings_service != null:
		_settings_service.set_isolated_debug_session(false)
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[t129-gate-f] PASS: isolated post-revisit start, formal main "
			+ "route, exact reset, optional-order handoff, and save isolation."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t129-gate-f] %s" % failure)
	quit(1)
