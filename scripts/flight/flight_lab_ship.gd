class_name FlightLabShip
extends CharacterBody2D

signal impact_resolved(severity: int, impact_speed: float)
signal flight_failed(reason_key: StringName)
signal company_warning_requested(warning_key: StringName, cargo_integrity: float)
signal laser_fired(hit_target: bool)
signal laser_fire_rejected(reason_key: StringName)
signal laser_target_hit(
	target_id: StringName,
	remaining_durability: int,
	target_destroyed: bool
)

const THROTTLE_ACTION: StringName = &"flight_throttle"
const BRAKE_ACTION: StringName = &"flight_brake"
const PITCH_UP_ACTION: StringName = &"flight_pitch_up"
const PITCH_DOWN_ACTION: StringName = &"flight_pitch_down"
const BOOST_ACTION: StringName = &"flight_boost"
const FIRE_ACTION: StringName = &"flight_fire"
const DEFAULT_RESOURCE_VALUE: float = FlightResources.MAX_RESOURCE_VALUE
const DEFAULT_ASSIST_STRENGTH: float = 0.75
const DEFAULT_ZONE_KEY: StringName = &"UI_FLIGHT_LAB_ZONE_DEEP_SPACE"
const DEFAULT_COLLISION_KEY: StringName = &"UI_FLIGHT_LAB_COLLISION_CLEAR"
const FLIGHT_FAILURE_KEY: StringName = &"UI_FLIGHT_LAB_FAILURE_COLLISION"
const ENGINE_IDLE_SCALE: float = 0.55
const ENGINE_FULL_SCALE: float = 1.35
const ENGINE_IDLE_ALPHA: float = 0.35

@export var stable_start_position: Vector2 = Vector2(320.0, 190.0)
@export var tuning: FlightTuning = FlightTuning.new()
@export var environment_profile: FlightEnvironmentProfile
@export var cargo_definition: CargoDefinition

var resources: FlightResources = FlightResources.new()
var hull: float:
	get:
		return resources.hull
	set(value):
		resources.hull = clampf(value, 0.0, DEFAULT_RESOURCE_VALUE)
var shield: float:
	get:
		return resources.shield
	set(value):
		resources.shield = clampf(value, 0.0, DEFAULT_RESOURCE_VALUE)
var fuel: float:
	get:
		return resources.fuel
	set(value):
		resources.fuel = clampf(value, 0.0, DEFAULT_RESOURCE_VALUE)
var boost_energy: float:
	get:
		return resources.boost_energy
	set(value):
		resources.boost_energy = clampf(value, 0.0, DEFAULT_RESOURCE_VALUE)
var cargo_integrity: float:
	get:
		return resources.cargo_integrity
	set(value):
		resources.cargo_integrity = clampf(value, 0.0, DEFAULT_RESOURCE_VALUE)
var assist_strength: float = DEFAULT_ASSIST_STRENGTH
var effective_assist_strength: float = DEFAULT_ASSIST_STRENGTH
var assist_fuel_cost_rate: float = 0.0
var propulsion_fuel_cost_rate: float = 0.0
var gravity_acceleration: float = 0.0
var gravity_blend: float = 0.0
var air_density: float = 0.0
var atmospheric_drag: Vector2 = Vector2.ZERO
var natural_terminal_fall_speed: float = 0.0
var environment_zone_key: StringName = DEFAULT_ZONE_KEY
var collision_state_key: StringName = DEFAULT_COLLISION_KEY
var last_impact_speed: float = 0.0
var checkpoint_id: StringName = &""
var is_failed: bool = false
var angular_velocity: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0
var pitch_input: float = 0.0
var boost_input: float = 0.0
var effective_throttle_input: float = 0.0
var effective_boost_input: float = 0.0

@onready var _engine_glow: Polygon2D = $EngineGlow
@onready var _boost_glow: Polygon2D = $BoostGlow
@onready var _impact_sparks: CPUParticles2D = $ImpactSparks
@onready var _laser_weapon: FlightLaserWeapon = %LaserWeapon

var _checkpoint_state: FlightCheckpointState
var _collision_feedback_cooldown_remaining: float = 0.0
var _triggered_cargo_warning_keys: Dictionary[StringName, bool] = {}


