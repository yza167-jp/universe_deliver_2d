extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m0_data_registry.tres"


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry_resource: Resource = load(REGISTRY_PATH)
	var registry: GameDataRegistry = registry_resource as GameDataRegistry

	expect_true(registry != null, "M0 data registry must load as GameDataRegistry.", failures)
	if registry == null:
		return failures

	var validation_errors: PackedStringArray = GameDataValidator.validate(registry)
	expect_true(
		validation_errors.is_empty(),
		"M0 data registry must validate: %s" % "; ".join(validation_errors),
		failures
	)
	expect_true(registry.planets.size() == 1, "M0 registry must contain only Red Sand.", failures)
	expect_true(registry.orders.size() == 1, "M0 registry must contain one main order.", failures)
	expect_true(registry.cargo_items.size() == 1, "M0 registry must contain one cargo item.", failures)
	expect_true(registry.modules.size() == 4, "M0 registry must contain four loadout modules.", failures)

	var order: OrderDefinition = registry.find_order(&"order_red_sand_m0")
	expect_true(order != null, "Red Sand M0 order must be registered.", failures)
	if order == null:
		return failures

	expect_true(
		order.destination_planet != null and order.destination_planet.id == &"planet_red_sand",
		"Red Sand order must reference its destination planet.",
		failures
	)
	if order.destination_planet != null:
		var environment: FlightEnvironmentProfile = (
			order.destination_planet.flight_environment_profile
		)
		expect_true(
			environment != null
			and environment.id == &"environment_red_sand_atmosphere"
			and environment.planet_gravity > 0.0,
			"Red Sand must reference its configurable atmosphere and gravity profile.",
			failures
		)
	expect_true(order.cargo != null, "Red Sand order must reference cargo.", failures)
	expect_true(order.required_modules.size() == 2, "Red Sand order must declare required modules.", failures)
	expect_true(
		order.recommended_modules.size() == 2
		and order.recommended_modules[0].id == ShipLoadoutRules.LASER_MODULE_ID
		and order.recommended_modules[1].id
		== ShipLoadoutRules.SHIELD_BACKUP_POWER_MODULE_ID,
		"Red Sand must expose the optional laser and shield backup power.",
		failures
	)
	for module: ShipModuleDefinition in order.required_modules:
		expect_true(
			module.cost == 0 and module.story_unlock_flags.is_empty(),
			"Required M0 modules must be standard issue with no purchase or story grind: %s"
			% module.id,
			failures
		)
	expect_true(
		order.customer_history_keys.size() == 3,
		"Red Sand order must provide a concise three-entry customer history.",
		failures
	)
	expect_true(
		order.delivery_method == OrderDefinition.DeliveryMethod.LANDING,
		"Red Sand M0 order must use landing delivery.",
		failures
	)

	var cargo: CargoDefinition = order.cargo
	if cargo != null:
		expect_true(
			cargo.boost_policy == CargoDefinition.BoostPolicy.LIMITED,
			"M0 cargo must declare its Boost restriction.",
			failures
		)
		expect_true(
			cargo.collision_tolerance > 0.0 and cargo.collision_tolerance <= 1.0,
			"M0 cargo must declare collision tolerance.",
			failures
		)
		expect_true(
			not cargo.attraction_risk_tags.is_empty(),
			"M0 cargo must declare attraction risk tags.",
			failures
		)
	return failures
