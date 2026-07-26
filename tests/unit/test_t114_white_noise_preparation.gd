extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const LOCALIZATION_PATH: String = "res://data/localization/game_text.csv"
const WHITE_ORDER_ID: StringName = M1CatalogModel.WHITE_NOISE_ORDER_ID
const REVISIT_ORDER_ID: StringName = (
	M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT
)


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	expect_true(registry != null, "T-114 registry must load.", failures)
	if registry == null:
		return failures
	var order: OrderDefinition = registry.find_order(WHITE_ORDER_ID)
	var shielding: ShipModuleDefinition = registry.find_module(
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
	)
	expect_true(
		order != null and shielding != null,
		"T-114 White Noise order and shielding module must resolve.",
		failures
	)
	if order == null or shielding == null:
		return failures
	_test_preparation_state_matrix(order, shielding, failures)
	_test_catalog_and_departure_contract(registry, order, shielding, failures)
	_test_revisit_reward_unlock(registry, failures)
	_test_save_compatibility_backfill(failures)
	_test_localization_contract(failures)
	return failures


func _test_preparation_state_matrix(
	order: OrderDefinition,
	shielding: ShipModuleDefinition,
	failures: Array[String]
) -> void:
	var previous_state: GameStateModel = GameStateModel.new()
	previous_state.main_story_chapter = (
		M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	)
	previous_state.unlocked_planet_ids = [M1ProgressRules.PLANET_RED_SAND]
	previous_state.completed_order_ids[M1CatalogModel.M0_ORDER_ID] = true
	var previous: M1DestinationPreparationStatus = (
		M1CatalogModel.build_destination_preparation_status(
			order,
			previous_state
		)
	)
	expect_true(
		previous != null
		and previous.is_visible
		and previous.state
		== M1DestinationPreparationStatus.State.PREVIOUS_MAIN_REQUIRED
		and previous.hint_key == &"UI_M1_WHITE_NOISE_PREP_PREVIOUS_MAIN"
		and not previous.is_navigation_unlocked
		and not previous.is_route_qualified,
		"An unfinished Red Sand revisit must expose the exact previous-main gate.",
		failures
	)
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	var previous_entry: M1OrderCatalogEntry = _find_order_entry(
		M1CatalogModel.build_order_catalog(registry, previous_state),
		WHITE_ORDER_ID
	)
	expect_true(
		previous_entry != null
		and previous_entry.display_category
		== M1OrderCatalogEntry.DisplayCategory.NEXT_CLUE
		and previous_entry.is_visible
		and not previous_entry.is_name_disclosed
		and previous_entry.lock_hint_key
		== &"UI_M1_WHITE_NOISE_PREP_PREVIOUS_MAIN",
		"The order terminal must explain the prior revisit without leaking future packet details.",
		failures
	)
	previous_state.free()

	var missing_state: GameStateModel = _create_completed_revisit_state()
	var missing: M1DestinationPreparationStatus = (
		M1CatalogModel.build_destination_preparation_status(
			order,
			missing_state
		)
	)
	expect_true(
		missing != null
		and missing.state
		== M1DestinationPreparationStatus.State.MODULE_NOT_OBTAINED
		and missing.hint_key
		== &"UI_M1_WHITE_NOISE_PREP_MODULE_NOT_OBTAINED"
		and not missing.is_navigation_unlocked
		and not missing.is_route_qualified,
		"A completed revisit missing its reward must explain the unique free acquisition path.",
		failures
	)

	missing_state.ship_upgrade_ids.append(shielding.id)
	expect_true(
		missing_state.unlock_planet(M1ProgressRules.PLANET_WHITE_NOISE).changed,
		"Owning the shielding must unlock the White Noise navigation node before installation.",
		failures
	)
	var owned: M1DestinationPreparationStatus = (
		M1CatalogModel.build_destination_preparation_status(
			order,
			missing_state
		)
	)
	expect_true(
		owned.state
		== M1DestinationPreparationStatus.State.MODULE_NOT_INSTALLED
		and owned.hint_key
		== &"UI_M1_WHITE_NOISE_PREP_MODULE_NOT_INSTALLED"
		and owned.is_navigation_unlocked
		and not owned.is_route_qualified,
		"Owned shielding must leave navigation unlocked while explicitly requiring installation.",
		failures
	)

	missing_state.ship_configuration[
		ShipLoadoutRules.SLOT_DEFENSE
	] = shielding.id
	var installed: M1DestinationPreparationStatus = (
		M1CatalogModel.build_destination_preparation_status(
			order,
			missing_state
		)
	)
	expect_true(
		installed.state
		== M1DestinationPreparationStatus.State.READY
		and installed.hint_key == &"UI_M1_WHITE_NOISE_PREP_READY"
		and installed.is_navigation_unlocked
		and installed.is_route_qualified
		and installed.is_formal_route_available,
		"Installed shielding must expose the dedicated route after T-125.",
		failures
	)
	missing_state.free()


