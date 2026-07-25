extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const LOCALIZATION_PATH: String = "res://data/localization/game_text.csv"
const M0_ORDER_ID: StringName = &"order_red_sand_m0"
const REVISIT_ORDER_ID: StringName = (
	&"order_m1_red_sand_shielding_retrofit"
)
const WHITE_MAIN_ORDER_ID: StringName = &"order_m1_white_noise_archive_core"
const WHITE_SIDE_ORDER_ID: StringName = &"side_white_noise_returned_memory"


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	expect_true(registry != null, "T-105 catalog registry must load.", failures)
	if registry == null:
		return failures
	_test_new_game_catalog(registry, failures)
	_test_completed_history_and_current_revisit(registry, failures)
	_test_optional_discovery(registry, failures)
	_test_active_order_priority(registry, failures)
	_test_registered_only_debug_query(registry, failures)
	_test_hint_resolution(registry, failures)
	_test_navigation_guards(registry, failures)
	return failures


func _test_new_game_catalog(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var entries: Array[M1OrderCatalogEntry] = (
		M1CatalogModel.build_order_catalog(registry, game_state)
	)
	var visible_entries: Array[M1OrderCatalogEntry] = _visible(entries)
	expect_true(
		visible_entries.size() == 1
		and visible_entries[0].order_id == M0_ORDER_ID
		and visible_entries[0].accept_enabled,
		"New Game must expose exactly one acceptable M0 order.",
		failures
	)
	expect_true(
		_count_order(entries, M0_ORDER_ID) == 1
		and _count_order(entries, &"order_red_sand_cooling_core") == 0,
		"The M0 compatibility alias must not create a second catalog entry.",
		failures
	)
	expect_true(
		_count_category(
			entries,
			M1OrderCatalogEntry.DisplayCategory.CURRENT_MAINLINE
		) == 1,
		"Only one current mainline or revisit may be highlighted.",
		failures
	)
	for entry: M1OrderCatalogEntry in entries:
		if entry.order_type == OrderDefinition.OrderType.SIDE:
			expect_true(
				not entry.is_visible and not entry.is_name_disclosed,
				"Undiscovered side orders must neither appear nor disclose names.",
				failures
			)
	expect_true(
		registry.find_order(&"side_red_sand_unlisted_filters") == null,
		"Stretch Red Sand side content must remain outside the active catalog.",
		failures
	)
	game_state.free()


func _test_completed_history_and_current_revisit(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	game_state.completed_order_ids[M0_ORDER_ID] = true
	game_state.order_states[M0_ORDER_ID] = GameStateModel.OrderStatus.COMPLETED
	game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	game_state.unlocked_planet_ids.append(M1ProgressRules.PLANET_RED_SAND)
	game_state.set_story_flag(&"story_red_sand_order_completed")
	var entries: Array[M1OrderCatalogEntry] = (
		M1CatalogModel.build_order_catalog(registry, game_state)
	)
	var m0_entry: M1OrderCatalogEntry = _find(entries, M0_ORDER_ID)
	var revisit_entry: M1OrderCatalogEntry = _find(entries, REVISIT_ORDER_ID)
	expect_true(
		m0_entry != null
		and m0_entry.is_history()
		and not m0_entry.accept_enabled
		and revisit_entry != null
		and revisit_entry.display_category
		== M1OrderCatalogEntry.DisplayCategory.CURRENT_MAINLINE,
		"Completed M0 must move to history while the revisit becomes the single current lead.",
		failures
	)
	expect_true(
		revisit_entry != null
		and revisit_entry.content_playable
		and revisit_entry.lock_reason.is_empty()
		and revisit_entry.accept_enabled,
		"The completed M0 state must expose the playable revisit.",
		failures
	)
	game_state.order_states[WHITE_SIDE_ORDER_ID] = GameStateModel.OrderStatus.ARCHIVED
	entries = M1CatalogModel.build_order_catalog(registry, game_state)
	expect_true(
		_find(entries, WHITE_SIDE_ORDER_ID).is_history(),
		"Completed and archived orders must share the compact history category.",
		failures
	)
	game_state.free()


func _test_optional_discovery(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	game_state.unlocked_planet_ids.append(M1ProgressRules.PLANET_RED_SAND)
	game_state.unlocked_planet_ids.append(M1ProgressRules.PLANET_WHITE_NOISE)
	game_state.planet_permission_ids.append(
		M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
	)
	for completed_id: StringName in [
		M0_ORDER_ID,
		REVISIT_ORDER_ID,
		WHITE_MAIN_ORDER_ID,
	]:
		game_state.completed_order_ids[completed_id] = true
		game_state.order_states[completed_id] = GameStateModel.OrderStatus.COMPLETED
	game_state.set_story_flag(&"story_m1_white_noise_archive_core_completed")
	var entries: Array[M1OrderCatalogEntry] = (
		M1CatalogModel.build_order_catalog(registry, game_state)
	)
	var side_entry: M1OrderCatalogEntry = _find(entries, WHITE_SIDE_ORDER_ID)
	expect_true(
		side_entry != null
		and side_entry.is_visible
		and side_entry.is_name_disclosed
		and side_entry.display_category
		== M1OrderCatalogEntry.DisplayCategory.OPTIONAL,
		"A discovered optional order must appear only after its chapter and planet are known.",
		failures
	)
	expect_true(
		_count_category(
			entries,
			M1OrderCatalogEntry.DisplayCategory.CURRENT_MAINLINE
		) <= 1,
		"Optional visibility must not create multiple current-main highlights.",
		failures
	)
	game_state.free()


func _test_active_order_priority(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var m0_order: OrderDefinition = registry.find_order(M0_ORDER_ID)
	expect_true(game_state.accept_order(m0_order), "M0 active fixture must accept.", failures)
	var entries: Array[M1OrderCatalogEntry] = (
		M1CatalogModel.build_order_catalog(registry, game_state, true)
	)
	expect_true(
		not entries.is_empty()
		and entries[0].order_id == M0_ORDER_ID
		and entries[0].display_category
		== M1OrderCatalogEntry.DisplayCategory.CURRENT_ACCEPTED
		and _count_category(
			entries,
			M1OrderCatalogEntry.DisplayCategory.CURRENT_ACCEPTED
		) == 1,
		"The one active order must be the first catalog entry.",
		failures
	)
	var other_entry: M1OrderCatalogEntry = _find(entries, REVISIT_ORDER_ID)
	expect_true(
		other_entry != null
		and other_entry.lock_reason == GameStateModel.ORDER_ERROR_ACTIVE_ORDER
		and other_entry.lock_hint_key == &"UI_CATALOG_HINT_ACTIVE_ORDER",
		"Other entries must explain the one-active-order rule.",
		failures
	)
	expect_true(
		not game_state.accept_order(registry.find_order(REVISIT_ORDER_ID))
		and game_state.current_order_id == M0_ORDER_ID,
		"A second catalog order must never replace the active order.",
		failures
	)
	game_state.free()


func _test_registered_only_debug_query(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	game_state.unlocked_planet_ids.append(M1ProgressRules.PLANET_RED_SAND)
	game_state.completed_order_ids[M0_ORDER_ID] = true
	game_state.order_states[M0_ORDER_ID] = GameStateModel.OrderStatus.COMPLETED
	game_state.set_story_flag(&"story_red_sand_order_completed")
	var before: String = JSON.stringify(
		GameProgressData.capture(game_state).to_dictionary()
	)
	var entries: Array[M1OrderCatalogEntry] = (
		M1CatalogModel.build_order_catalog(registry, game_state, true)
	)
	var revisit_entry: M1OrderCatalogEntry = _find(entries, REVISIT_ORDER_ID)
	var after: String = JSON.stringify(
		GameProgressData.capture(game_state).to_dictionary()
	)
	expect_true(
		revisit_entry != null
		and revisit_entry.content_playable
		and revisit_entry.lock_reason.is_empty()
		and revisit_entry.accept_enabled
		and before == after,
		"Debug catalog queries must expose playable revisit content without mutating progress.",
		failures
	)
	expect_true(
		game_state.accept_order(registry.find_order(REVISIT_ORDER_ID)),
		"The authoritative accept path must accept the completed playable revisit gate.",
		failures
	)
	game_state.free()


func _test_hint_resolution(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var source: OrderDefinition = registry.find_order(M0_ORDER_ID)
	var chapter_order: OrderDefinition = source.duplicate(true) as OrderDefinition
	chapter_order.id = &"order_catalog_chapter_fixture"
	chapter_order.required_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	var chapter_reason: StringName = game_state.get_order_acceptance_error(
		chapter_order
	)
	expect_true(
		chapter_reason == M1ProgressRules.REASON_REQUIRED_CHAPTER
		and M1CatalogHintResolver.get_hint_key(chapter_reason)
		== &"UI_CATALOG_HINT_PREVIOUS_MAIN",
		"Missing chapters must resolve to the previous-main acquisition hint.",
		failures
	)

	var module_order: OrderDefinition = source.duplicate(true) as OrderDefinition
	module_order.id = &"order_catalog_module_fixture"
	var module_condition: OrderUnlockCondition = OrderUnlockCondition.new()
	module_condition.condition_type = (
		OrderUnlockCondition.ConditionType.MODULE_AVAILABLE
	)
	module_condition.reference_id = M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
	module_order.unlock_conditions = [module_condition]
	var module_reason: StringName = game_state.get_order_acceptance_error(
		module_order
	)
	expect_true(
		module_reason == M1ProgressRules.REASON_REQUIRED_MODULE
		and M1CatalogHintResolver.get_hint_key(
			module_reason,
			module_condition.reference_id
		) == &"UI_CATALOG_HINT_HIGH_VOLTAGE",
		"Missing high-voltage shielding must resolve to its concrete acquisition path.",
		failures
	)

	var permission_order: OrderDefinition = source.duplicate(true) as OrderDefinition
	permission_order.id = &"order_catalog_permission_fixture"
	var permission_condition: OrderUnlockCondition = OrderUnlockCondition.new()
	permission_condition.condition_type = (
		OrderUnlockCondition.ConditionType.PERMISSION_GRANTED
	)
	permission_condition.reference_id = (
		M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
	)
	permission_order.unlock_conditions = [permission_condition]
	var permission_reason: StringName = game_state.get_order_acceptance_error(
		permission_order
	)
	expect_true(
		permission_reason == M1ProgressRules.REASON_REQUIRED_PERMISSION
		and M1CatalogHintResolver.get_hint_key(
			permission_reason,
			permission_condition.reference_id
		) == &"UI_CATALOG_HINT_WHITE_NOISE_ARCHIVE_PERMISSION",
		"Missing archive permission must resolve to the White Noise mainline path.",
		failures
	)

	var catalog: LocalizationCatalog = LocalizationCatalog.load_csv(
		LOCALIZATION_PATH
	)
	var hint_keys: Array[StringName] = [
		&"UI_CATALOG_HINT_PREVIOUS_MAIN",
		&"UI_CATALOG_HINT_HIGH_VOLTAGE",
		&"UI_CATALOG_HINT_WHITE_NOISE_ARCHIVE_PERMISSION",
		&"UI_CATALOG_HINT_ACTIVE_ORDER",
		&"UI_CATALOG_HINT_REGISTERED_ONLY",
		&"UI_CATALOG_HINT_PLANET_REGISTERED_ONLY",
		&"UI_CATALOG_HINT_MISSING_ROUTE",
		&"UI_CATALOG_HINT_NO_ACTIVE_ORDER",
		&"UI_CATALOG_HINT_DEPARTURE_NOT_CONFIRMED",
	]
	for hint_key: StringName in hint_keys:
		var zh_text: String = catalog.get_message(hint_key, &"zh_CN")
		var en_text: String = catalog.get_message(hint_key, &"en")
		expect_true(
			not zh_text.is_empty()
			and not en_text.is_empty()
			and not zh_text.contains("required_")
			and not zh_text.contains("registered_only"),
			"Catalog hint must be localized without exposing internal reason IDs: %s"
			% hint_key,
			failures
		)
	expect_true(
		catalog.get_message(&"UI_CATALOG_HINT_HIGH_VOLTAGE", &"zh_CN")
		== "完成赤砂星回访改装后获得"
		and catalog.get_message(
			&"UI_CATALOG_HINT_WHITE_NOISE_ARCHIVE_PERMISSION",
			&"zh_CN"
		) == "完成白噪星档案主线后获得",
		"Module and permission hints must state their concrete acquisition paths.",
		failures
	)
	game_state.free()


func _test_navigation_guards(
	source_registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var no_order_state: GameStateModel = GameStateModel.new()
	no_order_state.unlocked_planet_ids.append(M1ProgressRules.PLANET_RED_SAND)
	var no_order_entries: Array[M1PlanetCatalogEntry] = (
		M1CatalogModel.build_navigation_catalog(
			source_registry,
			no_order_state
		)
	)
	expect_true(
		_count_departure_selectable(no_order_entries) == 0
		and _find_planet(
			no_order_entries,
			M1ProgressRules.PLANET_RED_SAND
		).is_progression_unlocked,
		"An unlocked planet without an active order must not become free travel.",
		failures
	)
	expect_true(
		not _find_planet(
			no_order_entries,
			M1ProgressRules.PLANET_WHITE_NOISE
		).is_departure_selectable,
		"Story-locked planets must not become selectable.",
		failures
	)
	no_order_state.free()

	var active_state: GameStateModel = GameStateModel.new()
	var m0_order: OrderDefinition = source_registry.find_order(M0_ORDER_ID)
	expect_true(active_state.accept_order(m0_order), "Navigation M0 fixture must accept.", failures)
	var active_entries: Array[M1PlanetCatalogEntry] = (
		M1CatalogModel.build_navigation_catalog(
			source_registry,
			active_state
		)
	)
	var red_entry: M1PlanetCatalogEntry = _find_planet(
		active_entries,
		M1ProgressRules.PLANET_RED_SAND
	)
	expect_true(
		red_entry != null
		and red_entry.is_current_destination
		and not red_entry.is_departure_selectable
		and red_entry.lock_reason
		== GameStateModel.TRAVEL_ERROR_DEPARTURE_NOT_CONFIRMED
		and _count_departure_selectable(active_entries) == 0,
		"Only the active destination may be confirmed, and preflight must remain explicit.",
		failures
	)
	expect_true(
		active_state.confirm_departure(m0_order)
		and _find_planet(
			M1CatalogModel.build_navigation_catalog(
				source_registry,
				active_state
			),
			M1ProgressRules.PLANET_RED_SAND
		).is_departure_selectable,
		"Confirmed M0 preflight must make exactly its Red Sand destination selectable.",
		failures
	)
	active_state.free()

	var missing_order: OrderDefinition = (
		source_registry.find_order(M0_ORDER_ID).duplicate(true) as OrderDefinition
	)
	missing_order.required_modules.append(
		source_registry.find_module(
			M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
		)
	)
	var missing_registry: GameDataRegistry = _registry_with_fixture(
		source_registry,
		missing_order
	)
	var missing_state: GameStateModel = GameStateModel.new()
	expect_true(missing_state.accept_order(missing_order), "Missing-module fixture must accept.", failures)
	var missing_entry: M1PlanetCatalogEntry = _find_planet(
		M1CatalogModel.build_navigation_catalog(
			missing_registry,
			missing_state
		),
		M1ProgressRules.PLANET_RED_SAND
	)
	expect_true(
		missing_entry != null
		and not missing_entry.is_departure_selectable
		and missing_entry.lock_reason
		== GameStateModel.LOADOUT_ERROR_MISSING_REQUIRED_MODULES
		and missing_entry.lock_hint_key == &"UI_CATALOG_HINT_HIGH_VOLTAGE",
		"Missing required modules must block departure with the same acquisition path.",
		failures
	)
	missing_state.free()

	var registered_order: OrderDefinition = (
		source_registry.find_order(M0_ORDER_ID).duplicate(true) as OrderDefinition
	)
	registered_order.content_readiness = (
		OrderDefinition.ContentReadiness.REGISTERED_ONLY
	)
	var order_registry: GameDataRegistry = _registry_with_fixture(
		source_registry,
		registered_order
	)
	var registered_order_state: GameStateModel = GameStateModel.new()
	_force_active_order(registered_order_state, registered_order)
	expect_true(
		registered_order_state.get_departure_confirmation_error(registered_order)
		== GameStateModel.LOADOUT_ERROR_ORDER_REGISTERED_ONLY
		and not _find_planet(
			M1CatalogModel.build_navigation_catalog(
				order_registry,
				registered_order_state
			),
			M1ProgressRules.PLANET_RED_SAND
		).is_departure_selectable,
		"Registered-only orders must remain blocked even if a save contains an active ID.",
		failures
	)
	registered_order_state.free()

	var registered_planet: PlanetDefinition = (
		source_registry.find_planet(
			M1ProgressRules.PLANET_RED_SAND
		).duplicate(true) as PlanetDefinition
	)
	registered_planet.content_readiness = (
		PlanetDefinition.ContentReadiness.REGISTERED_ONLY
	)
	registered_planet.flight_scene_path = ""
	var planet_order: OrderDefinition = (
		source_registry.find_order(M0_ORDER_ID).duplicate(true) as OrderDefinition
	)
	planet_order.destination_planet = registered_planet
	var planet_registry: GameDataRegistry = _registry_with_fixture(
		source_registry,
		planet_order,
		registered_planet
	)
	var registered_planet_state: GameStateModel = GameStateModel.new()
	_force_active_order(registered_planet_state, planet_order)
	expect_true(
		registered_planet_state.get_departure_confirmation_error(planet_order)
		== GameStateModel.LOADOUT_ERROR_PLANET_REGISTERED_ONLY
		and not _find_planet(
			M1CatalogModel.build_navigation_catalog(
				planet_registry,
				registered_planet_state
			),
			M1ProgressRules.PLANET_RED_SAND
		).is_departure_selectable,
		"Registered-only planets must never become departure targets.",
		failures
	)
	registered_planet_state.free()

	var missing_route_planet: PlanetDefinition = (
		source_registry.find_planet(
			M1ProgressRules.PLANET_RED_SAND
		).duplicate(true) as PlanetDefinition
	)
	missing_route_planet.flight_scene_path = "res://scenes/missing_route.tscn"
	var missing_route_order: OrderDefinition = (
		source_registry.find_order(M0_ORDER_ID).duplicate(true) as OrderDefinition
	)
	missing_route_order.destination_planet = missing_route_planet
	var missing_route_registry: GameDataRegistry = _registry_with_fixture(
		source_registry,
		missing_route_order,
		missing_route_planet
	)
	var missing_route_state: GameStateModel = GameStateModel.new()
	_force_active_order(missing_route_state, missing_route_order)
	var missing_route_entry: M1PlanetCatalogEntry = _find_planet(
		M1CatalogModel.build_navigation_catalog(
			missing_route_registry,
			missing_route_state
		),
		M1ProgressRules.PLANET_RED_SAND
	)
	expect_true(
		missing_route_state.get_departure_confirmation_error(
			missing_route_order
		) == GameStateModel.LOADOUT_ERROR_MISSING_ROUTE
		and missing_route_entry != null
		and missing_route_entry.lock_hint_key
		== &"UI_CATALOG_HINT_MISSING_ROUTE",
		"A playable declaration with no real scene must fail through the missing-route guard.",
		failures
	)
	missing_route_state.free()


func _force_active_order(
	game_state: GameStateModel,
	order: OrderDefinition
) -> void:
	game_state.current_order_id = order.id
	game_state.destination_id = order.planet_id
	game_state.cargo_id = order.cargo.id
	game_state.order_states[order.id] = GameStateModel.OrderStatus.ACCEPTED


func _registry_with_fixture(
	source: GameDataRegistry,
	order_fixture: OrderDefinition,
	planet_fixture: PlanetDefinition = null
) -> GameDataRegistry:
	var registry: GameDataRegistry = GameDataRegistry.new()
	registry.registry_id = &"test_m1_catalog_fixture"
	for planet: PlanetDefinition in source.planets:
		registry.planets.append(
			planet_fixture
			if (
				planet_fixture != null
				and planet.id == planet_fixture.id
			)
			else planet
		)
	for order: OrderDefinition in source.orders:
		registry.orders.append(
			order_fixture if order.id == order_fixture.id else order
		)
	registry.cargo_items = source.cargo_items.duplicate()
	registry.modules = source.modules.duplicate()
	registry.characters = source.characters.duplicate()
	registry.codex_entries = source.codex_entries.duplicate()
	registry.souvenirs = source.souvenirs.duplicate()
	registry.order_aliases = source.order_aliases.duplicate()
	return registry


func _visible(
	entries: Array[M1OrderCatalogEntry]
) -> Array[M1OrderCatalogEntry]:
	var visible_entries: Array[M1OrderCatalogEntry] = []
	for entry: M1OrderCatalogEntry in entries:
		if entry.is_visible:
			visible_entries.append(entry)
	return visible_entries


func _find(
	entries: Array[M1OrderCatalogEntry],
	order_id: StringName
) -> M1OrderCatalogEntry:
	for entry: M1OrderCatalogEntry in entries:
		if entry.order_id == order_id:
			return entry
	return null


func _find_planet(
	entries: Array[M1PlanetCatalogEntry],
	planet_id: StringName
) -> M1PlanetCatalogEntry:
	for entry: M1PlanetCatalogEntry in entries:
		if entry.planet_id == planet_id:
			return entry
	return null


func _count_order(
	entries: Array[M1OrderCatalogEntry],
	order_id: StringName
) -> int:
	var count: int = 0
	for entry: M1OrderCatalogEntry in entries:
		if entry.order_id == order_id:
			count += 1
	return count


func _count_category(
	entries: Array[M1OrderCatalogEntry],
	category: M1OrderCatalogEntry.DisplayCategory
) -> int:
	var count: int = 0
	for entry: M1OrderCatalogEntry in entries:
		if entry.display_category == category:
			count += 1
	return count


func _count_departure_selectable(
	entries: Array[M1PlanetCatalogEntry]
) -> int:
	var count: int = 0
	for entry: M1PlanetCatalogEntry in entries:
		if entry.is_departure_selectable:
			count += 1
	return count
