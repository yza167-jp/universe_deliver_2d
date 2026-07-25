class_name GameDataValidator
extends RefCounted

const DEFINITION_ID_PATTERN: String = "^[a-z][a-z0-9_]*$"
const M1_REGISTRY_ID: StringName = &"m1_four_planet_demo"
const M1_ACTUAL_M0_ORDER_ID: StringName = &"order_red_sand_m0"
const M1_CANONICAL_M0_ORDER_ALIAS: StringName = &"order_red_sand_cooling_core"
const M1_STRETCH_ORDER_ID: StringName = &"side_red_sand_unlisted_filters"
const M1_HIGH_VOLTAGE_MODULE_ID: StringName = &"module_high_voltage_shielding"
const M1_RED_SAND_REVISIT_ORDER_ID: StringName = (
	&"order_m1_red_sand_shielding_retrofit"
)
const M1_WHITE_NOISE_ORDER_ID: StringName = &"order_m1_white_noise_archive_core"
const M1_CANOPY_SIDE_ORDER_ID: StringName = &"side_canopy_spore_drop"
const M1_TIDAL_SIDE_ORDER_ID: StringName = &"side_tidal_beacon_before_eye"
const M1_REQUIRED_PLANET_IDS: Array[StringName] = [
	&"planet_red_sand",
	&"planet_white_noise",
	&"planet_canopy_world",
	&"planet_tidal_archipelago",
]
const M1_NEW_PLANET_IDS: Array[StringName] = [
	&"planet_white_noise",
	&"planet_canopy_world",
	&"planet_tidal_archipelago",
]
const M1_REQUIRED_ORDER_IDS: Array[StringName] = [
	M1_ACTUAL_M0_ORDER_ID,
	M1_RED_SAND_REVISIT_ORDER_ID,
	M1_WHITE_NOISE_ORDER_ID,
	&"order_m1_canopy_ecology_cargo",
	&"order_m1_tidal_weather_core",
	M1_CANOPY_SIDE_ORDER_ID,
	&"side_white_noise_returned_memory",
	M1_TIDAL_SIDE_ORDER_ID,
]
const M1_REQUIRED_SIDE_ORDER_IDS: Array[StringName] = [
	&"side_white_noise_returned_memory",
	M1_CANOPY_SIDE_ORDER_ID,
	M1_TIDAL_SIDE_ORDER_ID,
]


## Validates registry-owned definitions and every cross-resource reference without mutating data.
static func validate(registry: GameDataRegistry) -> PackedStringArray:
	var errors: PackedStringArray = []
	if registry == null:
		errors.append("GameDataRegistry is missing.")
		return errors

	var known_ids: Dictionary[StringName, String] = {}
	if (
		not registry.registry_id.is_empty()
		and not _is_valid_definition_id(registry.registry_id)
	):
		errors.append(
			"GameDataRegistry ID '%s' must use lower snake_case." % registry.registry_id
		)
	_validate_planets(registry, known_ids, errors)
	_validate_cargo(registry, known_ids, errors)
	_validate_modules(registry, known_ids, errors)
	_validate_characters(registry, known_ids, errors)
	_validate_codex_entries(registry, known_ids, errors)
	_validate_souvenirs(registry, known_ids, errors)
	_validate_orders(registry, known_ids, errors)
	_validate_order_aliases(registry, known_ids, errors)
	_validate_m1_packet_contract(registry, errors)
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
		_validate_flight_environment_profile(planet, known_ids, errors)
		if (
			planet.content_readiness < PlanetDefinition.ContentReadiness.REGISTERED_ONLY
			or planet.content_readiness > PlanetDefinition.ContentReadiness.PLAYABLE
		):
			errors.append("PlanetDefinition '%s' content_readiness is invalid." % planet.id)
		elif planet.is_playable():
			if planet.flight_scene_path.is_empty():
				errors.append(
					"PlanetDefinition '%s' playable content requires a flight_scene_path."
					% planet.id
				)
			elif not ResourceLoader.exists(planet.flight_scene_path):
				errors.append(
					"PlanetDefinition '%s' flight_scene_path does not exist: %s"
					% [planet.id, planet.flight_scene_path]
				)
		elif not planet.flight_scene_path.is_empty():
			errors.append(
				"PlanetDefinition '%s' registered-only content must not declare a flight_scene_path."
				% planet.id
			)
		_validate_string_names(
			"PlanetDefinition '%s' required_story_flags" % planet.id,
			planet.required_story_flags,
			errors
		)


