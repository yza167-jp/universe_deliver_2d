class_name FlightCollisionResult
extends RefCounted

enum Severity {
	NONE,
	GRAZE,
	HARD,
	FATAL,
}

var severity: Severity = Severity.NONE
var impact_speed: float = 0.0
var impact_normal: Vector2 = Vector2.ZERO
var total_damage: float = 0.0
var cargo_damage: float = 0.0
var should_fail: bool = false
var state_key: StringName = &"UI_FLIGHT_LAB_COLLISION_CLEAR"


func is_impact() -> bool:
	return severity != Severity.NONE
