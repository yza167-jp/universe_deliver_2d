extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const M0_ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"

var _persistent_change_count: int = 0
var _station_event_count: int = 0


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	expect_true(registry != null, "T-106 registry must load.", failures)
	if registry == null:
		return failures
	_test_catalog_projection(registry, failures)
	_test_locked_catalog_redaction(failures)
	_test_souvenir_wall_projection(registry, failures)
	_test_idempotent_public_unlocks(failures)
	_test_station_state_authority(failures)
	_test_save_round_trip_and_load_silence(failures)
	_test_m0_direct_and_migrated_plaque(registry, failures)
	return failures


func _test_catalog_projection(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var before_codex: Array[StringName] = game_state.codex_entry_ids.duplicate()
	var before_souvenirs: Array[StringName] = game_state.souvenir_ids.duplicate()
	expect_true(
		CodexCatalogModel.build_catalog(registry, game_state).is_empty(),
		"New Game must hide every currently hidden-when-locked codex entry.",
		failures
	)
	expect_true(
		game_state.codex_entry_ids == before_codex
		and game_state.souvenir_ids == before_souvenirs,
		"Codex queries must never mutate persistent collections.",
		failures
	)

	game_state.unlock_codex_entry(&"codex_planet_red_sand")
	game_state.unlock_codex_entry(&"codex_character_iya")
	game_state.add_souvenir(&"souvenir_old_relay_plaque")
	var catalog: Array[CodexCatalogEntry] = (
		CodexCatalogModel.build_catalog(registry, game_state)
	)
	expect_true(
		_count_category(catalog, CodexEntryDefinition.Category.PLANET) == 1
		and _count_category(
			catalog,
			CodexEntryDefinition.Category.CHARACTER
		) == 1
		and _count_category(
			catalog,
			CodexEntryDefinition.Category.SOUVENIR
		) == 1,
		"Unlocked Red Sand, Iya, and the plaque must appear in their categories.",
		failures
	)
	var plaque_entry: CodexCatalogEntry = _find_codex_entry(
		catalog,
		&"codex_souvenir_old_relay_plaque"
	)
	expect_true(
		plaque_entry != null
		and plaque_entry.is_unlocked
		and plaque_entry.title_key
		== &"CODEX_SOUVENIR_OLD_RELAY_PLAQUE_TITLE"
		and _count_codex_id(
			catalog,
			&"codex_souvenir_old_relay_plaque"
		) == 1,
		"A physical souvenir must unlock its one linked codex entry without duplication.",
		failures
	)
	game_state.free()


func _test_locked_catalog_redaction(failures: Array[String]) -> void:
	var registry: GameDataRegistry = GameDataRegistry.new()
	var visible_locked: CodexEntryDefinition = CodexEntryDefinition.new()
	visible_locked.id = &"codex_anomaly_visible_fixture"
	visible_locked.category = CodexEntryDefinition.Category.ANOMALY
	visible_locked.title_key = &"CODEX_PLANET_RED_SAND_TITLE"
	visible_locked.description_key = &"CODEX_PLANET_RED_SAND_DESCRIPTION"
	visible_locked.hidden_when_locked = false
	var hidden_locked: CodexEntryDefinition = visible_locked.duplicate(
		true
	) as CodexEntryDefinition
	hidden_locked.id = &"codex_anomaly_hidden_fixture"
	hidden_locked.hidden_when_locked = true
	registry.codex_entries = [visible_locked, hidden_locked]
	var game_state: GameStateModel = GameStateModel.new()
	var entries: Array[CodexCatalogEntry] = (
		CodexCatalogModel.build_catalog(registry, game_state)
	)
	expect_true(
		entries.size() == 1
		and entries[0].id == visible_locked.id
		and entries[0].is_locked_placeholder
		and entries[0].title_key == CodexCatalogModel.UNKNOWN_TITLE_KEY
		and entries[0].description_key
		== CodexCatalogModel.UNKNOWN_DESCRIPTION_KEY,
		"A visible locked slot must use generic text while hidden content stays absent.",
		failures
	)
	game_state.free()


func _test_souvenir_wall_projection(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var entries: Array[SouvenirWallEntry] = (
		SouvenirWallModel.build_entries(registry, game_state)
	)
	expect_true(
		entries.size() == registry.souvenirs.size()
		and entries.size() == 4,
		"The wall must expose one stable slot per registered souvenir.",
		failures
	)
	for index: int in entries.size():
		var entry: SouvenirWallEntry = entries[index]
		expect_true(
			entry.souvenir_id == registry.souvenirs[index].id
			and not entry.is_acquired
			and entry.display_name_key == SouvenirWallModel.LOCKED_NAME_KEY
			and entry.description_key
			== SouvenirWallModel.LOCKED_DESCRIPTION_KEY,
			"Locked wall slots must preserve registry order without revealing content.",
			failures
		)

	game_state.add_souvenir(&"souvenir_canopy_route_chime")
	game_state.add_souvenir(&"souvenir_old_relay_plaque")
	entries = SouvenirWallModel.build_entries(registry, game_state)
	expect_true(
		SouvenirWallModel.get_acquired_count(entries) == 2
		and entries[0].souvenir_id == &"souvenir_old_relay_plaque"
		and entries[0].is_acquired
		and entries[2].souvenir_id == &"souvenir_canopy_route_chime"
		and entries[2].is_acquired,
		"Acquired souvenirs must fill their existing stable slots.",
		failures
	)

	var legacy_state: GameStateModel = GameStateModel.new()
	legacy_state.station_upgrade_ids[
		M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
	] = true
	var legacy_entries: Array[SouvenirWallEntry] = (
		SouvenirWallModel.build_entries(registry, legacy_state)
	)
	expect_true(
		legacy_entries[0].is_acquired
		and SouvenirWallModel.get_acquired_count(legacy_entries) == 1,
		"An in-memory M0 display flag must still project the relay plaque once.",
		failures
	)
	game_state.free()
	legacy_state.free()


func _test_idempotent_public_unlocks(failures: Array[String]) -> void:
	var game_state: GameStateModel = _create_observed_state()
	var first_codex: ProgressChangeResult = game_state.unlock_codex_entry(
		&"codex_planet_red_sand"
	)
	var repeated_codex: ProgressChangeResult = game_state.unlock_codex_entry(
		&"codex_planet_red_sand"
	)
	var first_souvenir: ProgressChangeResult = game_state.add_souvenir(
		&"souvenir_old_relay_plaque"
	)
	var repeated_souvenir: ProgressChangeResult = game_state.add_souvenir(
		&"souvenir_old_relay_plaque"
	)
	var first_station: ProgressChangeResult = game_state.unlock_station_state(
		StationStateRules.ARCHIVE_TERMINAL_ID
	)
	var repeated_station: ProgressChangeResult = game_state.unlock_station_state(
		StationStateRules.ARCHIVE_TERMINAL_ID
	)
	var invalid_station: ProgressChangeResult = game_state.unlock_station_state(
		&"station_state_unregistered"
	)
	expect_true(
		first_codex.changed
		and not repeated_codex.changed
		and first_souvenir.changed
		and not repeated_souvenir.changed
		and first_station.changed
		and not repeated_station.changed
		and not invalid_station.success
		and game_state.codex_entry_ids.count(&"codex_planet_red_sand") == 1
		and game_state.souvenir_ids.count(&"souvenir_old_relay_plaque") == 1
		and _persistent_change_count == 3
		and _station_event_count == 1,
		"Collection and station unlock APIs must be idempotent and emit only on change.",
		failures
	)
	game_state.free()


func _test_station_state_authority(failures: Array[String]) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var ecology: ProgressChangeResult = game_state.unlock_station_state(
		StationStateRules.ECOLOGY_CORNER_ID
	)
	var archive: ProgressChangeResult = game_state.unlock_station_state(
		StationStateRules.ARCHIVE_TERMINAL_ID
	)
	var relay: ProgressChangeResult = game_state.unlock_station_state(
		StationStateRules.RELAY_OBSERVATORY_ID
	)
	expect_true(
		ecology.changed
		and ecology.current_value == StationStateRules.ECOLOGY_CORNER_LEVEL
		and archive.changed
		and archive.current_value == StationStateRules.ECOLOGY_CORNER_LEVEL
		and relay.changed
		and relay.current_value == StationStateRules.RELAY_OBSERVATORY_LEVEL
		and game_state.has_station_state(
			StationStateRules.ARCHIVE_TERMINAL_ID
		)
		and game_state.has_station_state(
			StationStateRules.ECOLOGY_CORNER_ID
		)
		and game_state.has_station_state(
			StationStateRules.RELAY_OBSERVATORY_ID
		),
		"Exact station IDs must unlock independently while the summary never regresses.",
		failures
	)
	game_state.free()


func _test_save_round_trip_and_load_silence(
	failures: Array[String]
) -> void:
	var source: GameStateModel = GameStateModel.new()
	source.unlock_codex_entry(&"codex_planet_red_sand")
	source.add_souvenir(&"souvenir_old_relay_plaque")
	source.unlock_station_state(StationStateRules.ARCHIVE_TERMINAL_ID)
	source.unlock_station_state(StationStateRules.ECOLOGY_CORNER_ID)
	var captured: GameProgressData = GameProgressData.capture(source)
	var restored_progress: GameProgressData = GameProgressData.from_dictionary(
		captured.to_dictionary()
	)
	var restored: GameStateModel = GameStateModel.new()
	_station_event_count = 0
	restored.station_state_unlocked.connect(_on_station_state_unlocked)
	expect_true(
		captured.is_valid()
		and restored_progress.is_valid()
		and restored_progress.apply_to(restored)
		and restored.codex_entry_ids == [&"codex_planet_red_sand"]
		and restored.souvenir_ids == [&"souvenir_old_relay_plaque"]
		and restored.has_station_state(
			StationStateRules.ARCHIVE_TERMINAL_ID
		)
		and restored.has_station_state(
			StationStateRules.ECOLOGY_CORNER_ID
		)
		and restored.station_state_level
		== StationStateRules.ECOLOGY_CORNER_LEVEL
		and _station_event_count == 0,
		"Save loading must restore collections and exact station IDs without replaying unlock events.",
		failures
	)

	var stale_summary: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {
			"station_upgrade_ids": [
				String(StationStateRules.ARCHIVE_TERMINAL_ID),
			],
			"station_state_level": 0,
		},
	})
	expect_true(
		stale_summary.is_valid()
		and stale_summary.station_state_level
		== StationStateRules.ARCHIVE_TERMINAL_LEVEL,
		"A stale coarse level must normalize upward from authoritative IDs.",
		failures
	)
	var invalid_state: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {
			"station_upgrade_ids": ["station_state_not_registered"],
		},
	})
	expect_true(
		not invalid_state.is_valid()
		and invalid_state.validation_error.contains("station state"),
		"Unknown station_state_* IDs must be rejected during save validation.",
		failures
	)
	source.free()
	restored.free()