static func _validate_flight_environment_profile(
	planet: PlanetDefinition,
	known_ids: Dictionary[StringName, String],
	errors: PackedStringArray
) -> void:
	var profile: FlightEnvironmentProfile = planet.flight_environment_profile
	if profile == null:
		errors.append(
			"PlanetDefinition '%s' flight_environment_profile is missing." % planet.id
		)
		return
	_register_id("FlightEnvironmentProfile", profile.id, known_ids, errors)
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
		if (
			order.order_type < OrderDefinition.OrderType.MAIN
			or order.order_type > OrderDefinition.OrderType.REVISIT
		):
			errors.append("OrderDefinition '%s' order_type is invalid." % order.id)
		if (
			order.content_readiness < OrderDefinition.ContentReadiness.REGISTERED_ONLY
			or order.content_readiness > OrderDefinition.ContentReadiness.PLAYABLE
		):
			errors.append(
				"OrderDefinition '%s' content_readiness is invalid." % order.id
			)
		if (
			order.repeat_policy < OrderDefinition.RepeatPolicy.UNIQUE
			or order.repeat_policy > OrderDefinition.RepeatPolicy.ARCHIVED_ONLY
		):
			errors.append("OrderDefinition '%s' repeat_policy is invalid." % order.id)
		elif (
			order.is_mainline()
			and order.repeat_policy != OrderDefinition.RepeatPolicy.UNIQUE
		):
			errors.append(
				"OrderDefinition '%s' mainline orders must use UNIQUE repeat_policy."
				% order.id
			)
		if order.credit_reward < 0:
			errors.append("OrderDefinition '%s' credit_reward cannot be negative." % order.id)
		if not is_finite(order.route_distance) or order.route_distance <= 0.0:
			errors.append("OrderDefinition '%s' route_distance must be finite and greater than 0." % order.id)
		if order.risk_level < 0 or order.risk_level > 5:
			errors.append("OrderDefinition '%s' risk_level must be between 0 and 5." % order.id)
		if (
			order.delivery_type < OrderDefinition.DeliveryType.LANDING
			or order.delivery_type > OrderDefinition.DeliveryType.LOW_ALTITUDE_DROP
		):
			errors.append("OrderDefinition '%s' delivery_type is invalid." % order.id)
		if (
			not order.required_chapter.is_empty()
			and not M1ProgressRules.is_known_chapter(order.required_chapter)
		):
			errors.append(
				"OrderDefinition '%s' references unknown chapter_id '%s'."
				% [order.id, order.required_chapter]
			)
		if order.planet_id.is_empty():
			errors.append("OrderDefinition '%s' planet_id is empty." % order.id)
		elif registry.find_planet(order.planet_id) == null:
			errors.append(
				"OrderDefinition '%s' references unknown planet_id '%s'."
				% [order.id, order.planet_id]
			)
		if order.destination_id.is_empty():
			errors.append("OrderDefinition '%s' destination_id is empty." % order.id)
		elif not _is_valid_definition_id(order.destination_id):
			errors.append(
				"OrderDefinition '%s' destination_id '%s' must use lower snake_case."
				% [order.id, order.destination_id]
			)
		_validate_express_configuration(order, errors)

		_validate_character_reference(registry, order, "sender", order.sender, errors)
		_validate_character_reference(registry, order, "recipient", order.recipient, errors)
		_validate_planet_reference(registry, order, order.destination_planet, errors)
		if (
			order.destination_planet != null
			and not order.planet_id.is_empty()
			and order.destination_planet.id != order.planet_id
		):
			errors.append(
				"OrderDefinition '%s' planet_id does not match destination_planet."
				% order.id
			)
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
			if (
				required_module != null
				and _order_module_list_has_id(
					order.recommended_modules,
					required_module.id
				)
			):
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
			"OrderDefinition '%s' required_completed_order_ids" % order.id,
			order.required_completed_order_ids,
			errors
		)
		for required_order_id: StringName in order.required_completed_order_ids:
			if registry.find_order(required_order_id) == null:
				errors.append(
					"OrderDefinition '%s' requires unknown completed order '%s'."
					% [order.id, required_order_id]
				)
		_validate_string_names(
			"OrderDefinition '%s' completion_flags" % order.id,
			order.completion_flags,
			errors
		)
		_validate_order_unlock_conditions(registry, order, errors)
		_validate_order_rewards(registry, order, errors)


