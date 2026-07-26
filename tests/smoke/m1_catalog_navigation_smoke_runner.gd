extends SceneTree

const COCKPIT_SCENE_PATH: String = "res://scenes/cockpit/cockpit.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)
const M0_ORDER_ID: StringName = &"order_red_sand_m0"
const REGISTERED_ORDER_ID: StringName = (
	&"order_m1_canopy_ecology_cargo"
)

var _failures: PackedStringArray = []
var _game_state: GameStateModel
var _registry: GameDataRegistry
var _cockpit: Cockpit
var _original_locale: String = ""


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_check(_game_state != null, "M1 navigation smoke requires GameState.")
	_check(_registry != null, "M1 navigation smoke requires the M1 registry.")
	if _game_state == null or _registry == null:
		_finish()
		return
	_game_state.reset_runtime_state()
	var scene: PackedScene = load(COCKPIT_SCENE_PATH) as PackedScene
	_cockpit = scene.instantiate() as Cockpit
	_check(_cockpit != null, "Cockpit could not instantiate.")
	if _cockpit == null:
		_finish()
		return
	root.add_child(_cockpit)
	await process_frame
	await process_frame

	_check(
		_cockpit.data_registry == _registry
		or (
			_cockpit.data_registry != null
			and _cockpit.data_registry.registry_id == _registry.registry_id
		),
		"Normal cockpit did not load the M1 registry."
	)
	_check(
		_cockpit.activate_hotspot(&"navigation_screen"),
		"No-order navigation panel could not open."
	)
	await process_frame
	var device_panel: PanelContainer = _cockpit.get_node_or_null(
		"ModalLayer/DevicePanel"
	) as PanelContainer
	var navigation_panel: CockpitNavigationPanel = _cockpit.get_navigation_panel()
	_check(
		device_panel != null
		and VIEWPORT_RECT.encloses(device_panel.get_global_rect()),
		"Navigation panel leaves the 640x360 viewport."
	)
	_check(
		navigation_panel != null
		and not _cockpit.is_navigation_action_enabled()
		and _cockpit.get_device_panel_body().contains(
			tr("UI_COCKPIT_NAV_ROUTE_NO_ORDER")
		),
		"No-order navigation did not visibly block departure."
	)
	_check(
		_cockpit.get_device_panel_body().contains(
			tr("UI_COCKPIT_NAV_PLANET_UNKNOWN")
		)
		and not _cockpit.get_device_panel_body().contains(
			tr("PLANET_WHITE_NOISE_NAME_PROVISIONAL")
		)
		and not _cockpit.get_device_panel_body().contains(
			tr("PLANET_CANOPY_WORLD_NAME_PROVISIONAL")
		),
		"Undiscovered planets leaked formal names in the player navigation panel."
	)
	_check(
		not _cockpit.start_configured_travel(),
		"No-order navigation incorrectly started travel."
	)
	_cockpit.close_active_modal()
	await process_frame

	var m0_order: OrderDefinition = _registry.find_order(M0_ORDER_ID)
	_check(_game_state.accept_order(m0_order), "M0 navigation fixture could not accept.")
	_check(
		_cockpit.activate_hotspot(&"navigation_screen"),
		"Active M0 navigation could not open."
	)
	await process_frame
	var active_text: String = _cockpit.get_device_panel_body()
	_check(
		active_text.contains(tr("ORDER_RED_SAND_M0_NAME"))
		and active_text.contains(tr("PLANET_RED_SAND_NAME"))
		and active_text.contains(tr("UI_COCKPIT_NAV_CONTENT_PLAYABLE"))
		and active_text.contains(tr("MODULE_STANDARD_DRIVE_NAME"))
		and active_text.contains(tr("UI_COCKPIT_NAV_ROUTE_PENDING"))
		and not _cockpit.is_navigation_action_enabled(),
		"Active M0 navigation is missing destination, route, module, or preflight state."
	)
	_cockpit.close_active_modal()
	_check(
		_game_state.confirm_departure(m0_order),
		"M0 navigation fixture could not confirm preflight."
	)
	_check(
		_cockpit.activate_hotspot(&"navigation_screen"),
		"Confirmed M0 navigation could not reopen."
	)
	await process_frame
	_check(
		_cockpit.is_navigation_action_enabled()
		and _cockpit.get_device_panel_body().contains(
			tr("UI_COCKPIT_NAV_ROUTE_READY")
		),
		"Confirmed M0 route did not enable the one active destination."
	)
	var planet_entries: Array[M1PlanetCatalogEntry] = (
		M1CatalogModel.build_navigation_catalog(_registry, _game_state)
	)
	var selectable_count: int = 0
	for entry: M1PlanetCatalogEntry in planet_entries:
		if entry.is_departure_selectable:
			selectable_count += 1
			_check(
				entry.planet_id == M1ProgressRules.PLANET_RED_SAND,
				"Navigation enabled a destination outside the active M0 order."
			)
	_check(selectable_count == 1, "Confirmed M0 must expose exactly one destination.")
	_cockpit.close_active_modal()
	await process_frame

	_game_state.reset_runtime_state()
	var registered_order: OrderDefinition = _registry.find_order(
		REGISTERED_ORDER_ID
	)
	_force_active_order(registered_order)
	_check(
		_cockpit.activate_hotspot(&"navigation_screen"),
		"Registered-order navigation fixture could not open."
	)
	await process_frame
	_check(
		not _cockpit.is_navigation_action_enabled()
		and _cockpit.get_device_panel_body().contains(
			tr("UI_CATALOG_HINT_REGISTERED_ONLY")
		)
		and not _cockpit.get_device_panel_body().contains("registered_only")
		and not _cockpit.start_configured_travel()
		and _game_state.last_travel_error
		== GameStateModel.TRAVEL_ERROR_ORDER_REGISTERED_ONLY,
		"Registered-only order did not show a localized hard departure guard."
	)
	_cockpit.close_active_modal()
	await process_frame

	var fixture_order: OrderDefinition = m0_order.duplicate(true) as OrderDefinition
	fixture_order.required_modules.append(
		_registry.find_module(M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING)
	)
	var fixture_registry: GameDataRegistry = _registry_with_order(fixture_order)
	_game_state.reset_runtime_state()
	_check(
		_game_state.accept_order(fixture_order),
		"Missing-module navigation fixture could not accept."
	)
	_cockpit.set_data_registry(fixture_registry)
	_check(
		_cockpit.activate_hotspot(&"navigation_screen"),
		"Missing-module navigation fixture could not open."
	)
	await process_frame
	_check(
		not _cockpit.is_navigation_action_enabled()
		and _cockpit.get_device_panel_body().contains(
			tr("MODULE_HIGH_VOLTAGE_SHIELDING_NAME")
		)
		and _cockpit.get_device_panel_body().contains(
			tr("UI_CATALOG_HINT_HIGH_VOLTAGE")
		),
		"Missing required module did not show its name, state, and acquisition path."
	)

	await _cleanup()
	_finish()


