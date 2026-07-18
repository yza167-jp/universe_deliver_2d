class_name FlightLabShip
extends CharacterBody2D

const DEFAULT_RESOURCE_VALUE: float = 100.0
const DEFAULT_ASSIST_STRENGTH: float = 0.75
const DEFAULT_ZONE_KEY: StringName = &"UI_FLIGHT_LAB_ZONE_DEEP_SPACE"
const DEFAULT_COLLISION_KEY: StringName = &"UI_FLIGHT_LAB_COLLISION_CLEAR"

@export var stable_start_position: Vector2 = Vector2(320.0, 190.0)

var fuel: float = DEFAULT_RESOURCE_VALUE
var boost_energy: float = DEFAULT_RESOURCE_VALUE
var assist_strength: float = DEFAULT_ASSIST_STRENGTH
var gravity_acceleration: float = 0.0
var environment_zone_key: StringName = DEFAULT_ZONE_KEY
var collision_state_key: StringName = DEFAULT_COLLISION_KEY


## Restores the deterministic baseline that later flight tasks will build on.
func reset_to_start(requested_assist_strength: float = DEFAULT_ASSIST_STRENGTH) -> void:
	position = stable_start_position
	velocity = Vector2.ZERO
	rotation = 0.0
	fuel = DEFAULT_RESOURCE_VALUE
	boost_energy = DEFAULT_RESOURCE_VALUE
	assist_strength = clampf(requested_assist_strength, 0.0, 1.0)
	gravity_acceleration = 0.0
	environment_zone_key = DEFAULT_ZONE_KEY
	collision_state_key = DEFAULT_COLLISION_KEY


func get_speed() -> float:
	return velocity.length()


func get_vertical_speed() -> float:
	return velocity.y


func get_pitch_degrees() -> float:
	return rad_to_deg(rotation)