static func _validate_codex_entries(
	registry: GameDataRegistry,
	known_ids: Dictionary[StringName, String],
	errors: PackedStringArray
) -> void:
	for index: int in registry.codex_entries.size():
		var entry: CodexEntryDefinition = registry.codex_entries[index]
		if entry == null:
			errors.append("CodexEntryDefinition at index %d is missing." % index)
			continue
		_register_id("CodexEntryDefinition", entry.id, known_ids, errors)
		if not M1ProgressRules.is_valid_codex_entry_id(entry.id):
			errors.append("Invalid registered codex reward ID '%s'." % entry.id)
		if (
			entry.category < CodexEntryDefinition.Category.PLANET
			or entry.category > CodexEntryDefinition.Category.SOUVENIR
		):
			errors.append("CodexEntryDefinition '%s' category is invalid." % entry.id)
		_validate_text_key(entry.id, "title_key", entry.title_key, errors)
		_validate_text_key(entry.id, "description_key", entry.description_key, errors)
		_validate_related_planet_id(
			registry,
			"CodexEntryDefinition",
			entry.id,
			entry.related_planet_id,
			errors
		)


static func _validate_souvenirs(
	registry: GameDataRegistry,
	known_ids: Dictionary[StringName, String],
	errors: PackedStringArray
) -> void:
	for index: int in registry.souvenirs.size():
		var souvenir: SouvenirDefinition = registry.souvenirs[index]
		if souvenir == null:
			errors.append("SouvenirDefinition at index %d is missing." % index)
			continue
		_register_id("SouvenirDefinition", souvenir.id, known_ids, errors)
		if not M1ProgressRules.is_valid_souvenir_id(souvenir.id):
			errors.append("Invalid registered souvenir reward ID '%s'." % souvenir.id)
		_validate_text_key(
			souvenir.id,
			"display_name_key",
			souvenir.display_name_key,
			errors
		)
		_validate_text_key(
			souvenir.id,
			"description_key",
			souvenir.description_key,
			errors
		)
		_validate_related_planet_id(
			registry,
			"SouvenirDefinition",
			souvenir.id,
			souvenir.related_planet_id,
			errors
		)


static func _validate_order_aliases(
	registry: GameDataRegistry,
	known_ids: Dictionary[StringName, String],
	errors: PackedStringArray
) -> void:
	for alias_id: StringName in registry.order_aliases:
		var actual_id: StringName = registry.order_aliases.get(alias_id, &"")
		if not _is_valid_definition_id(alias_id):
			errors.append("Order alias ID '%s' must use lower snake_case." % alias_id)
		if not _is_valid_definition_id(actual_id):
			errors.append(
				"Order alias '%s' target '%s' must use lower snake_case."
				% [alias_id, actual_id]
			)
		if alias_id == actual_id:
			errors.append("Order alias '%s' cannot target itself." % alias_id)
		if known_ids.has(alias_id):
			errors.append(
				"Order alias '%s' duplicates a registered definition ID." % alias_id
			)
		var actual_order_count: int = 0
		for order: OrderDefinition in registry.orders:
			if order != null and order.id == actual_id:
				actual_order_count += 1
		if actual_order_count != 1:
			errors.append(
				"Order alias '%s' must target exactly one registered OrderDefinition '%s'."
				% [alias_id, actual_id]
			)


static func _validate_related_planet_id(
	registry: GameDataRegistry,
	type_name: String,
	definition_id: StringName,
	planet_id: StringName,
	errors: PackedStringArray
) -> void:
	if planet_id.is_empty():
		errors.append("%s '%s' related_planet_id is empty." % [type_name, definition_id])
	elif registry.find_planet(planet_id) == null:
		errors.append(
			"%s '%s' references unknown related_planet_id '%s'."
			% [type_name, definition_id, planet_id]
		)


