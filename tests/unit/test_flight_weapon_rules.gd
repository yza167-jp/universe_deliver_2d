extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m0_data_registry.tres"


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	expect_true(registry != null, "M0 registry must load for weapon rules.", failures)
	if registry == null:
		return failures

	var default_configuration: Dictionary[StringName, StringName] = (
		ShipLoadoutRules.create_default_configuration()
	)
	expect_true(
		not FlightWeaponRules.has_asteroid_laser(
			default_configuration,
			registry.modules
		),
		"Asteroid laser capability must be absent from the default loadout.",
		failures
	)

	var laser_configuration: Dictionary[StringName, StringName] = (
		default_configuration.duplicate()
	)
	laser_configuration[ShipLoadoutRules.SLOT_UTILITY] = ShipLoadoutRules.LASER_MODULE_ID
	expect_true(
		FlightWeaponRules.has_asteroid_laser(
			laser_configuration,
			registry.modules
		),
		"Installing the asteroid laser must expose the firing capability.",
		failures
	)

	var unrelated_configuration: Dictionary[StringName, StringName] = (
		default_configuration.duplicate()
	)
	unrelated_configuration[ShipLoadoutRules.SLOT_UTILITY] = &"module_unknown_utility"
	expect_true(
		not FlightWeaponRules.has_asteroid_laser(
			unrelated_configuration,
			registry.modules
		),
		"An unknown utility module must not grant asteroid laser capability.",
		failures
	)

	expect_true(
		FlightWeaponRules.LASER_TARGET_MASK
		== FlightWeaponRules.DESTRUCTIBLE_ASTEROID_LAYER
		and not FlightWeaponRules.is_laser_target_layer(
			FlightWeaponRules.WORLD_COLLISION_LAYER
		)
		and FlightWeaponRules.is_laser_target_layer(
			FlightWeaponRules.DESTRUCTIBLE_ASTEROID_LAYER
		)
		and FlightWeaponRules.is_world_only_layer(
			FlightWeaponRules.WORLD_COLLISION_LAYER
		),
		"Laser target mask must include only explicit destructible asteroids.",
		failures
	)
	expect_true(
		FlightWeaponRules.SHIP_COLLISION_MASK
		== (
			FlightWeaponRules.WORLD_COLLISION_LAYER
			| FlightWeaponRules.DESTRUCTIBLE_ASTEROID_LAYER
		),
		"The ship must still collide with terrain and destructible asteroids.",
		failures
	)
	expect_true(
		String(ProjectSettings.get_setting("layer_names/2d_physics/layer_1", ""))
		== "World"
		and String(ProjectSettings.get_setting("layer_names/2d_physics/layer_2", ""))
		== "DestructibleAsteroid",
		"Project settings must name both collision layers for editor inspection.",
		failures
	)

	var asteroid: DestructibleAsteroid = DestructibleAsteroid.new()
	asteroid.max_durability = 3
	asteroid.reset_asteroid()
	expect_true(
		asteroid.get_current_durability() == 3
		and not asteroid.is_destroyed()
		and asteroid.collision_layer
		== FlightWeaponRules.DESTRUCTIBLE_ASTEROID_LAYER,
		"Asteroid reset must restore durability and its dedicated collision layer.",
		failures
	)
	expect_true(
		asteroid.apply_laser_damage(1)
		and asteroid.get_current_durability() == 2
		and not asteroid.is_destroyed(),
		"A durable asteroid must survive a non-fatal laser hit.",
		failures
	)
	expect_true(
		asteroid.apply_laser_damage(2)
		and asteroid.is_destroyed()
		and asteroid.get_current_durability() == 0
		and asteroid.collision_layer == 0,
		"A destroyed asteroid must stop blocking the route and laser ray.",
		failures
	)
	expect_true(
		not asteroid.apply_laser_damage(1),
		"A destroyed asteroid must ignore additional laser damage.",
		failures
	)
	asteroid.reset_asteroid()
	expect_true(
		asteroid.get_current_durability() == 3
		and not asteroid.is_destroyed()
		and asteroid.collision_layer
		== FlightWeaponRules.DESTRUCTIBLE_ASTEROID_LAYER,
		"Checkpoint reset must be able to restore a destroyed asteroid.",
		failures
	)
	asteroid.free()
	return failures