func _force_active_order(order: OrderDefinition) -> void:
	_game_state.current_order_id = order.id
	_game_state.destination_id = order.planet_id
	_game_state.cargo_id = order.cargo.id
	_game_state.order_states[order.id] = GameStateModel.OrderStatus.ACCEPTED


func _registry_with_order(order_fixture: OrderDefinition) -> GameDataRegistry:
	var registry: GameDataRegistry = GameDataRegistry.new()
	registry.registry_id = &"test_m1_navigation_fixture"
	registry.planets = _registry.planets.duplicate()
	for order: OrderDefinition in _registry.orders:
		registry.orders.append(
			order_fixture if order.id == order_fixture.id else order
		)
	registry.cargo_items = _registry.cargo_items.duplicate()
	registry.modules = _registry.modules.duplicate()
	registry.characters = _registry.characters.duplicate()
	registry.codex_entries = _registry.codex_entries.duplicate()
	registry.souvenirs = _registry.souvenirs.duplicate()
	registry.order_aliases = _registry.order_aliases.duplicate()
	return registry


func _cleanup() -> void:
	if _cockpit != null and is_instance_valid(_cockpit):
		_cockpit.queue_free()
		await process_frame
	_game_state.reset_runtime_state()
	TranslationServer.set_locale(_original_locale)


func _finish() -> void:
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[m1-catalog-navigation] PASS: no-order, M0 destination, registered content, "
			+ "required-module path, known beacons, and 640x360 layout."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[m1-catalog-navigation] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
