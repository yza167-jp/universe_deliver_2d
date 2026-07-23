extends ProjectTestSuite

const ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"


func run() -> Array[String]:
	var failures: Array[String] = []
	var order: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	var game_state: GameStateModel = GameStateModel.new()
	var module_catalog: Array[ShipModuleDefinition] = ShipLoadoutRules.get_order_modules(order)
	var power_module: ShipModuleDefinition = ShipLoadoutRules.get_module_for_slot(
		order,
		ShipModuleDefinition.SlotType.POWER
	)
	var defense_module: ShipModuleDefinition = ShipLoadoutRules.get_module_for_slot(
		order,
		ShipModuleDefinition.SlotType.DEFENSE
	)
	var utility_module: ShipModuleDefinition = ShipLoadoutRules.get_module_for_slot(
		order,
		ShipModuleDefinition.SlotType.UTILITY
	)
	var shield_backup_module: ShipModuleDefinition = ShipLoadoutRules.get_module_by_id(
		order,
		ShipLoadoutRules.SHIELD_BACKUP_POWER_MODULE_ID
	)

	expect_true(order != null, "Red Sand order must load for loadout tests.", failures)
	expect_true(
		power_module != null
		and defense_module != null
		and utility_module != null
		and shield_backup_module != null,
		"The M0 order must expose required modules and both optional utility mounts.",
		failures
	)
	expect_true(
		game_state.is_ship_module_equipped(ShipLoadoutRules.DEFAULT_POWER_MODULE_ID)
		and game_state.is_ship_module_equipped(ShipLoadoutRules.DEFAULT_DEFENSE_MODULE_ID),
		"A new game must begin with the standard power and defense modules installed.",
		failures
	)
	expect_true(
		not game_state.is_ship_module_equipped(ShipLoadoutRules.LASER_MODULE_ID),
		"The optional laser must begin uninstalled.",
		failures
	)
	expect_true(
		not game_state.is_ship_module_equipped(
			ShipLoadoutRules.SHIELD_BACKUP_POWER_MODULE_ID
		),
		"The optional shield backup power must begin uninstalled.",
		failures
	)
	expect_true(
		ShipLoadoutRules.BASE_HULL > 0
		and ShipLoadoutRules.BASE_SHIELD > 0
		and ShipLoadoutRules.BASE_FUEL > 0
		and ShipLoadoutRules.BASE_BOOST > 0
		and ShipLoadoutRules.BASE_CARGO_CAPACITY == 1,
		"The fixed M0 ship must expose all five positive base stats.",
		failures
	)

	expect_true(game_state.accept_order(order), "The M0 order must be accepted.", failures)
	expect_true(
		game_state.get_missing_required_modules(order).is_empty(),
		"The standard issue loadout must satisfy the main order without grinding.",
		failures
	)
	expect_true(
		game_state.confirm_departure(order)
		and game_state.is_departure_confirmed_for_order(order),
		"A complete required loadout must support departure confirmation.",
		failures
	)

	expect_true(
		not game_state.has_ship_capability(
			ShipLoadoutRules.ASTEROID_BREAK_CAPABILITY,
			module_catalog
		),
		"Asteroid breaking must be unavailable while the laser is uninstalled.",
		failures
	)
	expect_true(
		game_state.equip_ship_module(utility_module),
		"The optional utility module must be installable.",
		failures
	)
	expect_true(
		game_state.ship_configuration[ShipLoadoutRules.SLOT_UTILITY]
		== ShipLoadoutRules.LASER_MODULE_ID,
		"Installing the laser must write its stable ID into GameState.",
		failures
	)
	expect_true(
		game_state.has_ship_capability(
			ShipLoadoutRules.ASTEROID_BREAK_CAPABILITY,
			module_catalog
		),
		"Installing the laser must expose the later asteroid-breaking capability.",
		failures
	)
	expect_true(
		not game_state.departure_confirmed,
		"Changing the loadout must invalidate an earlier departure confirmation.",
		failures
	)
	expect_true(game_state.confirm_departure(order), "The updated loadout must be confirmable.", failures)
	expect_true(
		game_state.equip_ship_module(shield_backup_module)
		and game_state.is_ship_module_equipped(
			ShipLoadoutRules.SHIELD_BACKUP_POWER_MODULE_ID
		)
		and game_state.is_ship_module_equipped(ShipLoadoutRules.LASER_MODULE_ID)
		and game_state.has_ship_capability(
			ShipLoadoutRules.SHIELD_REGENERATION_CAPABILITY,
			module_catalog
		),
		"Shield backup power must install independently without replacing the laser.",
		failures
	)
	expect_true(
		game_state.ship_configuration[
			ShipLoadoutRules.SLOT_SHIELD_BACKUP_POWER
		] == ShipLoadoutRules.SHIELD_BACKUP_POWER_MODULE_ID,
		"Shield backup power must persist in its stable secondary utility slot.",
		failures
	)
	expect_true(
		game_state.unequip_ship_module(utility_module)
		and not game_state.has_ship_capability(
			ShipLoadoutRules.ASTEROID_BREAK_CAPABILITY,
			module_catalog
		),
		"Removing the laser must remove asteroid breaking without removing backup power.",
		failures
	)
	expect_true(
		game_state.is_ship_module_equipped(
			ShipLoadoutRules.SHIELD_BACKUP_POWER_MODULE_ID
		)
		and game_state.unequip_ship_module(shield_backup_module),
		"Shield backup power must remain independently removable.",
		failures
	)

	expect_true(
		game_state.unequip_ship_module(defense_module),
		"The defense slot must support a visible missing-required state.",
		failures
	)
	var missing_modules: Array[ShipModuleDefinition] = game_state.get_missing_required_modules(order)
	expect_true(
		missing_modules.size() == 1 and missing_modules[0].id == defense_module.id,
		"Missing required modules must identify the exact absent module.",
		failures
	)
	expect_true(
		not game_state.confirm_departure(order)
		and game_state.last_loadout_error
		== GameStateModel.LOADOUT_ERROR_MISSING_REQUIRED_MODULES,
		"Departure must be rejected when a required module is absent.",
		failures
	)
	expect_true(
		game_state.equip_ship_module(defense_module)
		and game_state.confirm_departure(order),
		"Reinstalling the standard issue defense module must restore departure readiness.",
		failures
	)

	game_state.reset_runtime_state()
	expect_true(
		game_state.is_ship_module_equipped(ShipLoadoutRules.DEFAULT_POWER_MODULE_ID)
		and game_state.is_ship_module_equipped(ShipLoadoutRules.DEFAULT_DEFENSE_MODULE_ID)
		and not game_state.departure_confirmed,
		"Runtime reset must restore the fixed ship's safe default loadout.",
		failures
	)
	game_state.free()
	return failures