static func _validate_m1_packet_contract(
	registry: GameDataRegistry,
	errors: PackedStringArray
) -> void:
	if not _contains_m1_packet_content(registry):
		return
	for planet_id: StringName in M1_REQUIRED_PLANET_IDS:
		if registry.find_planet(planet_id) == null:
			errors.append("M1 registry is missing required planet '%s'." % planet_id)
	for planet_id: StringName in M1_NEW_PLANET_IDS:
		var planet: PlanetDefinition = registry.find_planet(planet_id)
		if planet == null:
			continue
		if planet.content_readiness != PlanetDefinition.ContentReadiness.REGISTERED_ONLY:
			errors.append(
				"M1 planet '%s' must remain REGISTERED_ONLY until its route task lands."
				% planet_id
			)
		if not planet.flight_scene_path.is_empty():
			errors.append(
				"M1 planet '%s' must not borrow a playable flight scene." % planet_id
			)
	for order_id: StringName in M1_REQUIRED_ORDER_IDS:
		var order: OrderDefinition = registry.find_order(order_id)
		if order == null:
			errors.append("M1 registry is missing required order '%s'." % order_id)
			continue
		if (
			order_id in [
				M1_ACTUAL_M0_ORDER_ID,
				M1_RED_SAND_REVISIT_ORDER_ID,
			]
			and order.content_readiness
			!= OrderDefinition.ContentReadiness.PLAYABLE
		):
			errors.append(
				"M1 implemented order '%s' must remain PLAYABLE." % order_id
			)
		elif (
			order_id not in [
				M1_ACTUAL_M0_ORDER_ID,
				M1_RED_SAND_REVISIT_ORDER_ID,
			]
			and order.content_readiness
			!= OrderDefinition.ContentReadiness.REGISTERED_ONLY
		):
			errors.append(
				"M1 order '%s' must remain REGISTERED_ONLY until its route task lands."
				% order_id
			)
	if registry.find_order(M1_STRETCH_ORDER_ID) != null:
		errors.append(
			"M1 required registry must not include Stretch order '%s'."
			% M1_STRETCH_ORDER_ID
		)
	if (
		registry.order_aliases.get(M1_CANONICAL_M0_ORDER_ALIAS, &"")
		!= M1_ACTUAL_M0_ORDER_ID
	):
		errors.append(
			"M1 canonical M0 order alias must resolve '%s' to '%s'."
			% [M1_CANONICAL_M0_ORDER_ALIAS, M1_ACTUAL_M0_ORDER_ID]
		)
	var actual_m0_order_count: int = 0
	for order: OrderDefinition in registry.orders:
		if order != null and order.id == M1_ACTUAL_M0_ORDER_ID:
			actual_m0_order_count += 1
	if actual_m0_order_count != 1:
		errors.append("M1 registry must contain exactly one actual M0 order Resource.")
	for side_order_id: StringName in M1_REQUIRED_SIDE_ORDER_IDS:
		var side_order: OrderDefinition = registry.find_order(side_order_id)
		if (
			side_order != null
			and side_order.repeat_policy == OrderDefinition.RepeatPolicy.ARCHIVED_ONLY
		):
			errors.append(
				"M1 required side order '%s' cannot use ARCHIVED_ONLY." % side_order_id
			)
	var revisit_order: OrderDefinition = registry.find_order(
		M1_RED_SAND_REVISIT_ORDER_ID
	)
	if revisit_order != null:
		if not is_equal_approx(revisit_order.route_distance, 12000.0):
			errors.append(
				"M1 Red Sand revisit must expose its 12000 m playable route."
			)
		if not revisit_order.required_completed_order_ids.has(
			M1_ACTUAL_M0_ORDER_ID
		):
			errors.append(
				"M1 Red Sand revisit must require the completed M0 order."
			)
		if not revisit_order.ship_upgrade_rewards.has(
			M1_HIGH_VOLTAGE_MODULE_ID
		):
			errors.append(
				"M1 Red Sand revisit must reward high-voltage shielding."
			)
		if not revisit_order.station_state_rewards.has(
			StationStateRules.ARCHIVE_TERMINAL_ID
		):
			errors.append(
				"M1 Red Sand revisit must unlock the archive terminal."
			)
		if (
			revisit_order.chapter_reward
			!= M1ProgressRules.CHAPTER_M1_WHITE_NOISE
		):
			errors.append(
				"M1 Red Sand revisit must advance to the White Noise chapter."
			)
		if (
			revisit_order.revisit_state_rewards.get(
				M1ProgressRules.PLANET_RED_SAND,
				&""
			)
			!= M1ProgressRules.REVISIT_RED_SAND_COMPLETED
		):
			errors.append(
				"M1 Red Sand revisit must record its completed revisit state."
			)
	var high_voltage_reward_sources: int = 0
	for order: OrderDefinition in registry.orders:
		if (
			order != null
			and order.ship_upgrade_rewards.has(M1_HIGH_VOLTAGE_MODULE_ID)
		):
			high_voltage_reward_sources += 1
	var high_voltage_module: ShipModuleDefinition = registry.find_module(
		M1_HIGH_VOLTAGE_MODULE_ID
	)
	if (
		high_voltage_reward_sources != 1
		or high_voltage_module == null
		or high_voltage_module.cost != 0
	):
		errors.append(
			"M1 high-voltage shielding must have one free mainline reward source."
		)
	var white_noise_order: OrderDefinition = registry.find_order(M1_WHITE_NOISE_ORDER_ID)
	if (
		white_noise_order != null
		and not _order_module_list_has_id(
			white_noise_order.required_modules,
			M1_HIGH_VOLTAGE_MODULE_ID
		)
	):
		errors.append(
			"M1 White Noise main order must require '%s'."
			% M1_HIGH_VOLTAGE_MODULE_ID
		)
	var canopy_side_order: OrderDefinition = registry.find_order(M1_CANOPY_SIDE_ORDER_ID)
	if (
		canopy_side_order != null
		and canopy_side_order.delivery_type
		!= OrderDefinition.DeliveryType.LOW_ALTITUDE_DROP
	):
		errors.append("M1 Canopy side order must use LOW_ALTITUDE_DROP.")
	var tidal_side_order: OrderDefinition = registry.find_order(M1_TIDAL_SIDE_ORDER_ID)
	if tidal_side_order != null and not tidal_side_order.is_express:
		errors.append("M1 Tidal side order must be express.")


