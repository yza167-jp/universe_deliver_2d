class_name FlightLabShip
extends CharacterBody2D

const THROTTLE_ACTION: StringName = &"flight_throttle"
const BRAKE_ACTION: StringName = &"flight_brake"
const PITCH_UP_ACTION: StringName = &"flight_pitch_up"
const PITCH_DOWN_ACTION: StringName = &"flight_pitch_down"
const DEFAULT_RESOURCE_VALUE: float = 100.0
const DEFAULT_ASSIST_STRENGTH: float = 0.75
const DEFAULT_ZONE_KEY: StringName = &"UI_FLIGHT_LAB_ZONE_DEEP_SPACE"
const DEFAULT_COLLISION_KEY: StringName = &"UI_FLIGHT_LAB_COLLISION_CLEAR"
const ENGINE_IDLE_SCALE: float = 0.55
const ENGINE_FULL_SCALE: float = 1.35
const ENGINE_IDLE_ALPHA: float = 0.35

@export var stable_start_position: Vector2 = Vector2(320.0, 190.0)
@export var tuning: FlightTuning = FlightTuning.new()

var fuel: float = DEFAULT_RESOURCE_VALUE
var boost_energy: float = DEFAULT_RESOURCE_VALUE
var assist_strength: float = DEFAULT_ASSIST_STRENGTH
var gravity_acceleration: float = 0.0
var environment_zone_key: StringName = DEFAULT_ZONE_KEY
var collision_state_key: StringName = DEFAULT_COLLISION_KEY
var angular_velocity: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0
var pitch_input: float = 0.0

@onready var _engine_glow: Polygon2D = $EngineGlow


func _physics_process(delta: float) -> void:
	var requested_pitch: float = Input.get_axis(PITCH_UP_ACTION, PITCH_DOWN_ACTION)
	integrate_motion(
		Input.get_action_strength(THROTTLE_ACTION),
		Input.get_action_strength(BRAKE_ACTION),
		requested_pitch,
		delta
	)
	move_and_slide()
	_update_engine_feedback()


## Advances deterministic motion state without reading input or moving the body.
func integrate_motion(
	requested_throttle: float,
	requested_brake: float,
	requested_pitch: float,
	delta: float
) -> void:
	throttle_input = clampf(requested_throttle, 0.0, 1.0)
	brake_input = clampf(requested_brake, 0.0, 1.0)
	pitch_input = clampf(requested_pitch, -1.0, 1.0)
	angular_velocity = FlightMotionModel.step_angular_velocity(
		angular_velocity,
		pitch_input,
		tuning,
		delta
	)
	var raw_rotation: float = rotation + angular_velocity * maxf(delta, 0.0)
	rotation = FlightMotionModel.integrate_rotation(
		rotation,
		angular_velocity,
		tuning,
		delta
	)
	if not is_equal_approx(raw_rotation, rotation):
		angular_velocity = 0.0
	velocity = FlightMotionModel.step_velocity(
		velocity,
		rotation,
		throttle_input,
		brake_input,
		tuning,
		delta
	)


## Restores the deterministic baseline that later flight tasks will build on.
func reset_to_start(requested_assist_strength: float = DEFAULT_ASSIST_STRENGTH) -> void:
	position = stable_start_position
	velocity = Vector2.ZERO
	rotation = 0.0
	angular_velocity = 0.0
	throttle_input = 0.0
	brake_input = 0.0
	pitch_input = 0.0
	fuel = DEFAULT_RESOURCE_VALUE
	boost_energy = DEFAULT_RESOURCE_VALUE
	assist_strength = clampf(requested_assist_strength, 0.0, 1.0)
	gravity_acceleration = 0.0
	environment_zone_key = DEFAULT_ZONE_KEY
	collision_state_key = DEFAULT_COLLISION_KEY
	_update_engine_feedback()


func get_speed() -> float:
	return velocity.length()


func get_vertical_speed() -> float:
	return velocity.y


func get_pitch_degrees() -> float:
	return rad_to_deg(rotation)


func get_angular_velocity() -> float:
	return angular_velocity


func _update_engine_feedback() -> void:
	if _engine_glow == null:
		return
	_engine_glow.scale.x = lerpf(
		ENGINE_IDLE_SCALE,
		ENGINE_FULL_SCALE,
		throttle_input
	)
	_engine_glow.modulate.a = lerpf(ENGINE_IDLE_ALPHA, 1.0, throttle_input)
