class_name CockpitNavigationPanel
extends VBoxContainer

@onready var _order_label: Label = %NavigationOrderLabel
@onready var _destination_label: Label = %NavigationDestinationLabel
@onready var _unlock_label: Label = %NavigationUnlockLabel
@onready var _content_label: Label = %NavigationContentLabel
@onready var _required_modules_label: Label = %NavigationRequiredModulesLabel
@onready var _configuration_label: Label = %NavigationConfigurationLabel
@onready var _route_label: Label = %NavigationRouteLabel
@onready var _known_planets_label: Label = %NavigationKnownPlanetsLabel

var _registry: GameDataRegistry
var _game_state: GameStateModel
var _active_order: OrderDefinition
var _current_planet_entry: M1PlanetCatalogEntry
var _departure_enabled: bool = false


func configure(
	registry: GameDataRegistry,
	game_state: GameStateModel
) -> void:
	_registry = registry
	_game_state = game_state
	if is_node_ready():
		refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	_active_order = null
	_current_planet_entry = null
	_departure_enabled = false
	if _registry != null and _game_state != null:
		_active_order = _registry.find_order(_game_state.current_order_id)
		for entry: M1PlanetCatalogEntry in M1CatalogModel.build_navigation_catalog(
			_registry,
			_game_state
		):
			if entry.is_current_destination:
				_current_planet_entry = entry
				break
	_refresh_order_and_destination()
	_refresh_requirements()
	_refresh_route()
	_refresh_known_planets()


func get_active_order() -> OrderDefinition:
	return _active_order


func get_current_planet_entry() -> M1PlanetCatalogEntry:
	return _current_planet_entry


func is_departure_enabled() -> bool:
	return _departure_enabled


func get_summary_text() -> String:
	var lines: PackedStringArray = []
	for label: Label in [
		_order_label,
		_destination_label,
		_unlock_label,
		_content_label,
		_required_modules_label,
		_configuration_label,
		_route_label,
		_known_planets_label,
	]:
		if label != null and not label.text.is_empty():
			lines.append(label.text)
	return "\n".join(lines)


func _refresh_order_and_destination() -> void:
	if _active_order == null:
		_order_label.text = tr("UI_COCKPIT_NAV_NO_ORDER")
		_destination_label.text = tr("UI_COCKPIT_NAV_DESTINATION_UNSET")
		_unlock_label.text = tr("UI_COCKPIT_NAV_UNLOCK_FORMAT") % tr(
			"UI_COCKPIT_NAV_LOCKED"
		)
		_content_label.text = tr("UI_COCKPIT_NAV_CONTENT_FORMAT") % tr(
			"UI_COCKPIT_NAV_CONTENT_REGISTERED"
		)
		return
	_order_label.text = tr("UI_COCKPIT_NAV_ORDER_FORMAT") % tr(
		String(_active_order.display_name_key)
	)
	var destination_name: String = tr("UI_COCKPIT_VALUE_UNAVAILABLE")
	if _active_order.destination_planet != null:
		destination_name = tr(
			String(_active_order.destination_planet.display_name_key)
		)
	_destination_label.text = tr("UI_COCKPIT_NAV_DESTINATION_FORMAT") % (
		destination_name
	)
	var route_authorized: bool = (
		_current_planet_entry != null
		and (
			_current_planet_entry.is_progression_unlocked
			or _active_order.id == M1CatalogModel.M0_ORDER_ID
		)
	)
	_unlock_label.text = tr("UI_COCKPIT_NAV_UNLOCK_FORMAT") % tr(
		"UI_COCKPIT_NAV_UNLOCKED"
		if route_authorized
		else "UI_COCKPIT_NAV_LOCKED"
	)
	_content_label.text = tr("UI_COCKPIT_NAV_CONTENT_FORMAT") % tr(
		"UI_COCKPIT_NAV_CONTENT_PLAYABLE"
		if (
			_current_planet_entry != null
			and _current_planet_entry.is_content_playable
			and _active_order.is_playable()
		)
		else "UI_COCKPIT_NAV_CONTENT_REGISTERED"
	)


