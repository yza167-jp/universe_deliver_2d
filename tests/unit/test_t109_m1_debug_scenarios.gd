extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const MAIN_MENU_PATH: String = "res://scenes/app/main_menu.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	expect_true(registry != null, "T-109 requires the M1 registry.", failures)
	if registry == null:
		return failures
	_test_scenario_catalog(registry, failures)
	_test_invalid_scenarios(registry, failures)
	_test_registered_only_guards(registry, failures)
	_test_storage_and_settings_isolation(failures)
	_test_entry_visibility_and_compatibility(registry, failures)
	return failures


func _test_scenario_catalog(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var catalog: M1DebugScenarioCatalog = M1DebugScenarioCatalog.new()
	var scenario_ids: Array[StringName] = (
		M1DebugScenarioCatalog.get_scenario_ids()
	)
	expect_true(
		scenario_ids == [
			M1DebugScenarioCatalog.SCENARIO_RED_SAND_REVISIT,
			M1DebugScenarioCatalog.SCENARIO_WHITE_NOISE_CATALOG,
			M1DebugScenarioCatalog.SCENARIO_WHITE_NOISE_ROUTE,
			M1DebugScenarioCatalog.SCENARIO_WHITE_NOISE_ROUTE_UNSHIELDED,
			M1DebugScenarioCatalog.SCENARIO_CANOPY_CATALOG,
			M1DebugScenarioCatalog.SCENARIO_TIDAL_CATALOG,
			M1DebugScenarioCatalog.SCENARIO_LOW_ALTITUDE_DROP,
			M1DebugScenarioCatalog.SCENARIO_EXPRESS_ORDER,
			M1DebugScenarioCatalog.SCENARIO_GATE_E,
		],
		"The M1 debug catalog must expose its nine scenarios in stable order.",
		failures
	)
	for scenario_id: StringName in scenario_ids:
		var first: M1DebugScenarioDefinition = catalog.get_definition(
			scenario_id,
			registry
		)
		var second: M1DebugScenarioDefinition = catalog.get_definition(
			scenario_id,
			registry
		)
		expect_true(
			first != null and second != null,
			"Scenario must resolve: %s (%s)." % [scenario_id, catalog.last_error],
			failures
		)
		if first == null or second == null:
			continue
		expect_true(
			first.to_canonical_dictionary()
			== second.to_canonical_dictionary(),
			"Scenario resolution must be deterministic: %s." % scenario_id,
			failures
		)
		var first_progress: GameProgressData = (
			catalog.build_initial_progress(first, registry)
		)
		var second_progress: GameProgressData = (
			catalog.build_initial_progress(second, registry)
		)
		expect_true(
			first_progress != null
			and second_progress != null
			and first_progress.is_valid()
			and second_progress.is_valid()
			and first_progress.to_dictionary()
			== second_progress.to_dictionary(),
			"Scenario progress must be valid and deterministic: %s (%s)."
			% [scenario_id, catalog.last_error],
			failures
		)
		if first_progress == null:
			continue
		var state: GameStateModel = GameStateModel.new()
		expect_true(
			first_progress.apply_to(state)
			and state.main_story_chapter == first.chapter_id
			and _same_ids(
				state.unlocked_planet_ids,
				first.unlocked_planet_ids
			)
			and _same_ids(
				state.planet_permission_ids,
				first.permission_ids
			),
			"Scenario snapshot did not apply its chapter, planets, and permissions: %s."
			% scenario_id,
			failures
		)
		state.free()

	var parsed: M1DebugScenarioDefinition = catalog.parse_arguments(
		PackedStringArray(["--m1-debug=canopy_catalog"]),
		registry
	)
	expect_true(
		parsed != null
		and parsed.scenario_id
		== M1DebugScenarioCatalog.SCENARIO_CANOPY_CATALOG,
		"The --m1-debug argument must resolve one exact scenario.",
		failures
	)


func _test_invalid_scenarios(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var catalog: M1DebugScenarioCatalog = M1DebugScenarioCatalog.new()
	expect_true(
		catalog.get_definition(&"unknown_scenario", registry) == null
		and catalog.last_error.contains("Unknown"),
		"Unknown scenario IDs must be rejected.",
		failures
	)
	expect_true(
		catalog.parse_arguments(
			PackedStringArray(["--m1-debug="]),
			registry
		) == null,
		"An empty M1 scenario ID must be rejected.",
		failures
	)
	expect_true(
		catalog.parse_arguments(
			PackedStringArray(["--m1-debug"]),
			registry
		) == null,
		"A bare M1 debug argument must be rejected without losing isolation.",
		failures
	)
	expect_true(
		catalog.parse_arguments(
			PackedStringArray([
				"--m1-debug=canopy_catalog",
				"--m1-debug=tidal_catalog",
			]),
			registry
		) == null,
		"Multiple M1 scenario arguments must be rejected.",
		failures
	)

	var invalid_chapter: M1DebugScenarioDefinition = catalog.get_definition(
		M1DebugScenarioCatalog.SCENARIO_CANOPY_CATALOG,
		registry
	)
	invalid_chapter.chapter_id = &"chapter_not_registered"
	expect_true(
		not catalog.validate_definition(
			invalid_chapter,
			registry
		).is_empty(),
		"Unknown chapter combinations must be rejected.",
		failures
	)

	var mismatched_focus: M1DebugScenarioDefinition = catalog.get_definition(
		M1DebugScenarioCatalog.SCENARIO_WHITE_NOISE_CATALOG,
		registry
	)
	mismatched_focus.focus_planet_id = M1ProgressRules.PLANET_RED_SAND
	expect_true(
		not catalog.validate_definition(
			mismatched_focus,
			registry
		).is_empty(),
		"Order and focused-planet mismatches must be rejected.",
		failures
	)

	var invalid_active: M1DebugScenarioDefinition = catalog.get_definition(
		M1DebugScenarioCatalog.SCENARIO_EXPRESS_ORDER,
		registry
	)
	invalid_active.active_order_id = &"order_m1_tidal_weather_core"
	expect_true(
		not catalog.validate_definition(
			invalid_active,
			registry
		).is_empty(),
		"Only the isolated express fixture may become an active debug order.",
		failures
	)


func _test_registered_only_guards(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var catalog: M1DebugScenarioCatalog = M1DebugScenarioCatalog.new()
	for scenario_id: StringName in M1DebugScenarioCatalog.get_scenario_ids():
		var definition: M1DebugScenarioDefinition = catalog.get_definition(
			scenario_id,
			registry
		)
		if definition == null:
			continue
		var focused_order: OrderDefinition = registry.find_order(
			definition.catalog_focus_order_id
		)
		var focused_planet: PlanetDefinition = registry.find_planet(
			definition.focus_planet_id
		)
		expect_true(
			focused_order != null
			and focused_order.content_readiness
			== (
				OrderDefinition.ContentReadiness.PLAYABLE
				if scenario_id in [
					M1DebugScenarioCatalog.SCENARIO_RED_SAND_REVISIT,
					M1DebugScenarioCatalog.SCENARIO_GATE_E,
				]
				else OrderDefinition.ContentReadiness.REGISTERED_ONLY
			)
			and focused_planet != null
			and (
				definition.focus_planet_id
				== M1ProgressRules.PLANET_RED_SAND
				or focused_planet.content_readiness
				== PlanetDefinition.ContentReadiness.REGISTERED_ONLY
			),
			"Scenario readiness must match implemented content: %s." % scenario_id,
			failures
		)
		var progress: GameProgressData = catalog.build_initial_progress(
			definition,
			registry
		)
		var state: GameStateModel = GameStateModel.new()
		if progress != null:
			progress.apply_to(state)
		if scenario_id in [
			M1DebugScenarioCatalog.SCENARIO_RED_SAND_REVISIT,
			M1DebugScenarioCatalog.SCENARIO_GATE_E,
		]:
			expect_true(
				focused_order != null and state.accept_order(focused_order),
				"The implemented revisit scenario must pass authoritative acceptance.",
				failures
			)
		elif scenario_id in [
			M1DebugScenarioCatalog.SCENARIO_WHITE_NOISE_ROUTE,
			M1DebugScenarioCatalog.SCENARIO_WHITE_NOISE_ROUTE_UNSHIELDED,
		]:
			expect_true(
				focused_order != null
				and not state.accept_order(focused_order)
				and state.last_order_error
				== GameStateModel.ORDER_ERROR_REGISTERED_ONLY,
				"The route fixture must not change formal White Noise readiness.",
				failures
			)
		else:
			expect_true(
				focused_order != null
				and not state.accept_order(focused_order)
				and state.last_order_error
				== GameStateModel.ORDER_ERROR_REGISTERED_ONLY,
				"Scenario injection must preserve the authoritative acceptance guard: %s."
				% scenario_id,
				failures
			)
		state.free()


func _test_storage_and_settings_isolation(
	failures: Array[String]
) -> void:
	var progress_paths: PackedStringArray = [
		SaveServiceModel.DEFAULT_SAVE_PATH,
		SaveServiceModel.DEFAULT_TEMP_PATH,
		SaveServiceModel.DEFAULT_BACKUP_PATH,
		SaveServiceModel.DEFAULT_REJECTED_PATH,
	]
	var before_progress: PackedStringArray = _file_signatures(progress_paths)
	var before_settings: String = _file_signature(
		SettingsServiceModel.DEFAULT_SETTINGS_PATH
	)

	var state: GameStateModel = GameStateModel.new()
	state.credits = 77
	var save_service: SaveServiceModel = SaveServiceModel.new()
	save_service.game_state_override = state
	save_service.set_isolated_debug_session(true)
	save_service.reset_storage_access_count()
	expect_true(
		save_service.refresh_save_availability()
		== SaveServiceModel.SaveAvailability.NONE
		and not save_service.has_continue_option()
		and not save_service.save_progress()
		and not save_service.load_progress()
		and not save_service.start_new_game()
		and state.credits == 77
		and save_service.last_error_code
		== SaveServiceModel.ERROR_DEBUG_STORAGE_ISOLATED
		and save_service.get_storage_access_count() == 0,
		"Isolated debug progress operations must reject before any normal-file access.",
		failures
	)
	var settings_service: SettingsServiceModel = SettingsServiceModel.new()
	settings_service.set_isolated_debug_session(true)
	settings_service.reset_storage_write_count()
	expect_true(
		not settings_service.save_settings()
		and settings_service.get_storage_write_count() == 0,
		"Isolated debug settings must reject persistent writes.",
		failures
	)
	expect_true(
		before_progress == _file_signatures(progress_paths)
		and before_settings
		== _file_signature(SettingsServiceModel.DEFAULT_SETTINGS_PATH),
		"Default player save, backup, temporary, rejected, and settings files changed.",
		failures
	)
	expect_true(
		not SaveServiceModel.should_enable_automatic_saves(
			PackedStringArray(),
			PackedStringArray(["--m1-debug=canopy_catalog"])
		)
		and SaveServiceModel.should_isolate_debug_storage(
			PackedStringArray(["--m1-debug=canopy_catalog"])
		)
		and SaveServiceModel.should_isolate_debug_storage(
			PackedStringArray(["--m1-debug"])
		)
		and SettingsServiceModel.should_isolate_debug_settings(
			PackedStringArray(["--m1-debug=canopy_catalog"])
		)
		and SettingsServiceModel.should_isolate_debug_settings(
			PackedStringArray(["--m1-debug"])
		)
		and SaveServiceModel.should_enable_automatic_saves(
			PackedStringArray(),
			PackedStringArray()
		),
		"M1 debug isolation must be argument-scoped without changing normal startup.",
		failures
	)
	settings_service.free()
	save_service.free()
	state.free()


func _test_entry_visibility_and_compatibility(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var menu_file: FileAccess = FileAccess.open(MAIN_MENU_PATH, FileAccess.READ)
	var menu_source: String = (
		"" if menu_file == null else menu_file.get_as_text()
	)
	if menu_file != null:
		menu_file.close()
	expect_true(
		not menu_source.contains("--m1-debug")
		and not menu_source.contains("canopy_catalog")
		and not menu_source.contains("M1Debug"),
		"The normal player menu must not expose M1 debug entry points.",
		failures
	)
	expect_true(
		UniverseDeliverApp.should_start_in_m1_debug(
			true,
			PackedStringArray(["--m1-debug=red_sand_revisit"])
		)
		and not UniverseDeliverApp.should_start_in_m1_debug(
			false,
			PackedStringArray(["--m1-debug=red_sand_revisit"])
		)
		and UniverseDeliverApp.should_start_in_flight_lab(
			true,
			PackedStringArray([UniverseDeliverApp.DEBUG_FLIGHT_LAB_ARGUMENT])
		)
		and UniverseDeliverApp.should_start_in_delivery_lab(
			true,
			PackedStringArray([UniverseDeliverApp.DEBUG_DELIVERY_LAB_ARGUMENT])
		)
		and UniverseDeliverApp.should_start_in_red_sand_route(
			true,
			PackedStringArray([
				UniverseDeliverApp.DEBUG_RED_SAND_ROUTE_ARGUMENT,
			])
		),
		"M1 argument routing must preserve existing Lab and Red Sand direct entries.",
		failures
	)
	expect_true(
		registry.find_order(
			M1DebugScenarioCatalog.ORDER_TIDAL_EXPRESS
		).content_readiness
		== OrderDefinition.ContentReadiness.REGISTERED_ONLY,
		"T-109 tests must leave the formal M1 registry unchanged.",
		failures
	)


func _file_signatures(paths: PackedStringArray) -> PackedStringArray:
	var signatures: PackedStringArray = []
	for path: String in paths:
		signatures.append(_file_signature(path))
	return signatures


func _file_signature(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "%s:MISSING" % path
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "%s:UNREADABLE" % path
	var size: int = file.get_length()
	file.close()
	return "%s:%d:%s" % [path, size, FileAccess.get_sha256(path)]


func _same_ids(
	left: Array[StringName],
	right: Array[StringName]
) -> bool:
	var left_copy: Array[StringName] = left.duplicate()
	var right_copy: Array[StringName] = right.duplicate()
	left_copy.sort()
	right_copy.sort()
	return left_copy == right_copy
