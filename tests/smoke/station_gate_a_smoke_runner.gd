extends SceneTree

const APP_SCENE_PATH: String = "res://scenes/app/app.tscn"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

var _failures: PackedStringArray = []
var _original_locale: String = ""
var _game_state: GameStateModel
var _scene_router: SceneRouterService
var _app: UniverseDeliverApp


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_scene_router = root.get_node_or_null("SceneRouter") as SceneRouterService
	_check(_game_state != null, "GameState autoload is unavailable.")
	_check(_scene_router != null, "SceneRouter autoload is unavailable.")
	if _game_state == null or _scene_router == null:
		_finish_smoke()
		return

	_game_state.reset_runtime_state()
	_game_state.set_story_flag(&"gate_a_reset_fixture")
	var app_scene: PackedScene = load(APP_SCENE_PATH) as PackedScene
	_check(app_scene != null, "App scene could not be loaded.")
	if app_scene == null:
		_finish_smoke()
		return
	_app = app_scene.instantiate() as UniverseDeliverApp
	_check(_app != null, "App scene did not instantiate as UniverseDeliverApp.")
	if _app == null:
		_finish_smoke()
		return
	root.add_child(_app)
	await process_frame
	await process_frame

	var debug_layer: CanvasLayer = _app.get_node_or_null("DebugLayer") as CanvasLayer
	_check(debug_layer != null and not debug_layer.visible, "Player startup exposed the debug layer.")
	var scene_container: Control = _app.get_node_or_null("SceneContainer") as Control
	_check(scene_container != null, "App SceneContainer is missing.")
	if scene_container == null or scene_container.get_child_count() != 1:
		_check(false, "App did not start with exactly one stage scene.")
		await _cleanup()
		_finish_smoke()
		return
	var main_menu: MainMenu = scene_container.get_child(0) as MainMenu
	_check(main_menu != null, "First stage is not the playable main menu.")
	if main_menu == null:
		await _cleanup()
		_finish_smoke()
		return
	_check(
		VIEWPORT_RECT.encloses(main_menu.get_panel_rect()),
		"Main menu panel leaves the 640x360 viewport: %s" % main_menu.get_panel_rect()
	)
	_check(main_menu.get_title_text().contains("宇宙送快递"), "Main menu title is not localized.")
	_check(
		main_menu.get_brief_text().contains("老皮")
		and main_menu.get_brief_text().contains("赤砂星"),
		"Main menu does not explain the Gate A starting purpose."
	)
	_check(
		main_menu.get_controls_text().contains("WASD")
		and main_menu.get_controls_text().contains("E"),
		"Main menu does not expose movement and interaction controls."
	)
	_check(main_menu.get_start_button_text() == "开始新游戏", "New-game action is unclear.")
	_check(main_menu.is_start_button_focused(), "New-game action does not receive initial focus.")

	_check(main_menu.start_new_game(), "New game could not start from the main menu.")
	await process_frame
	await process_frame
	_check(
		not _game_state.has_story_flag(&"gate_a_reset_fixture"),
		"New game did not reset prior runtime state."
	)
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.STATION,
		"New game did not transition to the station."
	)
	var station: StationHub = scene_container.get_child(0) as StationHub
	_check(station != null, "Station did not load after starting a new game.")
	if station == null:
		await _cleanup()
		_finish_smoke()
		return
	await process_frame
	await process_frame

	var tutorial: StationTutorialController = station.get_tutorial_controller()
	var modal_coordinator: StationModalCoordinator = station.get_modal_coordinator()
	var departure: StationDepartureController = station.get_departure_controller()
	var player: StationPlayer = station.get_station_player()
	var lao_pi: LaoPiStation = station.get_lao_pi()
	var terminal_ui: OrderTerminalUI = station.get_order_terminal_ui()
	var loadout_ui: ShipLoadoutUI = station.get_ship_loadout_ui()
	var objective: Control = station.get_node_or_null(
		"TutorialUILayer/TutorialObjective"
	) as Control
	var order_terminal: Interactable2D = station.get_node_or_null(
		"Interactables/OrderTerminal"
	) as Interactable2D
	var workbench: Interactable2D = station.get_node_or_null(
		"Interactables/ShipWorkbench"
	) as Interactable2D
	var cockpit_entry: Interactable2D = station.get_node_or_null(
		"Interactables/CockpitEntry"
	) as Interactable2D
	_check(tutorial != null, "Station tutorial controller is missing.")
	_check(modal_coordinator != null, "Station modal coordinator is missing.")
	_check(departure != null, "Station departure controller is missing.")
	_check(player != null, "Station player is missing.")
	_check(lao_pi != null, "Lao Pi is missing.")
	_check(terminal_ui != null, "Order terminal UI is missing.")
	_check(loadout_ui != null, "Ship loadout UI is missing.")
	_check(objective != null, "Station objective HUD is missing.")
	_check(order_terminal != null, "Order terminal interaction is missing.")
	_check(workbench != null, "Ship workbench interaction is missing.")
	_check(cockpit_entry != null, "Cockpit entrance interaction is missing.")
	if (
		tutorial == null
		or modal_coordinator == null
		or departure == null
		or player == null
		or lao_pi == null
		or terminal_ui == null
		or loadout_ui == null
		or objective == null
		or order_terminal == null
		or workbench == null
		or cockpit_entry == null
	):
		await _cleanup()
		_finish_smoke()
		return

	var dialogue_ui: DialogueUI = tutorial.get_dialogue_ui()
	_check(dialogue_ui != null, "Tutorial dialogue UI is missing.")
	if dialogue_ui == null:
		await _cleanup()
		_finish_smoke()
		return
	_check(
		modal_coordinator.has_modal(StationTutorialController.MODAL_DIALOGUE),
		"Opening tutorial dialogue did not acquire the dialogue modal lock."
	)
	_check(player.is_interaction_prompt_suppressed(), "Dialogue did not suppress interaction prompts.")
	_check(
		not objective.visible,
		"Tutorial objective remained visible over dialogue."
	)
	await _finish_dialogue(tutorial, dialogue_ui, &"dialogue_lao_pi_tutorial_intro")
	_check(not modal_coordinator.is_modal_active(), "Tutorial dialogue did not release its modal lock.")
	player.position += Vector2(48.0, 0.0)
	await process_frame
	await process_frame
	await _finish_dialogue(tutorial, dialogue_ui, &"dialogue_lao_pi_tutorial_move_ack")
	_check(lao_pi.interact(player), "Tutorial Lao Pi interaction was rejected.")
	await _finish_dialogue(tutorial, dialogue_ui, &"dialogue_lao_pi_tutorial_interact_ack")
	_check(order_terminal.interact(player), "Tutorial order terminal interaction was rejected.")
	await _finish_dialogue(tutorial, dialogue_ui, &"dialogue_lao_pi_tutorial_complete")
	await process_frame
	await process_frame
	_check(tutorial.is_tutorial_complete(), "Tutorial did not complete through the player path.")
	_check(terminal_ui.visible, "Tutorial completion did not open the order terminal.")
	_check(
		modal_coordinator.has_modal(StationOrderTerminalController.MODAL_ORDER_TERMINAL),
		"Order terminal did not retain modal priority after the tutorial handoff."
	)
	_check(
		not objective.visible,
		"Route objective remained visible over the order terminal."
	)
	_check(
		departure.get_flow_state() == StationDepartureController.FlowState.WAIT_FOR_ORDER,
		"Post-tutorial flow did not wait for order acceptance."
	)

	terminal_ui.close_terminal()
	await process_frame
	_check(not modal_coordinator.is_modal_active(), "Closing the terminal did not release modal priority.")
	_check(
		objective.visible,
		"Closing the terminal did not restore route guidance."
	)
	_check(cockpit_entry.interact(player), "Locked cockpit entrance did not provide feedback.")
	_check(
		departure.get_objective_text().contains("先在订单终端"),
		"Early cockpit attempt did not redirect the player to the order terminal."
	)
	_check(order_terminal.interact(player), "Order terminal could not reopen after an early close.")
	await process_frame
	_check(terminal_ui.accept_current_order(), "Red Sand order could not be accepted.")
	terminal_ui.close_terminal()
	await process_frame
	await _finish_dialogue(tutorial, dialogue_ui, &"dialogue_lao_pi_order_accepted")
	_check(
		departure.get_flow_state() == StationDepartureController.FlowState.WAIT_FOR_LOADOUT,
		"Accepted order did not advance the flow to ship configuration."
	)
	_check(
		departure.get_objective_text().contains("模块工作台"),
		"Accepted order did not expose the workbench objective."
	)
	_check(cockpit_entry.interact(player), "Preflight-locked cockpit entrance rejected interaction.")
	_check(
		departure.get_objective_text().contains("确认飞船配置"),
		"Early cockpit attempt did not redirect the player to ship configuration."
	)

	_check(workbench.interact(player), "Ship workbench could not open from the station flow.")
	await process_frame
	_check(loadout_ui.visible, "Ship loadout did not open.")
	_check(
		modal_coordinator.has_modal(StationShipLoadoutController.MODAL_SHIP_LOADOUT),
		"Ship loadout did not acquire modal priority."
	)
	_check(
		not objective.visible,
		"Route objective remained visible over the ship loadout."
	)
	_check(
		loadout_ui.toggle_module_for_slot(ShipModuleDefinition.SlotType.UTILITY),
		"Optional asteroid laser could not be selected during Gate A."
	)
	_check(loadout_ui.confirm_departure(), "Valid Gate A loadout could not confirm departure.")
	loadout_ui.close_loadout()
	await process_frame
	_check(not modal_coordinator.is_modal_active(), "Closing ship loadout did not release modal priority.")
	_check(
		departure.get_flow_state()
		== StationDepartureController.FlowState.READY_FOR_COCKPIT,
		"Departure confirmation did not unlock the cockpit endpoint."
	)
	_check(
		departure.get_objective_text().contains("驾驶舱入口")
		and departure.get_objective_text().contains("老皮"),
		"Confirmed loadout did not direct the player to meet Lao Pi at the cockpit."
	)
	_check(
		cockpit_entry.prompt_key == &"UI_INTERACTION_COCKPIT_ENTRY_READY",
		"Cockpit interaction prompt did not visibly unlock."
	)

	_check(cockpit_entry.interact(player), "Ready cockpit entrance interaction was rejected.")
	await process_frame
	await process_frame
	_check(departure.is_departure_gate_visible(), "Cockpit entrance did not open the Gate A endpoint.")
	_check(not player.is_input_enabled(), "Station input remained active behind the endpoint panel.")
	_check(
		modal_coordinator.has_modal(StationDepartureController.MODAL_DEPARTURE_GATE),
		"Departure gate did not acquire modal priority."
	)
	_check(
		not objective.visible,
		"Route objective remained visible over the departure gate."
	)
	_check(
		departure.get_departure_gate_text().contains("出发准备完成")
		and departure.get_departure_gate_text().contains("赤砂星")
		and departure.get_departure_gate_text().contains("老皮"),
		"Gate A endpoint does not summarize destination, cargo preparation, and partner."
	)
	var departure_panel: PanelContainer = station.get_node_or_null(
		"DepartureUILayer/DepartureReadyPanel/Panel"
	) as PanelContainer
	_check(
		departure_panel != null and VIEWPORT_RECT.encloses(departure_panel.get_global_rect()),
		"Gate A endpoint panel leaves the 640x360 viewport: %s"
		% (Rect2() if departure_panel == null else departure_panel.get_global_rect())
	)
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.STATION,
		"Gate A must stop before entering the unimplemented cockpit."
	)
	departure.close_departure_gate()
	_check(player.is_input_enabled(), "Returning to the station did not restore player input.")
	_check(not modal_coordinator.is_modal_active(), "Departure gate did not release modal priority.")

	await _cleanup()
	_finish_smoke()


func _finish_dialogue(
	tutorial: StationTutorialController,
	dialogue_ui: DialogueUI,
	expected_dialogue_id: StringName
) -> void:
	_check(
		tutorial.get_active_dialogue_id() == expected_dialogue_id,
		"Expected dialogue was not active: %s" % expected_dialogue_id
	)
	if tutorial.get_active_dialogue_id() != expected_dialogue_id:
		return
	var remaining_lines: int = 20
	while tutorial.get_active_dialogue_id() == expected_dialogue_id and remaining_lines > 0:
		dialogue_ui.quick_show_current_line()
		_check(
			dialogue_ui.continue_dialogue(),
			"Dialogue could not advance: %s" % expected_dialogue_id
		)
		remaining_lines -= 1
		await process_frame
	_check(
		remaining_lines > 0,
		"Dialogue exceeded its smoke-test line limit: %s" % expected_dialogue_id
	)


func _cleanup() -> void:
	if _app != null and is_instance_valid(_app):
		_app.queue_free()
		await process_frame
		await process_frame
	if _game_state != null:
		_game_state.reset_runtime_state()


func _finish_smoke() -> void:
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print("[station-gate-a] PASS: new game, tutorial, order, loadout, cockpit gate, and clean player UI.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("[station-gate-a] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
