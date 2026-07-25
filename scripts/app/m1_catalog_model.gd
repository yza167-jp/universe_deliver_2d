class_name M1CatalogModel
extends RefCounted

## Stateless query model shared by the station order terminal and cockpit navigation.

enum ModuleInstallState {
	INSTALLED,
	OWNED_NOT_INSTALLED,
	NOT_OBTAINED,
}

const M0_ORDER_ID: StringName = &"order_red_sand_m0"
const BASE_OWNED_MODULE_IDS: Array[StringName] = [
	ShipLoadoutRules.DEFAULT_POWER_MODULE_ID,
	ShipLoadoutRules.DEFAULT_DEFENSE_MODULE_ID,
	ShipLoadoutRules.LASER_MODULE_ID,
	ShipLoadoutRules.SHIELD_BACKUP_POWER_MODULE_ID,
]


static func build_order_catalog(
	registry: GameDataRegistry,
	game_state: GameStateModel,
	include_hidden: bool = false
) -> Array[M1OrderCatalogEntry]:
	var entries: Array[M1OrderCatalogEntry] = []
	if registry == null or game_state == null:
		return entries
	var current_mainline_id: StringName = _find_current_mainline_id(
		registry,
		game_state
	)
	var next_clue_id: StringName = &""
	if current_mainline_id.is_empty():
		next_clue_id = _find_next_mainline_id(registry, game_state)
	elif game_state.current_order_id == current_mainline_id:
		next_clue_id = _find_next_mainline_id(
			registry,
			game_state,
			current_mainline_id
		)
	for order: OrderDefinition in registry.orders:
		if order == null:
			continue
		var entry: M1OrderCatalogEntry = _build_order_entry(
			order,
			game_state,
			current_mainline_id,
			next_clue_id
		)
		if include_hidden and not entry.is_visible:
			entry.is_visible = true
			entry.is_selectable = true
		entries.append(entry)
	return _sort_order_entries(entries)


static func build_single_order_entry(
	order: OrderDefinition,
	game_state: GameStateModel
) -> M1OrderCatalogEntry:
	if order == null or game_state == null:
		return null
	return _build_order_entry(order, game_state, order.id, &"")


static func get_visible_order_entries(
	registry: GameDataRegistry,
	game_state: GameStateModel
) -> Array[M1OrderCatalogEntry]:
	var visible_entries: Array[M1OrderCatalogEntry] = []
	for entry: M1OrderCatalogEntry in build_order_catalog(registry, game_state):
		if entry.is_visible:
			visible_entries.append(entry)
	return visible_entries


static func build_navigation_catalog(
	registry: GameDataRegistry,
	game_state: GameStateModel
) -> Array[M1PlanetCatalogEntry]:
	var entries: Array[M1PlanetCatalogEntry] = []
	if registry == null or game_state == null:
		return entries
	var order_entries: Array[M1OrderCatalogEntry] = build_order_catalog(
		registry,
		game_state
	)
	var active_order: OrderDefinition = registry.find_order(
		game_state.current_order_id
	)
	for planet: PlanetDefinition in registry.planets:
		if planet == null:
			continue
		var entry: M1PlanetCatalogEntry = M1PlanetCatalogEntry.new()
		entry.planet = planet
		entry.planet_id = planet.id
		entry.is_current_destination = (
			not game_state.current_order_id.is_empty()
			and game_state.destination_id == planet.id
		)
		entry.is_progression_unlocked = game_state.is_planet_unlocked(planet.id)
		entry.is_content_playable = _is_planet_route_playable(planet)
		entry.is_discovered = _is_planet_discovered(
			planet.id,
			entry.is_current_destination,
			entry.is_progression_unlocked,
			order_entries,
			game_state
		)
		entry.is_name_disclosed = entry.is_discovered
		_populate_planet_lock(entry, active_order, game_state)
		entries.append(entry)
	return entries


static func get_module_install_state(
	module: ShipModuleDefinition,
	game_state: GameStateModel
) -> ModuleInstallState:
	if module == null or game_state == null:
		return ModuleInstallState.NOT_OBTAINED
	if game_state.is_ship_module_equipped(module.id):
		return ModuleInstallState.INSTALLED
	if (
		BASE_OWNED_MODULE_IDS.has(module.id)
		or game_state.ship_upgrade_ids.has(module.id)
	):
		return ModuleInstallState.OWNED_NOT_INSTALLED
	return ModuleInstallState.NOT_OBTAINED


