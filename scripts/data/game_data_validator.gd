class_name GameDataValidator
extends RefCounted

const DEFINITION_ID_PATTERN: String = "^[a-z][a-z0-9_]*$"


## Validates registry-owned definitions and every cross-resource reference without mutating data.
static func validate(registry: GameDataRegistry) -> PackedStringArray:
	var errors: PackedStringArray = []
	if registry == null:
		errors.append("GameDataRegistry is missing.")
		return errors

	var known_ids: Dictionary[StringName, String] = {}
	_validate_planets(registry, known_ids, errors)
	_validate_cargo(registry, known_ids, errors)
	_validate_modules(registry, known_ids, errors)
	_validate_characters(registry, known_ids, errors)
	_validate_orders(registry, known_ids, errors)
	return errors


static func _validate_planets(
	registry: GameDataRegistry,
	known_ids: Dictionary[StringName, String],
	errors: PackedStringArray
) -> void:
	for index: int in registry.planets.size():
		var planet: PlanetDefinition = registry.planets[index]
		if planet == null:
			errors.append("PlanetDefinition at index %d is missing." % index)
			continue

		_register_id("PlanetDefinition", planet.id, known_ids, errors)
		_validate_text_key(planet.id, "display_name_key", planet.display_name_key, errors)
		_validate_text_key(planet.id, "description_key", planet.description_key, errors)
		if not is_finite(planet.gravity_scale) or planet.gravity_scale <= 0.0:
			errors.append("PlanetDefinition '%s' gravity_scale must be finite and greater than 0." % planet.id)
		_validate_flight_environment_profile(planet, errors)
		if planet.flight_scene_path.is_empty():
			errors.append("PlanetDefinition '%s' flight_scene_path is empty." % planet.id)
		elif not ResourceLoader.exists(planet.flight_scene_path):
			errors.append(
				"PlanetDefinition '%s' flight_scene_path does not exist: %s"
				% [planet.id, planet.flight_scene_path]
			)
		_validate_string_names(
			"PlanetDefinition '%s' required_story_flags" % planet.id,
			planet.required_story_flags,
			errors
		)


static func _validate_flight_environment_profile(
	planet: PlanetDefinition,
	errors: PackedStringArray
) -> void:
	var profile: FlightEnvironmentProfile = planet.flight_environment_profile
	if profile == null:
		errors.append(
			"PlanetDefinition '%s' flight_environment_profile is missing." % planet.id
		)
		return
	if profile.id.is_empty():
		errors.append("PlanetDefinition '%s' environment profile has an empty ID." % planet.id)
	elif not _is_valid_definition_id(profile.id):
		errors.append(
			"FlightEnvironmentProfile ID '%s' must use lower snake_case." % profile.id
		)
	_validate_text_key(profile.id, "display_name_key", profile.display_name_key, errors)
	if not is_finite(profile.planet_gravity) or profile.planet_gravity < 0.0:
		errors.append(
			"FlightEnvironmentProfile '%s' planet_gravity must be finite and non-negative."
			% profile.id
		)
	if (
		not is_finite(profile.target_gravity_blend)
		or profile.target_gravity_blend < 0.0
		or profile.target_gravity_blend > 1.0
	):
		errors.append(
			"FlightEnvironmentProfile '%s' target_gravity_blend must be between 0 and 1."
			% profile.id
		)
	if (
		not is_finite(profile.target_air_density)
		or profile.target_air_density < 0.0
		or profile.target_air_density > 1.0
	):
		errors.append(
			"FlightEnvironmentProfile '%s' target_air_density must be between 0 and 1."
			% profile.id
		)
	if (
		not is_finite(profile.horizontal_drag)
		or profile.horizontal_drag < 0.0
		or not is_finite(profile.vertical_drag)
		or profile.vertical_drag < 0.0
	):
		errors.append(
			"FlightEnvironmentProfile '%s' drag coefficients must be finite and non-negative."
			% profile.id
		)
	if (
		not is_finite(profile.terminal_fall_speed_safety)
		or profile.terminal_fall_speed_safety < 0.0
	):
		errors.append(
			"FlightEnvironmentProfile '%s' terminal_fall_speed_safety must be non-negative."
			% profile.id
		)
	elif (
		profile.target_gravity_blend > 0.0
		and profile.terminal_fall_speed_safety <= 0.0
	):
		errors.append(
			"FlightEnvironmentProfile '%s' with gravity must define a positive terminal fall safety."
			% profile.id
		)
	if not is_finite(profile.transition_rate) or profile.transition_rate <= 0.0:
		errors.append(
			"FlightEnvironmentProfile '%s' transition_rate must be positive." % profile.id
		)


