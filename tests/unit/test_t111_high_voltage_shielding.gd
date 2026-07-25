extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const WHITE_ORDER_ID: StringName = &"order_m1_white_noise_archive_core"
const PLAYABLE_ROUTE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	expect_true(registry != null, "T-111 requires the M1 registry.", failures)
	if registry == null:
		return failures
	var module: ShipModuleDefinition = registry.find_module(
		ShipLoadoutRules.HIGH_VOLTAGE_SHIELDING_MODULE_ID
	)
	var order: OrderDefinition = registry.find_order(WHITE_ORDER_ID)
	expect_true(module != null, "T-111 shielding module is missing.", failures)
	expect_true(order != null, "T-111 White Noise order is missing.", failures)
	if module == null or order == null:
		return failures
	_test_module_contract(module, registry.modules, failures)
	_test_ownership_installation_and_departure(module, order, failures)
	_test_save_round_trip(module, registry.modules, failures)
	return failures


func _test_module_contract(
	module: ShipModuleDefinition,
	module_catalog: Array[ShipModuleDefinition],
	failures: Array[String]
) -> void:
	var default_configuration: Dictionary[StringName, StringName] = (
		ShipLoadoutRules.create_default_configuration()
	)
	expect_true(
		module.slot_type == ShipModuleDefinition.SlotType.DEFENSE
		and module.capability_tags.has(
			ShipLoadoutRules.HIGH_VOLTAGE_SHIELDING_CAPABILITY
		)
		and module.cost == 0
		and module.story_unlock_flags
		== [&"story_m1_red_sand_shielding_retrofit_completed"],
		"The shielding must remain a free story-acquired defense module.",
		failures
	)
	expect_true(
		is_equal_approx(
			FlightElectromagneticProtectionModel
			.get_high_voltage_damage_multiplier(
				default_configuration,
				module_catalog
			),
			1.0
		)
		and is_equal_approx(
			FlightElectromagneticProtectionModel
			.get_electromagnetic_interference_multiplier(
				default_configuration,
				module_catalog
			),
			1.0
		),
		"An uninstalled shielding module must not change hazards.",
		failures
	)
	default_configuration[ShipLoadoutRules.SLOT_DEFENSE] = module.id
	expect_true(
		FlightElectromagneticProtectionModel.has_high_voltage_shielding(
			default_configuration,
			module_catalog
		)
		and is_equal_approx(
			FlightElectromagneticProtectionModel
			.get_high_voltage_damage_multiplier(
				default_configuration,
				module_catalog
			),
			0.6
		)
		and is_equal_approx(
			FlightElectromagneticProtectionModel
			.get_electromagnetic_interference_multiplier(
				default_configuration,
				module_catalog
			),
			0.45
		)
		and is_equal_approx(
			FlightElectromagneticProtectionModel.scale_high_voltage_damage(
				20.0,
				0.6
			),
			12.0
		),
		"Capability lookup must read both tunable shielding multipliers.",
		failures
	)


func _test_ownership_installation_and_departure(
	module: ShipModuleDefinition,
	order: OrderDefinition,
	failures: Array[String]
) -> void:
	var state: GameStateModel = GameStateModel.new()
	expect_true(
		not state.has_ship_module(module.id)
		and not state.equip_ship_module(module)
		and state.last_loadout_error
		== GameStateModel.LOADOUT_ERROR_MODULE_NOT_OWNED,
		"A story module must not be installable before its deterministic reward.",
		failures
	)
	state.ship_upgrade_ids.append(module.id)
	expect_true(
		state.has_ship_module(module.id),
		"The revisit reward ID must establish shielding ownership.",
		failures
	)

	var fixture: OrderDefinition = _make_playable_white_order(order)
	state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	state.unlocked_planet_ids = [
		M1ProgressRules.PLANET_RED_SAND,
		M1ProgressRules.PLANET_WHITE_NOISE,
	]
	state.set_story_flag(&"story_m1_red_sand_shielding_retrofit_completed")
	expect_true(
		state.accept_order(fixture),
		"The owned-module White Noise fixture must be accept-able.",
		failures
	)
	expect_true(
		not state.confirm_departure(fixture)
		and state.last_loadout_error
		== GameStateModel.LOADOUT_ERROR_MISSING_REQUIRED_MODULES,
		"Ownership alone must not satisfy the installed departure requirement.",
		failures
	)
	expect_true(
		state.equip_ship_module(module)
		and state.is_ship_module_equipped(module.id)
		and not state.is_ship_module_equipped(
			ShipLoadoutRules.DEFAULT_DEFENSE_MODULE_ID
		)
		and state.has_ship_capability(
			ShipLoadoutRules.HIGH_VOLTAGE_SHIELDING_CAPABILITY,
			[module]
		)
		and state.confirm_departure(fixture),
		"Installing the owned defense module must satisfy White Noise preflight.",
		failures
	)
	expect_true(
		state.unequip_ship_module(module)
		and not state.departure_confirmed
		and not state.can_confirm_departure(fixture),
		"Removing the shielding must immediately invalidate departure readiness.",
		failures
	)
	state.free()


func _test_save_round_trip(
	module: ShipModuleDefinition,
	module_catalog: Array[ShipModuleDefinition],
	failures: Array[String]
) -> void:
	var source: GameStateModel = GameStateModel.new()
	source.ship_upgrade_ids.append(module.id)
	expect_true(
		source.equip_ship_module(module),
		"The save fixture could not install its owned shielding.",
		failures
	)
	var captured: GameProgressData = GameProgressData.capture(source)
	var restored_progress: GameProgressData = GameProgressData.from_dictionary(
		captured.to_dictionary()
	)
	var restored: GameStateModel = GameStateModel.new()
	expect_true(
		captured.is_valid()
		and restored_progress.is_valid()
		and restored_progress.apply_to(restored)
		and restored.has_ship_module(module.id)
		and restored.is_ship_module_equipped(module.id)
		and restored.has_ship_capability(
			ShipLoadoutRules.HIGH_VOLTAGE_SHIELDING_CAPABILITY,
			module_catalog
		),
		"Schema v2 must restore both shielding ownership and installation.",
		failures
	)
	source.free()
	restored.free()


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