static func get_module_state_key(state: ModuleInstallState) -> StringName:
	match state:
		ModuleInstallState.INSTALLED:
			return &"UI_CATALOG_MODULE_INSTALLED"
		ModuleInstallState.OWNED_NOT_INSTALLED:
			return &"UI_CATALOG_MODULE_OWNED"
	return &"UI_CATALOG_MODULE_NOT_OBTAINED"


static func _build_order_entry(
	order: OrderDefinition,
	game_state: GameStateModel,
	current_mainline_id: StringName,
	next_clue_id: StringName
) -> M1OrderCatalogEntry:
	var entry: M1OrderCatalogEntry = M1OrderCatalogEntry.new()
	entry.order = order
	entry.order_id = order.id
	entry.order_type = order.order_type
	entry.status = game_state.get_order_status(order.id)
	entry.destination = order.destination_planet
	entry.is_express = order.is_express
	entry.content_playable = order.is_playable()
	entry.destination_playable = (
		order.destination_planet != null
		and _is_planet_route_playable(order.destination_planet)
	)
	entry.required_modules = order.required_modules.duplicate()
	entry.recommended_modules = order.recommended_modules.duplicate()

	if entry.status == GameStateModel.OrderStatus.ACCEPTED:
		entry.display_category = M1OrderCatalogEntry.DisplayCategory.CURRENT_ACCEPTED
		entry.is_visible = true
	elif entry.status in [
		GameStateModel.OrderStatus.COMPLETED,
		GameStateModel.OrderStatus.ARCHIVED,
	]:
		entry.display_category = M1OrderCatalogEntry.DisplayCategory.HISTORY
		entry.is_visible = true
	elif order.id == current_mainline_id:
		entry.display_category = M1OrderCatalogEntry.DisplayCategory.CURRENT_MAINLINE
		entry.is_visible = true
	elif order.order_type == OrderDefinition.OrderType.SIDE:
		entry.display_category = M1OrderCatalogEntry.DisplayCategory.OPTIONAL
		entry.is_visible = _is_side_order_discovered(order, game_state)
	elif order.id == next_clue_id:
		entry.display_category = M1OrderCatalogEntry.DisplayCategory.NEXT_CLUE
		entry.is_visible = true

	entry.is_selectable = (
		entry.is_visible
		and entry.display_category != M1OrderCatalogEntry.DisplayCategory.HISTORY
	)
	entry.is_name_disclosed = (
		entry.is_visible
		and entry.display_category != M1OrderCatalogEntry.DisplayCategory.NEXT_CLUE
		and (
			order.id == M0_ORDER_ID
			or entry.status == GameStateModel.OrderStatus.ACCEPTED
			or game_state.is_planet_unlocked(order.planet_id)
		)
	)
	var acceptance_error: StringName = game_state.get_order_acceptance_error(order)
	if entry.status == GameStateModel.OrderStatus.COMPLETED:
		acceptance_error = GameStateModel.ORDER_ERROR_ALREADY_COMPLETED
	elif entry.status == GameStateModel.OrderStatus.ARCHIVED:
		acceptance_error = GameStateModel.ORDER_ERROR_ARCHIVED
	elif entry.status == GameStateModel.OrderStatus.ACCEPTED:
		acceptance_error = GameStateModel.ORDER_ERROR_ALREADY_ACCEPTED
	entry.accept_enabled = (
		entry.is_selectable
		and entry.status == GameStateModel.OrderStatus.AVAILABLE
		and acceptance_error.is_empty()
	)
	entry.lock_reason = acceptance_error
	if not acceptance_error.is_empty():
		var reference_id: StringName = (
			M1CatalogHintResolver.get_order_gate_reference(
				order,
				acceptance_error
			)
		)
		entry.lock_hint_key = M1CatalogHintResolver.get_hint_key(
			acceptance_error,
			reference_id
		)
	return entry


static func _find_current_mainline_id(
	registry: GameDataRegistry,
	game_state: GameStateModel
) -> StringName:
	for order: OrderDefinition in registry.orders:
		if order == null or not order.is_mainline():
			continue
		var status: GameStateModel.OrderStatus = game_state.get_order_status(order.id)
		if status == GameStateModel.OrderStatus.ACCEPTED:
			return order.id
		if status in [
			GameStateModel.OrderStatus.COMPLETED,
			GameStateModel.OrderStatus.ARCHIVED,
		]:
			continue
		if (
			order.required_chapter.is_empty()
			or M1ProgressRules.has_reached_chapter(
				game_state.main_story_chapter,
				order.required_chapter
			)
		):
			return order.id
	return &""


