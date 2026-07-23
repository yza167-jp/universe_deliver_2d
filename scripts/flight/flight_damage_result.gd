class_name FlightDamageResult
extends RefCounted

var source: StringName = &""
var requested_damage: float = 0.0
var requested_cargo_damage: float = 0.0
var penetration_ratio: float = 0.0
var shield_damage: float = 0.0
var hull_damage: float = 0.0
var cargo_damage: float = 0.0
var forced_failure: bool = false


func has_resource_change() -> bool:
	return (
		shield_damage > 0.0
		or hull_damage > 0.0
		or cargo_damage > 0.0
	)
