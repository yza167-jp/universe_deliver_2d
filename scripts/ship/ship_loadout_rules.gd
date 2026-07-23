class_name ShipLoadoutRules
extends RefCounted

const SHIP_ID: StringName = &"ship_player_courier"
const SHIP_NAME_KEY: StringName = &"SHIP_PLAYER_COURIER_NAME"

const SLOT_POWER: StringName = &"power"
const SLOT_DEFENSE: StringName = &"defense"
const SLOT_UTILITY: StringName = &"utility"
const SLOT_SHIELD_BACKUP_POWER: StringName = &"shield_backup_power"

const DEFAULT_POWER_MODULE_ID: StringName = &"module_standard_drive"
const DEFAULT_DEFENSE_MODULE_ID: StringName = &"module_atmospheric_shield"
const LASER_MODULE_ID: StringName = &"module_asteroid_laser"
const SHIELD_BACKUP_POWER_MODULE_ID: StringName = &"module_shield_backup_power"
const ASTEROID_BREAK_CAPABILITY: StringName = &"capability_break_asteroids"
const SHIELD_REGENERATION_CAPABILITY: StringName = &"capability_regenerate_shield"

const BASE_HULL: int = 100
const BASE_SHIELD: int = 100
const BASE_FUEL: int = 100
const BASE_BOOST: int = 100
const BASE_CARGO_CAPACITY: int = 1

const SLOT_ORDER: Array[StringName] = [
	SLOT_POWER,
	SLOT_DEFENSE,
	SLOT_UTILITY,
	SLOT_SHIELD_BACKUP_POWER,
]


static func create_default_configuration() -> Dictionary[StringName, StringName]:
	var configuration: Dictionary[StringName, StringName] = {}
	configuration[SLOT_POWER] = DEFAULT_POWER_MODULE_ID
	configuration[SLOT_DEFENSE] = DEFAULT_DEFENSE_MODULE_ID
	configuration[SLOT_UTILITY] = &""
	configuration[SLOT_SHIELD_BACKUP_POWER] = &""
	return configuration


static func get_slot_id(slot_type: ShipModuleDefinition.SlotType) -> StringName:
	match slot_type:
		ShipModuleDefinition.SlotType.POWER:
			return SLOT_POWER
		ShipModuleDefinition.SlotType.DEFENSE:
			return SLOT_DEFENSE
		ShipModuleDefinition.SlotType.UTILITY:
			return SLOT_UTILITY
	return &""


static func is_valid_slot_id(slot_id: StringName) -> bool:
	return SLOT_ORDER.has(slot_id)


static func get_configuration_slot_id(module: ShipModuleDefinition) -> StringName:
	if module == null:
		return &""
	if not module.configuration_slot_id.is_empty():
		return module.configuration_slot_id
	return get_slot_id(module.slot_type)


static func is_module_equipped(
	configuration: Dictionary[StringName, StringName],
	module_id: StringName
) -> bool:
	if module_id.is_empty():
		return false
	for slot_id: StringName in SLOT_ORDER:
		if configuration.get(slot_id, &"") == module_id:
			return true
	return false


static func get_order_modules(order: OrderDefinition) -> Array[ShipModuleDefinition]:
	var modules: Array[ShipModuleDefinition] = []
	if order == null:
		return modules
	for module: ShipModuleDefinition in order.required_modules:
		if module != null and not modules.has(module):
			modules.append(module)
	for module: ShipModuleDefinition in order.recommended_modules:
		if module != null and not modules.has(module):
			modules.append(module)
	return modules


static func get_module_for_slot(
	order: OrderDefinition,
	slot_type: ShipModuleDefinition.SlotType
) -> ShipModuleDefinition:
	var default_slot_id: StringName = get_slot_id(slot_type)
	for module: ShipModuleDefinition in get_order_modules(order):
		if (
			module.slot_type == slot_type
			and get_configuration_slot_id(module) == default_slot_id
		):
			return module
	return null


static func get_module_by_id(
	order: OrderDefinition,
	module_id: StringName
) -> ShipModuleDefinition:
	if module_id.is_empty():
		return null
	for module: ShipModuleDefinition in get_order_modules(order):
		if module.id == module_id:
			return module
	return null


static func get_missing_required_modules(
	order: OrderDefinition,
	configuration: Dictionary[StringName, StringName]
) -> Array[ShipModuleDefinition]:
	var missing_modules: Array[ShipModuleDefinition] = []
	if order == null:
		return missing_modules
	for module: ShipModuleDefinition in order.required_modules:
		if module != null and not is_module_equipped(configuration, module.id):
			missing_modules.append(module)
	return missing_modules


static func has_capability(
	configuration: Dictionary[StringName, StringName],
	module_catalog: Array[ShipModuleDefinition],
	capability_tag: StringName
) -> bool:
	if capability_tag.is_empty():
		return false
	for module: ShipModuleDefinition in module_catalog:
		if (
			module != null
			and is_module_equipped(configuration, module.id)
			and module.capability_tags.has(capability_tag)
		):
			return true
	return false