func _ready() -> void:
	if _laser_weapon == null:
		return
	_laser_weapon.tuning = tuning
	if not _laser_weapon.fired.is_connected(_on_laser_fired):
		_laser_weapon.fired.connect(_on_laser_fired)
	if not _laser_weapon.fire_rejected.is_connected(_on_laser_fire_rejected):
		_laser_weapon.fire_rejected.connect(_on_laser_fire_rejected)
	if not _laser_weapon.target_hit.is_connected(_on_laser_target_hit):
		_laser_weapon.target_hit.connect(_on_laser_target_hit)


func _physics_process(delta: float) -> void:
	_collision_feedback_cooldown_remaining = maxf(
		_collision_feedback_cooldown_remaining - maxf(delta, 0.0),
		0.0
	)
	if is_failed:
		_clear_control_inputs()
		_update_engine_feedback()
		return
	if Input.is_action_just_pressed(FIRE_ACTION):
		request_laser_fire()
	var requested_pitch: float = Input.get_axis(PITCH_UP_ACTION, PITCH_DOWN_ACTION)
	integrate_motion(
		Input.get_action_strength(THROTTLE_ACTION),
		Input.get_action_strength(BRAKE_ACTION),
		requested_pitch,
		delta,
		Input.get_action_strength(BOOST_ACTION)
	)
	var incoming_velocity: Vector2 = velocity
	move_and_slide()
	_resolve_slide_collisions(incoming_velocity)
	_update_engine_feedback()


