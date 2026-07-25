class_name FlightElectromagneticProtectionModel
extends RefCounted

## Pure lookup/calculation layer for electromagnetic and high-voltage hazards.
## Ordinary shield/hull resources remain owned by FlightResources.

const HIGH_VOLTAGE_DAMAGE_MULTIPLIER_STAT: StringName = (
	&"high_voltage_damage_multiplier"
)
const ELECTROMAGNETIC_INTERFERENCE_MULTIPLIER_STAT: StringName = (
	&"electromagnetic_interference_multiplier"
)
const DEFAULT_MULTIPLIER: float = 1.0


static func has_high_voltage_shielding(
	configuration: Dictionary[StringName, StringName],
	module_catalog: Array[ShipModuleDefinition]
) -> bool:
	return (
		_get_equipped_shielding_module(configuration, module_catalog)
		!= null
	)


static func get_high_voltage_damage_multiplier(
	configuration: Dictionary[StringName, StringName],
	module_catalog: Array[ShipModuleDefinition]
) -> float:
	return _get_stat_multiplier(
		_get_equipped_shielding_module(configuration, module_catalog),
		HIGH_VOLTAGE_DAMAGE_MULTIPLIER_STAT
	)


static func get_electromagnetic_interference_multiplier(
	configuration: Dictionary[StringName, StringName],
	module_catalog: Array[ShipModuleDefinition]
) -> float:
	return _get_stat_multiplier(
		_get_equipped_shielding_module(configuration, module_catalog),
		ELECTROMAGNETIC_INTERFERENCE_MULTIPLIER_STAT
	)


static func scale_high_voltage_damage(
	raw_damage: float,
	damage_multiplier: float
) -> float:
	return maxf(raw_damage, 0.0) * clampf(
		damage_multiplier,
		0.0,
		DEFAULT_MULTIPLIER
	)


static func _get_equipped_shielding_module(
	configuration: Dictionary[StringName, StringName],
	module_catalog: Array[ShipModuleDefinition]
) -> ShipModuleDefinition:
	return ShipLoadoutRules.get_equipped_module_with_capability(
		configuration,
		module_catalog,
		ShipLoadoutRules.HIGH_VOLTAGE_SHIELDING_CAPABILITY
	)


static func _get_stat_multiplier(
	module: ShipModuleDefinition,
	stat_id: StringName
) -> float:
	if module == null:
		return DEFAULT_MULTIPLIER
	return clampf(
		module.stat_modifiers.get(stat_id, DEFAULT_MULTIPLIER),
		0.0,
		DEFAULT_MULTIPLIER
	)