func _refresh_requirements() -> void:
	if _active_order == null:
		_required_modules_label.text = tr(
			"UI_COCKPIT_NAV_REQUIRED_MODULES_FORMAT"
		) % tr("UI_COCKPIT_NAV_NO_REQUIRED_MODULES")
		_configuration_label.text = tr(
			"UI_COCKPIT_NAV_CONFIGURATION_FORMAT"
		) % tr("UI_COCKPIT_NAV_NO_REQUIRED_MODULES")
		return
	var required_entries: PackedStringArray = []
	for module: ShipModuleDefinition in _active_order.required_modules:
		if module == null:
			continue
		var state: M1CatalogModel.ModuleInstallState = (
			M1CatalogModel.get_module_install_state(module, _game_state)
		)
		required_entries.append(
			tr("UI_COCKPIT_NAV_MODULE_STATE_FORMAT") % [
				tr(String(module.display_name_key)),
				tr(String(M1CatalogModel.get_module_state_key(state))),
			]
		)
	_required_modules_label.text = tr(
		"UI_COCKPIT_NAV_REQUIRED_MODULES_FORMAT"
	) % (
		tr("UI_COCKPIT_NAV_NO_REQUIRED_MODULES")
		if required_entries.is_empty()
		else tr("UI_COCKPIT_NAV_LIST_SEPARATOR").join(required_entries)
	)
	var installed_entries: PackedStringArray = []
	if _game_state != null and _registry != null:
		for slot_id: StringName in ShipLoadoutRules.SLOT_ORDER:
			var module_id: StringName = _game_state.ship_configuration.get(
				slot_id,
				&""
			)
			var module: ShipModuleDefinition = _registry.find_module(module_id)
			if module != null:
				installed_entries.append(tr(String(module.display_name_key)))
	_configuration_label.text = tr(
		"UI_COCKPIT_NAV_CONFIGURATION_FORMAT"
	) % (
		tr("UI_COCKPIT_NAV_NO_REQUIRED_MODULES")
		if installed_entries.is_empty()
		else tr("UI_COCKPIT_NAV_LIST_SEPARATOR").join(installed_entries)
	)


func _refresh_route() -> void:
	if _active_order == null or _current_planet_entry == null:
		_route_label.text = tr("UI_COCKPIT_NAV_ROUTE_NO_ORDER")
		return
	_departure_enabled = _current_planet_entry.is_departure_selectable
	var reason: StringName = _current_planet_entry.lock_reason
	match reason:
		&"":
			_route_label.text = tr("UI_COCKPIT_NAV_ROUTE_READY")
		GameStateModel.TRAVEL_ERROR_DEPARTURE_NOT_CONFIRMED:
			_route_label.text = tr("UI_COCKPIT_NAV_ROUTE_PENDING")
		GameStateModel.TRAVEL_ERROR_ALREADY_STARTED:
			_route_label.text = tr("UI_COCKPIT_NAV_ROUTE_ACTIVE")
		&"already_completed":
			_route_label.text = tr("UI_COCKPIT_NAV_ROUTE_COMPLETED")
		_:
			_route_label.text = tr("UI_COCKPIT_NAV_LOCK_FORMAT") % tr(
				String(_current_planet_entry.lock_hint_key)
			)


func _refresh_known_planets() -> void:
	var lines: PackedStringArray = [
		tr("UI_COCKPIT_NAV_KNOWN_PLANETS_HEADING"),
	]
	if _registry == null or _game_state == null:
		lines.append(tr("UI_COCKPIT_NAV_PLANET_UNKNOWN"))
		_known_planets_label.text = "\n".join(lines)
		return
	for entry: M1PlanetCatalogEntry in M1CatalogModel.build_navigation_catalog(
		_registry,
		_game_state
	):
		if not entry.is_name_disclosed or entry.planet == null:
			lines.append(tr("UI_COCKPIT_NAV_PLANET_UNKNOWN"))
			continue
		var state_text: String = tr(
			"UI_COCKPIT_NAV_PLANET_CURRENT_SUFFIX"
			if entry.is_current_destination
			else (
				"UI_COCKPIT_NAV_PLANET_UNLOCKED_SUFFIX"
				if entry.is_progression_unlocked
				else "UI_COCKPIT_NAV_PLANET_LOCKED_SUFFIX"
			)
		)
		lines.append(
			tr("UI_COCKPIT_NAV_PLANET_KNOWN_FORMAT") % [
				tr(String(entry.planet.display_name_key)),
				state_text,
			]
		)
	_known_planets_label.text = "\n".join(lines)
