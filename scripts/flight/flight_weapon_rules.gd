class_name FlightWeaponRules
extends RefCounted

const WORLD_COLLISION_LAYER: int = 1 << 0
const DESTRUCTIBLE_ASTEROID_LAYER: int = 1 << 1
const SHIP_COLLISION_MASK: int = (
	WORLD_COLLISION_LAYER | DESTRUCTIBLE_ASTEROID_LAYER
)
const LASER_TARGET_MASK: int = DESTRUCTIBLE_ASTEROID_LAYER


static func has_asteroid_laser(
	configuration: Dictionary[StringName, StringName],
	module_catalog: Array[ShipModuleDefinition]
) -> bool:
	return ShipLoadoutRules.has_capability(
		configuration,
		module_catalog,
		ShipLoadoutRules.ASTEROID_BREAK_CAPABILITY
	)


static func is_laser_target_layer(collision_layer: int) -> bool:
	return (collision_layer & LASER_TARGET_MASK) != 0


static func is_world_only_layer(collision_layer: int) -> bool:
	return (
		(collision_layer & WORLD_COLLISION_LAYER) != 0
		and not is_laser_target_layer(collision_layer)
	)