## Advances deterministic motion state without reading input or moving the body.
func integrate_motion(
	requested_throttle: float,
	requested_brake: float,
	requested_pitch: float,
	delta: float,
	requested_boost: float = 0.0
) -> void:
	throttle_input = clampf(requested_throttle, 0.0, 1.0)
	brake_input = clampf(requested_brake, 0.0, 1.0)
	pitch_input = clampf(requested_pitch, -1.0, 1.0)
	boost_input = clampf(requested_boost, 0.0, 1.0)
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
		_clear_environment_telemetry()
	else:
		_update_environment_state(delta)
	var effective_inputs: Vector2 = resources.step_propulsion(
		throttle_input,
		boost_input,
		assist_fuel_cost_rate,
		_get_cargo_boost_policy(),
		_is_boost_recovery_blocked(),
		tuning,
		delta
	)
	effective_throttle_input = effective_inputs.x
	effective_boost_input = effective_inputs.y
	propulsion_fuel_cost_rate = resources.propulsion_fuel_cost_rate

	if environment_profile == null or tuning == null:
		velocity = FlightMotionModel.step_velocity(
			velocity,
			rotation,
			effective_throttle_input,
			brake_input,
			tuning,
			delta,
			effective_boost_input
		)
		return

	var controlled_velocity: Vector2 = FlightMotionModel.step_control_velocity(
		velocity,
		rotation,
		effective_throttle_input,
		brake_input,
		tuning,
		delta,
		effective_boost_input
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
	_refresh_environment_telemetry()


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
	boost_input = 0.0
	effective_throttle_input = 0.0
	effective_boost_input = 0.0
	resources.reset()
	propulsion_fuel_cost_rate = 0.0
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
	_clear_collision_state()
	is_failed = false
	_triggered_cargo_warning_keys.clear()
	if _laser_weapon != null:
		_laser_weapon.reset_weapon()
	_update_engine_feedback()


## Captures only stable runtime values; scene instances are never stored.
func capture_checkpoint(requested_checkpoint_id: StringName) -> bool:
	if requested_checkpoint_id.is_empty():
		return false
	var snapshot: FlightCheckpointState = FlightCheckpointState.new()
	snapshot.checkpoint_id = requested_checkpoint_id
	snapshot.position = position
	snapshot.velocity = velocity
	snapshot.rotation = rotation
	snapshot.angular_velocity = angular_velocity
	snapshot.assist_strength = assist_strength
	snapshot.environment_profile = environment_profile
	snapshot.gravity_blend = gravity_blend
	snapshot.air_density = air_density
	snapshot.resources = resources.duplicate_state()
	_checkpoint_state = snapshot
	checkpoint_id = requested_checkpoint_id
	return true


func restore_checkpoint() -> bool:
	if _checkpoint_state == null or _checkpoint_state.checkpoint_id.is_empty():
		return false
	checkpoint_id = _checkpoint_state.checkpoint_id
	position = _checkpoint_state.position
	velocity = _checkpoint_state.velocity
	rotation = _checkpoint_state.rotation
	angular_velocity = _checkpoint_state.angular_velocity
	assist_strength = _checkpoint_state.assist_strength
	environment_profile = _checkpoint_state.environment_profile
	gravity_blend = _checkpoint_state.gravity_blend
	air_density = _checkpoint_state.air_density
	resources.restore_from(_checkpoint_state.resources)
	_clear_control_inputs()
	_clear_collision_state()
	is_failed = false
	_triggered_cargo_warning_keys.clear()
	if _laser_weapon != null:
		_laser_weapon.reset_weapon()
	if environment_profile == null:
		_clear_environment_telemetry()
	else:
		environment_zone_key = environment_profile.display_name_key
		_refresh_environment_telemetry()
	_update_engine_feedback()
	return true


func configure_stable_checkpoint(
	requested_checkpoint_id: StringName,
	requested_assist_strength: float,
	requested_environment_profile: FlightEnvironmentProfile
) -> bool:
	if requested_checkpoint_id.is_empty():
		return false
	var snapshot: FlightCheckpointState = FlightCheckpointState.new()
	snapshot.checkpoint_id = requested_checkpoint_id
	snapshot.position = stable_start_position
	snapshot.velocity = Vector2.ZERO
	snapshot.rotation = 0.0
	snapshot.angular_velocity = 0.0
	snapshot.assist_strength = clampf(requested_assist_strength, 0.0, 1.0)
	snapshot.environment_profile = requested_environment_profile
	if requested_environment_profile != null:
		snapshot.gravity_blend = clampf(
			requested_environment_profile.target_gravity_blend,
			0.0,
			1.0
		)
		snapshot.air_density = clampf(
			requested_environment_profile.target_air_density,
			0.0,
			1.0
		)
	snapshot.resources = FlightResources.new()
	_checkpoint_state = snapshot
	checkpoint_id = requested_checkpoint_id
	return true


func resolve_impact(
	incoming_velocity: Vector2,
	collision_normal: Vector2
) -> FlightCollisionResult:
	if _collision_feedback_cooldown_remaining > 0.0 or is_failed:
		return FlightCollisionResult.new()
	var result: FlightCollisionResult = FlightCollisionResolver.resolve(
		incoming_velocity,
		collision_normal,
		_get_cargo_collision_tolerance(),
		tuning
	)
	_apply_collision_result(result)
	return result


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


func get_checkpoint_id() -> StringName:
	return checkpoint_id


func set_laser_enabled(enabled: bool) -> void:
	if _laser_weapon != null:
		_laser_weapon.set_laser_enabled(enabled)


func is_laser_enabled() -> bool:
	return _laser_weapon != null and _laser_weapon.is_laser_enabled()


func is_laser_ready() -> bool:
	return _laser_weapon != null and _laser_weapon.is_ready_to_fire()


func get_laser_cooldown_remaining() -> float:
	return 0.0 if _laser_weapon == null else _laser_weapon.get_cooldown_remaining()


func get_laser_weapon() -> FlightLaserWeapon:
	return _laser_weapon


func request_laser_fire() -> FlightLaserWeapon.FireResult:
	if _laser_weapon == null:
		return FlightLaserWeapon.FireResult.UNAVAILABLE
	_laser_weapon.tuning = tuning
	return _laser_weapon.request_fire()


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
	var engine_strength: float = maxf(
		effective_throttle_input,
		effective_boost_input
	)
	_engine_glow.scale.x = lerpf(
		ENGINE_IDLE_SCALE,
		ENGINE_FULL_SCALE,
		engine_strength
	)
	_engine_glow.modulate.a = lerpf(ENGINE_IDLE_ALPHA, 1.0, engine_strength)
	if _boost_glow != null:
		_boost_glow.visible = effective_boost_input > 0.0
		_boost_glow.scale.x = lerpf(0.8, 1.5, effective_boost_input)


func _resolve_slide_collisions(incoming_velocity: Vector2) -> void:
	if _collision_feedback_cooldown_remaining > 0.0:
		return
	var strongest_result: FlightCollisionResult = FlightCollisionResult.new()
	for collision_index: int in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision == null:
			continue
		var candidate: FlightCollisionResult = FlightCollisionResolver.resolve(
			incoming_velocity,
			collision.get_normal(),
			_get_cargo_collision_tolerance(),
			tuning
		)
		if (
			candidate.severity > strongest_result.severity
			or (
				candidate.severity == strongest_result.severity
				and candidate.impact_speed > strongest_result.impact_speed
			)
		):
			strongest_result = candidate
	_apply_collision_result(strongest_result)


func _apply_collision_result(result: FlightCollisionResult) -> void:
	if result == null or not result.is_impact():
		return
	var previous_cargo_integrity: float = cargo_integrity
	resources.apply_collision(result)
	collision_state_key = result.state_key
	last_impact_speed = result.impact_speed
	_collision_feedback_cooldown_remaining = maxf(
		tuning.collision_feedback_cooldown_seconds if tuning != null else 0.0,
		0.0
	)
	if _impact_sparks != null:
		_impact_sparks.restart()
		_impact_sparks.emitting = true
	impact_resolved.emit(result.severity, result.impact_speed)
	_emit_cargo_warning_if_needed(previous_cargo_integrity)
	if result.should_fail:
		is_failed = true
		velocity = Vector2.ZERO
		angular_velocity = 0.0
		_clear_control_inputs()
		flight_failed.emit(FLIGHT_FAILURE_KEY)
	elif result.severity == FlightCollisionResult.Severity.HARD:
		velocity *= clampf(tuning.hard_impact_velocity_retention, 0.0, 1.0)


func _emit_cargo_warning_if_needed(previous_integrity: float) -> void:
	if tuning == null or cargo_integrity >= previous_integrity:
		return
	var warning_key: StringName = &""
	if (
		previous_integrity > tuning.cargo_warning_low_threshold
		and cargo_integrity <= tuning.cargo_warning_low_threshold
	):
		warning_key = &"UI_FLIGHT_COMPANY_WARNING_CARGO_LOW"
	elif (
		previous_integrity > tuning.cargo_warning_medium_threshold
		and cargo_integrity <= tuning.cargo_warning_medium_threshold
	):
		warning_key = &"UI_FLIGHT_COMPANY_WARNING_CARGO_MEDIUM"
	elif (
		previous_integrity > tuning.cargo_warning_high_threshold
		and cargo_integrity <= tuning.cargo_warning_high_threshold
	):
		warning_key = &"UI_FLIGHT_COMPANY_WARNING_CARGO_HIGH"
	if warning_key.is_empty() or _triggered_cargo_warning_keys.get(warning_key, false):
		return
	_triggered_cargo_warning_keys[warning_key] = true
	company_warning_requested.emit(warning_key, cargo_integrity)


func _get_cargo_boost_policy() -> int:
	if cargo_definition == null:
		return CargoDefinition.BoostPolicy.ALLOWED
	return cargo_definition.boost_policy


func _get_cargo_collision_tolerance() -> float:
	if cargo_definition == null:
		return 1.0
	return clampf(cargo_definition.collision_tolerance, 0.0, 1.0)


func _is_boost_recovery_blocked() -> bool:
	return (
		assist_strength >= 1.0
		and gravity_blend > 0.0
		and environment_profile != null
		and environment_profile.planet_gravity > 0.0
	)


func _clear_control_inputs() -> void:
	throttle_input = 0.0
	brake_input = 0.0
	pitch_input = 0.0
	boost_input = 0.0
	effective_throttle_input = 0.0
	effective_boost_input = 0.0


func _clear_collision_state() -> void:
	collision_state_key = DEFAULT_COLLISION_KEY
	last_impact_speed = 0.0
	_collision_feedback_cooldown_remaining = 0.0


func _on_laser_fired(hit_target: bool) -> void:
	laser_fired.emit(hit_target)


func _on_laser_fire_rejected(reason_key: StringName) -> void:
	laser_fire_rejected.emit(reason_key)


func _on_laser_target_hit(
	target_id: StringName,
	remaining_durability: int,
	target_destroyed: bool
) -> void:
	laser_target_hit.emit(target_id, remaining_durability, target_destroyed)
