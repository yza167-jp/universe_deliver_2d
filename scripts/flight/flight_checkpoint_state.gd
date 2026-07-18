class_name FlightCheckpointState
extends RefCounted

var checkpoint_id: StringName = &""
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var rotation: float = 0.0
var angular_velocity: float = 0.0
var assist_strength: float = 0.75
var environment_profile: FlightEnvironmentProfile
var gravity_blend: float = 0.0
var air_density: float = 0.0
var resources: FlightResources = FlightResources.new()