static func _validate_cargo(
	registry: GameDataRegistry,
	known_ids: Dictionary[StringName, String],
	errors: PackedStringArray
) -> void:
	for index: int in registry.cargo_items.size():
		var cargo: CargoDefinition = registry.cargo_items[index]
		if cargo == null:
			errors.append("CargoDefinition at index %d is missing." % index)
			continue

		_register_id("CargoDefinition", cargo.id, known_ids, errors)
		_validate_text_key(cargo.id, "display_name_key", cargo.display_name_key, errors)
		_validate_text_key(
			cargo.id,
			"company_description_key",
			cargo.company_description_key,
			errors
		)
		_validate_text_key(cargo.id, "story_description_key", cargo.story_description_key, errors)
		if (
			cargo.boost_policy < CargoDefinition.BoostPolicy.ALLOWED
			or cargo.boost_policy > CargoDefinition.BoostPolicy.FORBIDDEN
		):
			errors.append("CargoDefinition '%s' boost_policy is invalid." % cargo.id)
		if (
			not is_finite(cargo.collision_tolerance)
			or cargo.collision_tolerance < 0.0
			or cargo.collision_tolerance > 1.0
		):
			errors.append(
				"CargoDefinition '%s' collision_tolerance must be between 0 and 1." % cargo.id
			)
		_validate_string_names(
			"CargoDefinition '%s' attraction_risk_tags" % cargo.id,
			cargo.attraction_risk_tags,
			errors
		)


static func _validate_modules(
	registry: GameDataRegistry,
	known_ids: Dictionary[StringName, String],
	errors: PackedStringArray
) -> void:
	for index: int in registry.modules.size():
		var module: ShipModuleDefinition = registry.modules[index]
		if module == null:
			errors.append("ShipModuleDefinition at index %d is missing." % index)
			continue

		_register_id("ShipModuleDefinition", module.id, known_ids, errors)
		_validate_text_key(module.id, "display_name_key", module.display_name_key, errors)
		_validate_text_key(module.id, "description_key", module.description_key, errors)
		if (
			module.slot_type < ShipModuleDefinition.SlotType.POWER
			or module.slot_type > ShipModuleDefinition.SlotType.UTILITY
		):
			errors.append("ShipModuleDefinition '%s' slot_type is invalid." % module.id)
		var configuration_slot_id: StringName = (
			ShipLoadoutRules.get_configuration_slot_id(module)
		)
		if not ShipLoadoutRules.is_valid_slot_id(configuration_slot_id):
			errors.append(
				"ShipModuleDefinition '%s' configuration slot '%s' is invalid."
				% [module.id, configuration_slot_id]
			)
		if module.cost < 0:
			errors.append("ShipModuleDefinition '%s' cost cannot be negative." % module.id)
		for stat_id: StringName in module.stat_modifiers:
			if stat_id.is_empty():
				errors.append("ShipModuleDefinition '%s' has an empty stat modifier ID." % module.id)
			elif not is_finite(module.stat_modifiers[stat_id]):
				errors.append(
					"ShipModuleDefinition '%s' stat '%s' must be finite." % [module.id, stat_id]
				)
		_validate_string_names(
			"ShipModuleDefinition '%s' capability_tags" % module.id,
			module.capability_tags,
			errors
		)
		_validate_string_names(
			"ShipModuleDefinition '%s' story_unlock_flags" % module.id,
			module.story_unlock_flags,
			errors
		)


static func _validate_characters(
	registry: GameDataRegistry,
	known_ids: Dictionary[StringName, String],
	errors: PackedStringArray
) -> void:
	for index: int in registry.characters.size():
		var character: CharacterDefinition = registry.characters[index]
		if character == null:
			errors.append("CharacterDefinition at index %d is missing." % index)
			continue

		_register_id("CharacterDefinition", character.id, known_ids, errors)
		_validate_text_key(character.id, "display_name_key", character.display_name_key, errors)
		_validate_text_key(character.id, "role_key", character.role_key, errors)


static func _validate_orders(
	registry: GameDataRegistry,
	known_ids: Dictionary[StringName, String],
	errors: PackedStringArray
) -> void:
	for index: int in registry.orders.size():
		var order: OrderDefinition = registry.orders[index]
		if order == null:
			errors.append("OrderDefinition at index %d is missing." % index)
			continue

		_register_id("OrderDefinition", order.id, known_ids, errors)
		_validate_text_key(order.id, "display_name_key", order.display_name_key, errors)
		if order.order_type < OrderDefinition.OrderType.MAIN or order.order_type > OrderDefinition.OrderType.SIDE:
			errors.append("OrderDefinition '%s' order_type is invalid." % order.id)
		if order.reward_credits < 0:
			errors.append("OrderDefinition '%s' reward_credits cannot be negative." % order.id)
		if not is_finite(order.route_distance) or order.route_distance <= 0.0:
			errors.append("OrderDefinition '%s' route_distance must be finite and greater than 0." % order.id)
		if order.risk_level < 0 or order.risk_level > 5:
			errors.append("OrderDefinition '%s' risk_level must be between 0 and 5." % order.id)
		if (
			order.delivery_method < OrderDefinition.DeliveryMethod.LANDING
			or order.delivery_method > OrderDefinition.DeliveryMethod.DOCKING
		):
			errors.append("OrderDefinition '%s' delivery_method is invalid." % order.id)

		_validate_character_reference(registry, order, "sender", order.sender, errors)
		_validate_character_reference(registry, order, "recipient", order.recipient, errors)
		_validate_planet_reference(registry, order, order.destination_planet, errors)
		_validate_cargo_reference(registry, order, order.cargo, errors)
		_validate_module_references(
			registry,
			order,
			"required_modules",
			order.required_modules,
			errors
		)
		_validate_module_references(
			registry,
			order,
			"recommended_modules",
			order.recommended_modules,
			errors
		)
		for required_module: ShipModuleDefinition in order.required_modules:
			if required_module != null and order.recommended_modules.has(required_module):
				errors.append(
					"OrderDefinition '%s' lists module '%s' as both required and recommended."
					% [order.id, required_module.id]
				)

		_validate_string_names(
			"OrderDefinition '%s' customer_history_keys" % order.id,
			order.customer_history_keys,
			errors
		)
		_validate_string_names(
			"OrderDefinition '%s' story_requirements" % order.id,
			order.story_requirements,
			errors
		)
		_validate_string_names(
			"OrderDefinition '%s' completion_flags" % order.id,
			order.completion_flags,
			errors
		)


