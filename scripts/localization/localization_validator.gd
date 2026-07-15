class_name LocalizationValidator
extends RefCounted


static func validate_keys(
	keys_by_label: Dictionary[String, StringName],
	catalog: LocalizationCatalog,
	required_locales: PackedStringArray
) -> PackedStringArray:
	var errors: PackedStringArray = []
	if catalog == null:
		return PackedStringArray(["Localization catalog is missing."])

	for catalog_error: String in catalog.errors:
		errors.append(catalog_error)
	for label: String in keys_by_label:
		_validate_key(label, keys_by_label[label], catalog, required_locales, errors)
	return errors


static func validate_registry(
	registry: GameDataRegistry,
	catalog: LocalizationCatalog,
	required_locales: PackedStringArray
) -> PackedStringArray:
	var keys_by_label: Dictionary[String, StringName] = {}
	if registry == null:
		return PackedStringArray(["GameDataRegistry is missing for localization validation."])

	for planet: PlanetDefinition in registry.planets:
		if planet == null:
			continue
		keys_by_label["PlanetDefinition '%s' display_name_key" % planet.id] = planet.display_name_key
		keys_by_label["PlanetDefinition '%s' description_key" % planet.id] = planet.description_key
	for order: OrderDefinition in registry.orders:
		if order == null:
			continue
		keys_by_label["OrderDefinition '%s' display_name_key" % order.id] = order.display_name_key
		for index: int in order.customer_history_keys.size():
			keys_by_label["OrderDefinition '%s' customer_history_keys[%d]" % [order.id, index]] = (
				order.customer_history_keys[index]
			)
	for cargo: CargoDefinition in registry.cargo_items:
		if cargo == null:
			continue
		keys_by_label["CargoDefinition '%s' display_name_key" % cargo.id] = cargo.display_name_key
		keys_by_label["CargoDefinition '%s' company_description_key" % cargo.id] = (
			cargo.company_description_key
		)
		keys_by_label["CargoDefinition '%s' story_description_key" % cargo.id] = (
			cargo.story_description_key
		)
	for module: ShipModuleDefinition in registry.modules:
		if module == null:
			continue
		keys_by_label["ShipModuleDefinition '%s' display_name_key" % module.id] = module.display_name_key
		keys_by_label["ShipModuleDefinition '%s' description_key" % module.id] = module.description_key
	for character: CharacterDefinition in registry.characters:
		if character == null:
			continue
		keys_by_label["CharacterDefinition '%s' display_name_key" % character.id] = (
			character.display_name_key
		)
		keys_by_label["CharacterDefinition '%s' role_key" % character.id] = character.role_key

	return validate_keys(keys_by_label, catalog, required_locales)


static func _validate_key(
	label: String,
	message_key: StringName,
	catalog: LocalizationCatalog,
	required_locales: PackedStringArray,
	errors: PackedStringArray
) -> void:
	if message_key.is_empty():
		errors.append("%s is empty." % label)
		return
	if not catalog.has_key(message_key):
		errors.append("%s references missing localization key '%s'." % [label, message_key])
		return
	for locale: String in required_locales:
		if not catalog.has_translation(message_key, StringName(locale)):
			errors.append("%s key '%s' is missing locale '%s'." % [label, message_key, locale])