static func _sort_order_entries(
	entries: Array[M1OrderCatalogEntry]
) -> Array[M1OrderCatalogEntry]:
	var sorted_entries: Array[M1OrderCatalogEntry] = []
	var category_order: Array[M1OrderCatalogEntry.DisplayCategory] = [
		M1OrderCatalogEntry.DisplayCategory.CURRENT_ACCEPTED,
		M1OrderCatalogEntry.DisplayCategory.CURRENT_MAINLINE,
		M1OrderCatalogEntry.DisplayCategory.OPTIONAL,
		M1OrderCatalogEntry.DisplayCategory.NEXT_CLUE,
		M1OrderCatalogEntry.DisplayCategory.HISTORY,
		M1OrderCatalogEntry.DisplayCategory.HIDDEN,
	]
	for category: M1OrderCatalogEntry.DisplayCategory in category_order:
		for entry: M1OrderCatalogEntry in entries:
			if entry.display_category == category:
				sorted_entries.append(entry)
	return sorted_entries


static func _find_next_mainline_id(
	registry: GameDataRegistry,
	game_state: GameStateModel,
	excluded_order_id: StringName = &""
) -> StringName:
	for order: OrderDefinition in registry.orders:
		if (
			order == null
			or not order.is_mainline()
			or order.id == excluded_order_id
		):
			continue
		if game_state.get_order_status(order.id) in [
			GameStateModel.OrderStatus.COMPLETED,
			GameStateModel.OrderStatus.ARCHIVED,
		]:
			continue
		return order.id
	return &""


static func _is_side_order_discovered(
	order: OrderDefinition,
	game_state: GameStateModel
) -> bool:
	if order == null:
		return false
	var status: GameStateModel.OrderStatus = game_state.get_order_status(order.id)
	if status != GameStateModel.OrderStatus.AVAILABLE:
		return true
	return (
		M1ProgressRules.has_reached_chapter(
			game_state.main_story_chapter,
			order.required_chapter
		)
		and (
			game_state.is_planet_unlocked(order.planet_id)
			or game_state.destination_id == order.planet_id
		)
	)


static func _is_planet_discovered(
	planet_id: StringName,
	is_current_destination: bool,
	is_progression_unlocked: bool,
	order_entries: Array[M1OrderCatalogEntry],
	game_state: GameStateModel
) -> bool:
	if is_current_destination or is_progression_unlocked:
		return true
	for order_entry: M1OrderCatalogEntry in order_entries:
		if (
			order_entry.destination != null
			and order_entry.destination.id == planet_id
			and order_entry.is_visible
			and order_entry.is_name_disclosed
		):
			return true
	for order_id: StringName in game_state.completed_order_ids:
		if (
			game_state.completed_order_ids.get(order_id, false)
			and order_id == M0_ORDER_ID
			and planet_id == M1ProgressRules.PLANET_RED_SAND
		):
			return true
	return false


static func _populate_planet_lock(
	entry: M1PlanetCatalogEntry,
	active_order: OrderDefinition,
	game_state: GameStateModel
) -> void:
	if not entry.is_current_destination:
		entry.lock_reason = (
			M1CatalogHintResolver.REASON_NO_ACTIVE_ORDER
			if active_order == null
			else GameStateModel.TRAVEL_ERROR_DESTINATION_NOT_ALLOWED
		)
	elif active_order == null:
		entry.lock_reason = M1CatalogHintResolver.REASON_NO_ACTIVE_ORDER
	else:
		var loadout_error: StringName = (
			game_state.get_departure_confirmation_error(active_order)
		)
		if not loadout_error.is_empty():
			entry.lock_reason = loadout_error
		else:
			entry.lock_reason = game_state.get_travel_start_error(
				active_order,
				entry.planet_id
			)
	entry.is_departure_selectable = (
		entry.is_current_destination
		and active_order != null
		and entry.lock_reason.is_empty()
	)
	if entry.lock_reason.is_empty():
		return
	var reference_id: StringName = &""
	if (
		entry.lock_reason
		== GameStateModel.LOADOUT_ERROR_MISSING_REQUIRED_MODULES
		and active_order != null
	):
		var missing_modules: Array[ShipModuleDefinition] = (
			game_state.get_missing_required_modules(active_order)
		)
		if not missing_modules.is_empty() and missing_modules[0] != null:
			reference_id = missing_modules[0].id
	entry.lock_hint_key = M1CatalogHintResolver.get_hint_key(
		entry.lock_reason,
		reference_id
	)


static func _is_planet_route_playable(planet: PlanetDefinition) -> bool:
	return (
		planet != null
		and planet.is_playable()
		and not planet.flight_scene_path.is_empty()
		and ResourceLoader.exists(planet.flight_scene_path)
	)
