extends SceneTree

const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"
const FLIGHT_LAB_SCENE_PATH: String = "res://scenes/flight/flight_lab.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const WHITE_ORDER_ID: StringName = &"order_m1_white_noise_archive_core"
const PLAYABLE_ROUTE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

var _failures: PackedStringArray = []
var _original_locale: String = ""
var _game_state: GameStateModel


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	_check(_game_state != null, "T-111 smoke requires GameState.")
	_check(registry != null, "T-111 smoke requires the M1 registry.")
	if _game_state == null or registry == null:
		_finish()
		return
	var shielding: ShipModuleDefinition = registry.find_module(
		ShipLoadoutRules.HIGH_VOLTAGE_SHIELDING_MODULE_ID
	)
	var source_order: OrderDefinition = registry.find_order(WHITE_ORDER_ID)
	_check(shielding != null, "T-111 shielding module is missing.")
	_check(source_order != null, "T-111 White Noise order is missing.")
	if shielding == null or source_order == null:
		_finish()
		return

	var fixture_order: OrderDefinition = _make_playable_white_order(source_order)
	var fixture_registry: GameDataRegistry = GameDataRegistry.new()
	fixture_registry.registry_id = &"t111_white_noise_fixture"
	fixture_registry.orders = [fixture_order]
	fixture_registry.planets = [fixture_order.destination_planet]
	fixture_registry.modules = registry.modules

	_prepare_owned_uninstalled_state(shielding)
	_check(
		_game_state.accept_order(fixture_order),
		"T-111 playable White Noise fixture could not be accepted."
	)
	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	var station: StationHub = station_scene.instantiate() as StationHub
	root.add_child(station)
	await process_frame
	await process_frame
	var terminal: OrderTerminalUI = station.get_order_terminal_ui()
	var loadout: ShipLoadoutUI = station.get_ship_loadout_ui()
	var player: StationPlayer = station.get_station_player()
	var workbench: Interactable2D = station.get_node_or_null(
		"Interactables/ShipWorkbench"
	) as Interactable2D
	_check(terminal != null, "T-111 station order terminal is missing.")
	_check(loadout != null, "T-111 station loadout is missing.")
	_check(player != null, "T-111 station player is missing.")
	_check(workbench != null, "T-111 station workbench is missing.")
	if terminal == null or loadout == null or player == null or workbench == null:
		await _cleanup_node(station)
		_finish()
		return
	terminal.set_data_registry(fixture_registry)
	_check(workbench.interact(player), "T-111 workbench interaction was rejected.")
	await process_frame

	_check(
		loadout.visible
		and loadout.get_order_definition_id() == WHITE_ORDER_ID
		and VIEWPORT_RECT.encloses(loadout.get_panel_rect()),
		"The workbench did not bind the active M1 order inside 640x360."
	)
	_check(
		not loadout.is_confirm_enabled()
		and loadout.get_status_text() == "配置不完整"
		and loadout.get_feedback_text().contains("重新安装")
		and loadout.get_feedback_text().contains("特高压电屏蔽罩"),
		"Owned but uninstalled shielding did not block departure clearly."
	)
	_check(
		loadout.toggle_module_for_slot(ShipModuleDefinition.SlotType.DEFENSE),
		"The owned shielding could not be installed from the normal workbench."
	)
	_check(
		loadout.is_high_voltage_shielding_visual_visible()
		and loadout.get_slot_status_text(
			ShipModuleDefinition.SlotType.DEFENSE
		).contains("主线必需 / 剧情获得")
		and loadout.get_slot_status_text(
			ShipModuleDefinition.SlotType.DEFENSE
		).contains("已安装")
		and _game_state.has_ship_capability(
			ShipLoadoutRules.HIGH_VOLTAGE_SHIELDING_CAPABILITY,
			registry.modules
		)
		and loadout.is_confirm_enabled()
		and loadout.confirm_departure(),
		"Installed shielding did not expose its capability, visual, or preflight."
	)

	_check(
		loadout.toggle_module_for_slot(ShipModuleDefinition.SlotType.DEFENSE),
		"The shielding could not be removed for acquisition-path feedback."
	)
	_game_state.ship_upgrade_ids.erase(shielding.id)
	loadout.set_order_definition(fixture_order)
	_check(
		not loadout.toggle_module_for_slot(ShipModuleDefinition.SlotType.DEFENSE)
		and _game_state.last_loadout_error
		== GameStateModel.LOADOUT_ERROR_MODULE_NOT_OWNED
		and loadout.get_feedback_text().contains("完成对应主线获取任务")
		and not loadout.is_high_voltage_shielding_visual_visible(),
		"Unobtained shielding was installable or lacked a clear acquisition path."
	)
	loadout.close_loadout()
	await _cleanup_node(station)

	_game_state.reset_runtime_state()
	_game_state.ship_upgrade_ids.append(shielding.id)
	_check(
		_game_state.equip_ship_module(shielding),
		"T-111 flight visual fixture could not install shielding."
	)
	var flight_scene: PackedScene = load(FLIGHT_LAB_SCENE_PATH) as PackedScene
	var flight_lab: FlightLab = flight_scene.instantiate() as FlightLab
	root.add_child(flight_lab)
	await process_frame
	var ship: FlightLabShip = flight_lab.flight_ship
	_check(ship != null, "T-111 Flight Lab ship is missing.")
	if ship != null:
		ship.configure_high_voltage_shielding(
			_game_state.ship_configuration,
			registry.modules
		)
		_check(
			ship.is_high_voltage_shielding_enabled()
			and ship.is_high_voltage_shielding_visual_visible()
			and is_equal_approx(ship.get_high_voltage_damage_multiplier(), 0.6)
			and is_equal_approx(
				ship.get_electromagnetic_interference_multiplier(),
				0.45
			),
			"The flight ship did not expose the configured shielding visual/effect."
		)
		ship.shield = 100.0
		ship.hull = 100.0
		_check(
			ship.apply_high_voltage_damage(
				20.0,
				0.0,
				&"UI_T111_HIGH_VOLTAGE_TEST"
			)
			and is_equal_approx(ship.shield, 88.0)
			and is_equal_approx(ship.hull, 100.0),
			"High-voltage protection did not reduce damage before ordinary shields."
		)
		_check(
			ship.apply_environment_damage(
				10.0,
				0.0,
				&"UI_T111_ORDINARY_DAMAGE_TEST"
			)
			and is_equal_approx(ship.shield, 78.0),
			"Shielding incorrectly replaced or modified ordinary shield damage."
		)
	await _cleanup_node(flight_lab)
	_finish()