func _test_catalog_and_departure_contract(
	registry: GameDataRegistry,
	order: OrderDefinition,
	shielding: ShipModuleDefinition,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = _create_completed_revisit_state()
	game_state.ship_upgrade_ids.append(shielding.id)
	game_state.ship_configuration[ShipLoadoutRules.SLOT_DEFENSE] = shielding.id
	game_state.unlocked_planet_ids.append(M1ProgressRules.PLANET_WHITE_NOISE)
	var order_entries: Array[M1OrderCatalogEntry] = (
		M1CatalogModel.build_order_catalog(registry, game_state)
	)
	var order_entry: M1OrderCatalogEntry = _find_order_entry(
		order_entries,
		WHITE_ORDER_ID
	)
	var planet_entry: M1PlanetCatalogEntry = _find_planet_entry(
		M1CatalogModel.build_navigation_catalog(registry, game_state),
		M1ProgressRules.PLANET_WHITE_NOISE
	)
	expect_true(
		order_entry != null
		and order_entry.is_visible
		and order_entry.is_name_disclosed
		and order_entry.accept_enabled
		and order_entry.lock_reason.is_empty()
		and order_entry.lock_hint_key
		== &"UI_M1_WHITE_NOISE_PREP_READY"
		and order_entry.preparation_status != null
		and order_entry.preparation_status.state
		== M1DestinationPreparationStatus.State.READY,
		"The order preview must expose the qualified White Noise mainline.",
		failures
	)
	expect_true(
		planet_entry != null
		and planet_entry.is_discovered
		and planet_entry.is_progression_unlocked
		and planet_entry.is_content_playable
		and not planet_entry.is_departure_selectable
		and planet_entry.preparation_status != null
		and (
			planet_entry.preparation_status.hint_key
			== order_entry.preparation_status.hint_key
		),
		"Order and navigation catalogs must consume the same preparation result.",
		failures
	)
	expect_true(
		order.content_readiness
		== OrderDefinition.ContentReadiness.PLAYABLE
		and order.destination_planet.content_readiness
		== PlanetDefinition.ContentReadiness.PLAYABLE
		and order.destination_planet.flight_scene_path
		== "res://scenes/flight/white_noise_flight.tscn",
		"T-125 must promote the prepared packet to its dedicated playable route.",
		failures
	)
	_force_active_order(game_state, order)
	expect_true(
		game_state.get_departure_confirmation_error(order).is_empty()
		and game_state.confirm_departure(order)
		and game_state.begin_travel(
			order,
			M1ProgressRules.PLANET_WHITE_NOISE
		),
		"The qualified White Noise order must pass the formal departure guard.",
		failures
	)
	game_state.free()


func _test_revisit_reward_unlock(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var revisit_order: OrderDefinition = registry.find_order(REVISIT_ORDER_ID)
	game_state.main_story_chapter = (
		M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	)
	game_state.unlocked_planet_ids = [M1ProgressRules.PLANET_RED_SAND]
	game_state.completed_order_ids[M1CatalogModel.M0_ORDER_ID] = true
	game_state.order_states[
		M1CatalogModel.M0_ORDER_ID
	] = GameStateModel.OrderStatus.COMPLETED
	game_state.set_story_flag(&"story_red_sand_order_completed")
	expect_true(
		revisit_order != null
		and revisit_order.planet_unlock_rewards
		== [M1ProgressRules.PLANET_WHITE_NOISE]
		and game_state.accept_order(revisit_order)
		and game_state.complete_order(revisit_order)
		and game_state.is_planet_unlocked(M1ProgressRules.PLANET_WHITE_NOISE)
		and game_state.has_ship_module(
			M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
		)
		and game_state.main_story_chapter
		== M1ProgressRules.CHAPTER_M1_WHITE_NOISE,
		"The revisit settlement must atomically grant the module, chapter, and navigation node.",
		failures
	)
	game_state.free()


func _test_save_compatibility_backfill(failures: Array[String]) -> void:
	var game_state: GameStateModel = _create_completed_revisit_state()
	game_state.ship_upgrade_ids.append(
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
	)
	var progress: GameProgressData = GameProgressData.capture(game_state)
	expect_true(
		progress.is_valid()
		and progress.unlocked_planet_ids.has(
			M1ProgressRules.PLANET_WHITE_NOISE
		),
		"A valid pre-T-114 revisit save must backfill the White Noise navigation node.",
		failures
	)
	game_state.free()


func _test_localization_contract(failures: Array[String]) -> void:
	var catalog: LocalizationCatalog = LocalizationCatalog.load_csv(
		LOCALIZATION_PATH
	)
	for key: StringName in [
		&"UI_M1_WHITE_NOISE_PREP_PREVIOUS_MAIN",
		&"UI_M1_WHITE_NOISE_PREP_MODULE_NOT_OBTAINED",
		&"UI_M1_WHITE_NOISE_PREP_MODULE_NOT_INSTALLED",
		&"UI_M1_WHITE_NOISE_PREP_ROUTE_PENDING",
		&"UI_M1_WHITE_NOISE_PREP_READY",
		&"UI_M1_WHITE_NOISE_RISK_SUMMARY",
	]:
		expect_true(
			not catalog.get_message(key, &"zh_CN").is_empty()
			and not catalog.get_message(key, &"en").is_empty(),
			"T-114 preparation guidance must be localized: %s." % key,
			failures
		)
	var risk_text: String = catalog.get_message(
		&"UI_M1_WHITE_NOISE_RISK_SUMMARY",
		&"zh_CN"
	)
	expect_true(
		risk_text.contains("1.28g")
		and risk_text.contains("电磁暴雪")
		and risk_text.contains("低能见度")
		and risk_text.contains("特高压电屏蔽罩"),
		"The White Noise risk brief must name gravity, storm, visibility, and shielding.",
		failures
	)


func _create_completed_revisit_state() -> GameStateModel:
	var game_state: GameStateModel = GameStateModel.new()
	game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	game_state.unlocked_planet_ids = [M1ProgressRules.PLANET_RED_SAND]
	for order_id: StringName in [
		M1CatalogModel.M0_ORDER_ID,
		REVISIT_ORDER_ID,
	]:
		game_state.completed_order_ids[order_id] = true
		game_state.order_states[order_id] = GameStateModel.OrderStatus.COMPLETED
		game_state.reward_applied_order_ids.append(order_id)
	game_state.story_flags[
		M1ProgressRules.STORY_RED_SAND_SHIELDING_RETROFIT_COMPLETED
	] = true
	return game_state


func _force_active_order(
	game_state: GameStateModel,
	order: OrderDefinition
) -> void:
	game_state.current_order_id = order.id
	game_state.destination_id = order.planet_id
	game_state.cargo_id = order.cargo.id
	game_state.order_states[order.id] = GameStateModel.OrderStatus.ACCEPTED


func _find_order_entry(
	entries: Array[M1OrderCatalogEntry],
	order_id: StringName
) -> M1OrderCatalogEntry:
	for entry: M1OrderCatalogEntry in entries:
		if entry.order_id == order_id:
			return entry
	return null


func _find_planet_entry(
	entries: Array[M1PlanetCatalogEntry],
	planet_id: StringName
) -> M1PlanetCatalogEntry:
	for entry: M1PlanetCatalogEntry in entries:
		if entry.planet_id == planet_id:
			return entry
	return null