static func _contains_m1_packet_content(registry: GameDataRegistry) -> bool:
	return registry.registry_id == M1_REGISTRY_ID


static func _order_module_list_has_id(
	modules: Array[ShipModuleDefinition],
	module_id: StringName
) -> bool:
	for module: ShipModuleDefinition in modules:
		if module != null and module.id == module_id:
			return true
	return false


static func _validate_express_configuration(
	order: OrderDefinition,
	errors: PackedStringArray
) -> void:
	if order.is_express:
		if not is_finite(order.target_seconds) or order.target_seconds <= 0.0:
			errors.append(
				"OrderDefinition '%s' express target_seconds must be positive."
				% order.id
			)
		if not is_finite(order.grace_seconds) or order.grace_seconds < 0.0:
			errors.append(
				"OrderDefinition '%s' express grace_seconds cannot be negative."
				% order.id
			)
		if (
			not is_finite(order.minimum_reward_ratio)
			or order.minimum_reward_ratio < 0.0
			or order.minimum_reward_ratio > 1.0
		):
			errors.append(
				"OrderDefinition '%s' minimum_reward_ratio must be between 0 and 1."
				% order.id
			)
		if order.relation_bonus_on_time < 0:
			errors.append(
				"OrderDefinition '%s' relation_bonus_on_time cannot be negative."
				% order.id
			)
		return
	if (
		not is_zero_approx(order.target_seconds)
		or not is_zero_approx(order.grace_seconds)
		or not is_equal_approx(order.minimum_reward_ratio, 1.0)
		or order.relation_bonus_on_time != 0
	):
		errors.append(
			"OrderDefinition '%s' non-express timing fields must use neutral defaults."
			% order.id
		)


