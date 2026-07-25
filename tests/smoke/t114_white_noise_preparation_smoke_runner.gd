extends SceneTree

const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"
const COCKPIT_SCENE_PATH: String = "res://scenes/cockpit/cockpit.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

var _failures: PackedStringArray = []
var _original_locale: String = ""
var _game_state: GameStateModel
var _registry: GameDataRegistry


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_check(_game_state != null, "T-114 smoke requires GameState.")
	_check(_registry != null, "T-114 smoke requires the M1 registry.")
	if _game_state == null or _registry == null:
		_finish()
		return
	var shielding: ShipModuleDefinition = _registry.find_module(
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
	)
	_check(shielding != null, "T-114 shielding module is missing.")
	if shielding == null:
		_finish()
		return
	_prepare_owned_uninstalled_state(shielding)

	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	var station: StationHub = station_scene.instantiate() as StationHub
	root.add_child(station)
	await _settle_frames(4)
	await _check_order_terminal(station)
	await _check_workbench(station, shielding)
	var snapshot: GameProgressData = GameProgressData.capture(_game_state)
	_check(
		snapshot.is_valid(),
		"T-114 installed preparation state could not be captured: %s."
		% snapshot.validation_error
	)
	await _cleanup_node(station)
	if snapshot.is_valid():
		_game_state.reset_runtime_state()
		_check(
			snapshot.apply_to(_game_state)
			and _game_state.is_planet_unlocked(
				M1ProgressRules.PLANET_WHITE_NOISE
			)
			and _game_state.is_ship_module_equipped(shielding.id),
			"Continue-compatible state lost the navigation unlock or installed shielding."
		)
	await _check_cockpit()
	_finish()


func _check_order_terminal(station: StationHub) -> void:
	var terminal: OrderTerminalUI = station.get_order_terminal_ui()
	var player: StationPlayer = station.get_station_player()
	var interactable: Interactable2D = station.get_node_or_null(
		"Interactables/OrderTerminal"
	) as Interactable2D
	_check(
		terminal != null and player != null and interactable != null,
		"T-114 station order terminal integration is incomplete."
	)
	if terminal == null or player == null or interactable == null:
		return
	_check(
		interactable.interact(player),
		"T-114 order terminal interaction was rejected."
	)
	await _settle_frames(2)
	_check(
		terminal.visible
		and terminal.get_selected_order_id()
		== M1CatalogModel.WHITE_NOISE_ORDER_ID
		and terminal.get_order_name_text().contains("白噪")
		and terminal.get_environment_text().contains("1.28g")
		and terminal.get_environment_text().contains("电磁暴雪")
		and terminal.get_environment_text().contains("低能见度")
		and terminal.get_required_modules_text().contains("已拥有，未安装")
		and terminal.get_feedback_text().contains("安装到防护槽")
		and not terminal.is_accept_enabled()
		and VIEWPORT_RECT.encloses(terminal.get_panel_rect()),
		"The order preview did not show risk, module state, route guard, or 640x360 containment."
	)
	terminal.close_terminal()
	await process_frame


func _check_workbench(
	station: StationHub,
	shielding: ShipModuleDefinition
) -> void:
	var loadout: ShipLoadoutUI = station.get_ship_loadout_ui()
	var player: StationPlayer = station.get_station_player()
	var workbench: Interactable2D = station.get_node_or_null(
		"Interactables/ShipWorkbench"
	) as Interactable2D
	_check(
		loadout != null and player != null and workbench != null,
		"T-114 station workbench integration is incomplete."
	)
	if loadout == null or player == null or workbench == null:
		return
	_check(
		workbench.interact(player),
		"T-114 workbench interaction was rejected."
	)
	await _settle_frames(2)
	_check(
		loadout.visible
		and loadout.get_order_definition_id()
		== M1CatalogModel.WHITE_NOISE_ORDER_ID
		and loadout.get_status_text() == "待安装屏蔽罩"
		and loadout.get_feedback_text().contains("安装到防护槽")
		and loadout.get_slot_status_text(
			ShipModuleDefinition.SlotType.DEFENSE
		).contains("已拥有")
		and not loadout.is_confirm_enabled()
		and VIEWPORT_RECT.encloses(loadout.get_panel_rect()),
		"The workbench did not consume the owned-not-installed preparation state."
	)
	_check(
		loadout.toggle_module_by_id(shielding.id),
		"T-114 workbench could not install the owned shielding."
	)
	_check(
		loadout.is_high_voltage_shielding_visual_visible()
		and loadout.get_status_text() == "资格已满足 · 航路待开放"
		and loadout.get_feedback_text().contains("正式航路仍在校准")
		and not loadout.is_confirm_enabled(),
		"Installed shielding did not change the shared state to qualified-route-pending."
	)
	loadout.close_loadout()
	await process_frame


func _check_cockpit() -> void:
	var scene: PackedScene = load(COCKPIT_SCENE_PATH) as PackedScene
	var cockpit: Cockpit = scene.instantiate() as Cockpit
	root.add_child(cockpit)
	await _settle_frames(3)
	_check(
		cockpit.activate_hotspot(&"navigation_screen"),
		"T-114 cockpit navigation hotspot could not open."
	)
	await _settle_frames(2)
	var panel: CockpitNavigationPanel = cockpit.get_navigation_panel()
	var text: String = cockpit.get_device_panel_body()
	_check(
		panel != null
		and panel.get_preparation_status() != null
		and panel.get_preparation_status().state
		== M1DestinationPreparationStatus.State.QUALIFIED_ROUTE_PENDING
		and text.contains("主线预览")
		and text.contains("白噪星")
		and text.contains("1.28g 强重力")
		and text.contains("电磁暴雪")
		and text.contains("低能见度")
		and text.contains("特高压电屏蔽罩（已安装）")
		and text.contains("正式航路仍在校准")
		and text.contains("导航已解锁 · 航路待开放")
		and not cockpit.is_navigation_action_enabled()
		and not cockpit.start_configured_travel(),
		"The cockpit did not share the qualified preview or preserve the hard departure guard."
	)
	await _cleanup_node(cockpit)


func _prepare_owned_uninstalled_state(
	shielding: ShipModuleDefinition
) -> void:
	_game_state.reset_runtime_state()
	_game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	_game_state.unlocked_planet_ids = [
		M1ProgressRules.PLANET_RED_SAND,
		M1ProgressRules.PLANET_WHITE_NOISE,
	]
	for order_id: StringName in [
		M1CatalogModel.M0_ORDER_ID,
		M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT,
	]:
		_game_state.completed_order_ids[order_id] = true
		_game_state.order_states[order_id] = GameStateModel.OrderStatus.COMPLETED
		_game_state.reward_applied_order_ids.append(order_id)
	_game_state.story_flags[
		StationTutorialController.COMPLETION_FLAG
	] = true
	_game_state.story_flags[
		M1ProgressRules.STORY_RED_SAND_SHIELDING_RETROFIT_COMPLETED
	] = true
	_game_state.story_flags[
		StationTutorialController.ARCHIVE_BRIEFING_COMPLETION_FLAG
	] = true
	_game_state.ship_upgrade_ids.append(shielding.id)


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _cleanup_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
		await _settle_frames(2)


func _finish() -> void:
	if _game_state != null:
		_game_state.reset_runtime_state()
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[t114-white-noise-preparation] PASS: order preview, risk brief, "
			+ "owned/install states, persistent navigation unlock, cockpit preview, "
			+ "REGISTERED_ONLY guard, and 640x360 containment."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t114-white-noise-preparation] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