func _prepare_owned_uninstalled_state(module: ShipModuleDefinition) -> void:
	_game_state.reset_runtime_state()
	_game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	_game_state.unlocked_planet_ids = [
		M1ProgressRules.PLANET_RED_SAND,
		M1ProgressRules.PLANET_WHITE_NOISE,
	]
	_game_state.ship_upgrade_ids.append(module.id)
	_game_state.set_story_flag(
		&"story_m1_red_sand_shielding_retrofit_completed"
	)


func _make_playable_white_order(source: OrderDefinition) -> OrderDefinition:
	var fixture: OrderDefinition = source.duplicate(true) as OrderDefinition
	var planet: PlanetDefinition = (
		source.destination_planet.duplicate(true) as PlanetDefinition
	)
	fixture.content_readiness = OrderDefinition.ContentReadiness.PLAYABLE
	planet.content_readiness = PlanetDefinition.ContentReadiness.PLAYABLE
	planet.flight_scene_path = PLAYABLE_ROUTE_PATH
	fixture.destination_planet = planet
	return fixture


func _cleanup_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
		await process_frame


func _finish() -> void:
	if _game_state != null:
		_game_state.reset_runtime_state()
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[t111-high-voltage-shielding] PASS: story ownership, "
			+ "workbench gate, save-ready installation, capability stats, "
			+ "visible ship retrofit, and ordinary-shield separation."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t111-high-voltage-shielding] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
