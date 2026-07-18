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
@export var environment_profile: FlightEnvironmentProfile

var fuel: float = DEFAULT_RESOURCE_VALUE
var boost_energy: float = DEFAULT_RESOURCE_VALUE
var assist_strength: float = DEFAULT_ASSIST_STRENGTH
var effective_assist_strength: float = DEFAULT_ASSIST_STRENGTH
var assist_fuel_cost_rate: float = 0.0
var gravity_acceleration: float = 0.0
var gravity_blend: float = 0.0
var air_density: float = 0.0
var atmospheric_drag: Vector2 = Vector2.ZERO
var natural_terminal_fall_speed: float = 0.0
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
	if environment_profile == null or tuning == null:
		velocity = FlightMotionModel.step_velocity(
			velocity,
			rotation,
			throttle_input,
			brake_input,
			tuning,
			delta
		)
		_clear_environment_telemetry()
		return

	_update_environment_state(delta)
	var controlled_velocity: Vector2 = FlightMotionModel.step_control_velocity(
		velocity,
		rotation,
		throttle_input,
		brake_input,
		tuning,
		delta
	)
	velocity = FlightEnvironmentModel.step_velocity(
		controlled_velocity,
		gravity_acceleration,
		environment_profile,
		air_density,
		tuning.space_drag,
		delta
	)
	velocity = FlightMotionModel.apply_speed_limits(velocity, rotation, tuning)


## Restores a fixed profile and control baseline for repeatable Flight Lab comparisons.
func reset_to_start(
	requested_assist_strength: float = DEFAULT_ASSIST_STRENGTH,
	requested_environment_profile: FlightEnvironmentProfile = null,
	snap_environment: bool = true
) -> void:
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
	if requested_environment_profile != null:
		environment_profile = requested_environment_profile
	if environment_profile == null:
		_clear_environment_telemetry()
	else:
		environment_zone_key = environment_profile.display_name_key
		if snap_environment:
			gravity_blend = clampf(
				environment_profile.target_gravity_blend,
				0.0,
				1.0
			)
			air_density = clampf(environment_profile.target_air_density, 0.0, 1.0)
		_refresh_environment_telemetry()
	collision_state_key = DEFAULT_COLLISION_KEY
	_update_engine_feedback()


func set_environment_profile(
	requested_profile: FlightEnvironmentProfile,
	snap_environment: bool = false
) -> void:
	environment_profile = requested_profile
	if environment_profile == null:
		gravity_blend = 0.0
		air_density = 0.0
		_clear_environment_telemetry()
		return
	environment_zone_key = environment_profile.display_name_key
	if snap_environment:
		gravity_blend = clampf(environment_profile.target_gravity_blend, 0.0, 1.0)
		air_density = clampf(environment_profile.target_air_density, 0.0, 1.0)
	_refresh_environment_telemetry()


func set_assist_strength(requested_assist_strength: float) -> void:
	assist_strength = clampf(requested_assist_strength, 0.0, 1.0)
	_refresh_environment_telemetry()


func get_speed() -> float:
	return velocity.length()


func get_vertical_speed() -> float:
	return velocity.y


func get_pitch_degrees() -> float:
	return rad_to_deg(rotation)


func get_angular_velocity() -> float:
	return angular_velocity


func get_terminal_fall_speed_safety() -> float:
	if environment_profile == null:
		return 0.0
	return maxf(environment_profile.terminal_fall_speed_safety, 0.0)


func _update_environment_state(delta: float) -> void:
	gravity_blend = FlightEnvironmentModel.step_environment_value(
		gravity_blend,
		environment_profile.target_gravity_blend,
		environment_profile.transition_rate,
		delta
	)
	air_density = FlightEnvironmentModel.step_environment_value(
		air_density,
		environment_profile.target_air_density,
		environment_profile.transition_rate,
		delta
	)
	assist_fuel_cost_rate = FlightEnvironmentModel.calculate_assist_fuel_cost_rate(
		assist_strength,
		gravity_blend if environment_profile.planet_gravity > 0.0 else 0.0,
		fuel,
		tuning
	)
	fuel = maxf(fuel - assist_fuel_cost_rate * maxf(delta, 0.0), 0.0)
	_refresh_environment_telemetry()


func _refresh_environment_telemetry() -> void:
	if environment_profile == null or tuning == null:
		_clear_environment_telemetry()
		return
	assist_fuel_cost_rate = FlightEnvironmentModel.calculate_assist_fuel_cost_rate(
		assist_strength,
		gravity_blend if environment_profile.planet_gravity > 0.0 else 0.0,
		fuel,
		tuning
	)
	effective_assist_strength = (
		FlightEnvironmentModel.calculate_effective_assist_strength(
			assist_strength,
			fuel,
			tuning
		)
	)
	gravity_acceleration = FlightEnvironmentModel.calculate_effective_gravity(
		environment_profile,
		gravity_blend,
		effective_assist_strength
	)
	atmospheric_drag = Vector2(
		maxf(environment_profile.horizontal_drag, 0.0) * air_density,
		maxf(environment_profile.vertical_drag, 0.0) * air_density
	)
	natural_terminal_fall_speed = (
		FlightEnvironmentModel.calculate_natural_terminal_fall_speed(
			gravity_acceleration,
			environment_profile,
			air_density,
			tuning.space_drag
		)
	)


func _clear_environment_telemetry() -> void:
	effective_assist_strength = assist_strength
	assist_fuel_cost_rate = 0.0
	gravity_acceleration = 0.0
	atmospheric_drag = Vector2.ZERO
	natural_terminal_fall_speed = 0.0
	if environment_profile == null:
		gravity_blend = 0.0
		air_density = 0.0
		environment_zone_key = DEFAULT_ZONE_KEY


func _update_engine_feedback() -> void:
	if _engine_glow == null:
		return
	_engine_glow.scale.x = lerpf(
		ENGINE_IDLE_SCALE,
		ENGINE_FULL_SCALE,
		throttle_input
	)
	_engine_glow.modulate.a = lerpf(ENGINE_IDLE_ALPHA, 1.0, throttle_input)