static func _register_id(
	type_name: String,
	definition_id: StringName,
	known_ids: Dictionary[StringName, String],
	errors: PackedStringArray
) -> void:
	if definition_id.is_empty():
		errors.append("%s has an empty ID." % type_name)
		return
	if not _is_valid_definition_id(definition_id):
		errors.append("%s ID '%s' must use lower snake_case." % [type_name, definition_id])
	if known_ids.has(definition_id):
		errors.append(
			"Duplicate ID '%s' found in %s and %s."
			% [definition_id, known_ids[definition_id], type_name]
		)
	else:
		known_ids[definition_id] = type_name


static func _is_valid_definition_id(definition_id: StringName) -> bool:
	var pattern: RegEx = RegEx.new()
	if pattern.compile(DEFINITION_ID_PATTERN) != OK:
		return false
	return pattern.search(String(definition_id)) != null


static func _validate_text_key(
	definition_id: StringName,
	field_name: String,
	text_key: StringName,
	errors: PackedStringArray
) -> void:
	if text_key.is_empty():
		errors.append("Definition '%s' %s is empty." % [definition_id, field_name])


static func _validate_string_names(
	field_label: String,
	values: Array[StringName],
	errors: PackedStringArray
) -> void:
	var seen_values: Dictionary[StringName, bool] = {}
	for index: int in values.size():
		var value: StringName = values[index]
		if value.is_empty():
			errors.append("%s contains an empty value at index %d." % [field_label, index])
		elif seen_values.has(value):
			errors.append("%s contains duplicate value '%s'." % [field_label, value])
		else:
			seen_values[value] = true


static func _validate_character_reference(
	registry: GameDataRegistry,
	order: OrderDefinition,
	field_name: String,
	character: CharacterDefinition,
	errors: PackedStringArray
) -> void:
	if character == null:
		errors.append("OrderDefinition '%s' %s is missing." % [order.id, field_name])
		return
	if registry.find_character(character.id) != character:
		errors.append(
			"OrderDefinition '%s' %s references unregistered CharacterDefinition ID '%s'."
			% [order.id, field_name, character.id]
		)


static func _validate_planet_reference(
	registry: GameDataRegistry,
	order: OrderDefinition,
	planet: PlanetDefinition,
	errors: PackedStringArray
) -> void:
	if planet == null:
		errors.append("OrderDefinition '%s' destination_planet is missing." % order.id)
		return
	if registry.find_planet(planet.id) != planet:
		errors.append(
			"OrderDefinition '%s' destination_planet references unregistered PlanetDefinition ID '%s'."
			% [order.id, planet.id]
		)


static func _validate_cargo_reference(
	registry: GameDataRegistry,
	order: OrderDefinition,
	cargo: CargoDefinition,
	errors: PackedStringArray
) -> void:
	if cargo == null:
		errors.append("OrderDefinition '%s' cargo is missing." % order.id)
		return
	if registry.find_cargo(cargo.id) != cargo:
		errors.append(
			"OrderDefinition '%s' cargo references unregistered CargoDefinition ID '%s'."
			% [order.id, cargo.id]
		)


static func _validate_module_references(
	registry: GameDataRegistry,
	order: OrderDefinition,
	field_name: String,
	modules: Array[ShipModuleDefinition],
	errors: PackedStringArray
) -> void:
	var seen_modules: Dictionary[StringName, bool] = {}
	for index: int in modules.size():
		var module: ShipModuleDefinition = modules[index]
		if module == null:
			errors.append(
				"OrderDefinition '%s' %s contains a missing module at index %d."
				% [order.id, field_name, index]
			)
			continue
		if registry.find_module(module.id) != module:
			errors.append(
				"OrderDefinition '%s' %s references unregistered ShipModuleDefinition ID '%s'."
				% [order.id, field_name, module.id]
			)
		if seen_modules.has(module.id):
			errors.append(
				"OrderDefinition '%s' %s contains duplicate module '%s'."
				% [order.id, field_name, module.id]
			)
		else:
			seen_modules[module.id] = true
