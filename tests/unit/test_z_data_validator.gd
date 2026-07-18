extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m0_data_registry.tres"


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	expect_true(registry != null, "Validator fixture registry must load.", failures)
	if registry == null:
		return failures

	var original_order_count: int = registry.orders.size()
	var original_cargo_count: int = registry.cargo_items.size()
	var original_module_count: int = registry.modules.size()
	var original_character_count: int = registry.characters.size()

	var duplicate_character: CharacterDefinition = CharacterDefinition.new()
	duplicate_character.id = registry.characters[0].id
	duplicate_character.display_name_key = &"TEST_DUPLICATE_CHARACTER_NAME"
	duplicate_character.role_key = &"TEST_DUPLICATE_CHARACTER_ROLE"
	registry.characters.append(duplicate_character)

	var empty_id_module: ShipModuleDefinition = ShipModuleDefinition.new()
	empty_id_module.display_name_key = &"TEST_EMPTY_ID_MODULE_NAME"
	empty_id_module.description_key = &"TEST_EMPTY_ID_MODULE_DESCRIPTION"
	registry.modules.append(empty_id_module)

	var invalid_cargo: CargoDefinition = CargoDefinition.new()
	invalid_cargo.id = &"Cargo-Invalid"
	invalid_cargo.display_name_key = &"TEST_INVALID_CARGO_NAME"
	invalid_cargo.company_description_key = &"TEST_INVALID_CARGO_COMPANY_DESCRIPTION"
	invalid_cargo.story_description_key = &"TEST_INVALID_CARGO_STORY_DESCRIPTION"
	invalid_cargo.collision_tolerance = 1.5
	registry.cargo_items.append(invalid_cargo)

	var unregistered_planet: PlanetDefinition = PlanetDefinition.new()
	unregistered_planet.id = &"planet_unregistered"
	unregistered_planet.display_name_key = &"TEST_UNREGISTERED_PLANET_NAME"
	unregistered_planet.description_key = &"TEST_UNREGISTERED_PLANET_DESCRIPTION"
	unregistered_planet.flight_environment_profile = registry.planets[0].flight_environment_profile
	unregistered_planet.flight_scene_path = "res://scenes/flight/flight_level.tscn"

	var missing_reference_order: OrderDefinition = OrderDefinition.new()
	missing_reference_order.id = &"order_missing_references"
	missing_reference_order.display_name_key = &"TEST_MISSING_REFERENCE_ORDER_NAME"
	missing_reference_order.sender = registry.characters[0]
	missing_reference_order.recipient = registry.characters[1]
	missing_reference_order.destination_planet = unregistered_planet
	missing_reference_order.cargo = null
	missing_reference_order.required_modules.append(registry.modules[0])
	registry.orders.append(missing_reference_order)

	var validation_errors: PackedStringArray = GameDataValidator.validate(registry)
	expect_true(
		_contains_error(validation_errors, "Duplicate ID"),
		"Validator must reject duplicate IDs.",
		failures
	)
	expect_true(
		_contains_error(validation_errors, "empty ID"),
		"Validator must reject empty IDs.",
		failures
	)
	expect_true(
		_contains_error(validation_errors, "lower snake_case"),
		"Validator must reject unstable ID formats.",
		failures
	)
	expect_true(
		_contains_error(validation_errors, "collision_tolerance must be between 0 and 1"),
		"Validator must reject illegal numeric values.",
		failures
	)
	expect_true(
		_contains_error(validation_errors, "destination_planet references unregistered"),
		"Validator must reject unregistered resource references.",
		failures
	)
	expect_true(
		_contains_error(validation_errors, "cargo is missing"),
		"Validator must reject missing resource references.",
		failures
	)

	var original_profile: FlightEnvironmentProfile = registry.planets[0].flight_environment_profile
	registry.planets[0].flight_environment_profile = null
	var missing_profile_errors: PackedStringArray = GameDataValidator.validate(registry)
	expect_true(
		_contains_error(missing_profile_errors, "flight_environment_profile is missing"),
		"Validator must reject a planet without a flight environment profile.",
		failures
	)
	registry.planets[0].flight_environment_profile = original_profile

	registry.orders.resize(original_order_count)
	registry.cargo_items.resize(original_cargo_count)
	registry.modules.resize(original_module_count)
	registry.characters.resize(original_character_count)
	return failures


func _contains_error(errors: PackedStringArray, expected_fragment: String) -> bool:
	for error: String in errors:
		if error.contains(expected_fragment):
			return true
	return false