func _test_m0_direct_and_migrated_plaque(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var order: OrderDefinition = load(M0_ORDER_PATH) as OrderDefinition
	var current_state: GameStateModel = GameStateModel.new()
	expect_true(
		order != null
		and current_state.accept_order(order)
		and current_state.complete_order(
			order,
			-1,
			M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
		),
		"The current M0 first delivery must complete through the unified reward path.",
		failures
	)
	var current_wall: Array[SouvenirWallEntry] = (
		SouvenirWallModel.build_entries(registry, current_state)
	)
	expect_true(
		current_state.codex_entry_ids.has(&"codex_planet_red_sand")
		and current_state.codex_entry_ids.has(&"codex_character_iya")
		and current_state.codex_entry_ids.has(
			&"codex_souvenir_old_relay_plaque"
		)
		and current_state.souvenir_ids
		== [&"souvenir_old_relay_plaque"]
		and current_state.station_state_level
		== StationStateRules.M0_FIRST_DELIVERY_LEVEL
		and current_wall[0].is_acquired
		and SouvenirWallModel.get_acquired_count(current_wall) == 1,
		"The current M0 settlement must expose exactly one relay plaque immediately.",
		failures
	)

	var migrated: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 1,
		"game_progress": {
			"completed_order_ids": ["order_red_sand_m0"],
			"station_upgrade_ids": [
				String(
					M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
				),
			],
		},
	})
	var migrated_state: GameStateModel = GameStateModel.new()
	expect_true(
		migrated.is_valid()
		and migrated.apply_to(migrated_state)
		and migrated_state.souvenir_ids
		== [&"souvenir_old_relay_plaque"]
		and migrated_state.codex_entry_ids.count(
			&"codex_souvenir_old_relay_plaque"
		) == 1,
		"v1-to-v2 migration must retain one plaque and one linked codex record.",
		failures
	)
	current_state.free()
	migrated_state.free()


func _create_observed_state() -> GameStateModel:
	_persistent_change_count = 0
	_station_event_count = 0
	var game_state: GameStateModel = GameStateModel.new()
	game_state.persistent_state_changed.connect(_on_persistent_state_changed)
	game_state.station_state_unlocked.connect(_on_station_state_unlocked)
	return game_state


func _on_persistent_state_changed() -> void:
	_persistent_change_count += 1


func _on_station_state_unlocked(
	_state_id: StringName,
	_summary_level: int
) -> void:
	_station_event_count += 1


func _count_category(
	entries: Array[CodexCatalogEntry],
	category: CodexEntryDefinition.Category
) -> int:
	var count: int = 0
	for entry: CodexCatalogEntry in entries:
		if entry.category == category:
			count += 1
	return count


func _count_codex_id(
	entries: Array[CodexCatalogEntry],
	entry_id: StringName
) -> int:
	var count: int = 0
	for entry: CodexCatalogEntry in entries:
		if entry.id == entry_id:
			count += 1
	return count


func _find_codex_entry(
	entries: Array[CodexCatalogEntry],
	entry_id: StringName
) -> CodexCatalogEntry:
	for entry: CodexCatalogEntry in entries:
		if entry.id == entry_id:
			return entry
	return null