static func _validate_order_unlock_conditions(
	registry: GameDataRegistry,
	order: OrderDefinition,
	errors: PackedStringArray
) -> void:
	var seen_conditions: Dictionary[StringName, bool] = {}
	for index: int in order.unlock_conditions.size():
		var condition: OrderUnlockCondition = order.unlock_conditions[index]
		if condition == null:
			errors.append(
				"OrderDefinition '%s' unlock_conditions contains a missing condition at index %d."
				% [order.id, index]
			)
			continue
		if condition.reference_id.is_empty():
			errors.append(
				"OrderDefinition '%s' unlock condition at index %d has an empty reference ID."
				% [order.id, index]
			)
			continue
		var condition_key: StringName = StringName(
			"%d/%s" % [condition.condition_type, condition.reference_id]
		)
		if seen_conditions.has(condition_key):
			errors.append(
				"OrderDefinition '%s' has duplicate unlock condition '%s'."
				% [order.id, condition_key]
			)
		else:
			seen_conditions[condition_key] = true
		match condition.condition_type:
			OrderUnlockCondition.ConditionType.PLANET_UNLOCKED:
				if (
					not M1ProgressRules.is_known_planet(condition.reference_id)
					or registry.find_planet(condition.reference_id) == null
				):
					errors.append(
						"OrderDefinition '%s' unlock condition references unknown planet_id '%s'."
						% [order.id, condition.reference_id]
					)
			OrderUnlockCondition.ConditionType.PERMISSION_GRANTED:
				if not M1ProgressRules.is_known_permission(condition.reference_id):
					errors.append(
						"OrderDefinition '%s' unlock condition references unknown permission ID '%s'."
						% [order.id, condition.reference_id]
					)
			OrderUnlockCondition.ConditionType.MODULE_AVAILABLE:
				if registry.find_module(condition.reference_id) == null:
					errors.append(
						"OrderDefinition '%s' unlock condition references unknown module ID '%s'."
						% [order.id, condition.reference_id]
					)
			_:
				errors.append(
					"OrderDefinition '%s' unlock condition type is invalid."
					% order.id
				)


static func _validate_order_rewards(
	registry: GameDataRegistry,
	order: OrderDefinition,
	errors: PackedStringArray
) -> void:
	for planet_id: StringName in order.relation_rewards:
		var relation_delta: int = order.relation_rewards.get(planet_id, 0)
		if registry.find_planet(planet_id) == null:
			errors.append(
				"OrderDefinition '%s' relation reward references unknown planet_id '%s'."
				% [order.id, planet_id]
			)
		if relation_delta == 0:
			errors.append(
				"OrderDefinition '%s' relation reward for '%s' cannot be zero."
				% [order.id, planet_id]
			)
	_validate_string_names(
		"OrderDefinition '%s' permission_rewards" % order.id,
		order.permission_rewards,
		errors
	)
	for permission_id: StringName in order.permission_rewards:
		if not M1ProgressRules.is_known_permission(permission_id):
			errors.append(
				"OrderDefinition '%s' references unknown permission reward ID '%s'."
				% [order.id, permission_id]
			)
	_validate_string_names(
		"OrderDefinition '%s' codex_rewards" % order.id,
		order.codex_rewards,
		errors
	)
	for entry_id: StringName in order.codex_rewards:
		if not registry.has_codex_reward_id(entry_id):
			errors.append(
				"OrderDefinition '%s' references unknown codex reward ID '%s'."
				% [order.id, entry_id]
			)
	_validate_string_names(
		"OrderDefinition '%s' souvenir_rewards" % order.id,
		order.souvenir_rewards,
		errors
	)
	for souvenir_id: StringName in order.souvenir_rewards:
		if not registry.has_souvenir_reward_id(souvenir_id):
			errors.append(
				"OrderDefinition '%s' references unknown souvenir reward ID '%s'."
				% [order.id, souvenir_id]
			)
	_validate_string_names(
		"OrderDefinition '%s' ship_upgrade_rewards" % order.id,
		order.ship_upgrade_rewards,
		errors
	)
	for module_id: StringName in order.ship_upgrade_rewards:
		if registry.find_module(module_id) == null:
			errors.append(
				"OrderDefinition '%s' references unknown ship upgrade reward '%s'."
				% [order.id, module_id]
			)
	_validate_string_names(
		"OrderDefinition '%s' station_state_rewards" % order.id,
		order.station_state_rewards,
		errors
	)
	for state_id: StringName in order.station_state_rewards:
		if not StationStateRules.is_known_state_id(state_id):
			errors.append(
				"OrderDefinition '%s' references unknown station state reward '%s'."
				% [order.id, state_id]
			)
	if (
		not order.chapter_reward.is_empty()
		and not M1ProgressRules.is_known_chapter(order.chapter_reward)
	):
		errors.append(
			"OrderDefinition '%s' references unknown chapter reward '%s'."
			% [order.id, order.chapter_reward]
		)
	for planet_id: StringName in order.revisit_state_rewards:
		var state_id: StringName = order.revisit_state_rewards.get(
			planet_id,
			&""
		)
		if (
			not M1ProgressRules.is_known_planet(planet_id)
			or not M1ProgressRules.is_valid_revisit_state_id(state_id)
		):
			errors.append(
				"OrderDefinition '%s' has invalid revisit reward '%s'='%s'."
				% [order.id, planet_id, state_id]
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
