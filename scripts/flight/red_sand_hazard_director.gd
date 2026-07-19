class_name RedSandHazardDirector
extends Node2D

signal lightning_warning_started(
	strike_id: StringName,
	warning_seconds: float,
	slow_motion_active: bool
)
signal lightning_resolved(
	strike_id: StringName,
	hit_ship: bool,
	damage: float
)

const LIGHTNING_FAILURE_KEY: StringName = &"UI_RED_SAND_HAZARD_LIGHTNING_FAILURE"

@export var asteroid_container_path: NodePath
@export var lightning_container_path: NodePath
@export var storm_segment_id: StringName = &"red_sand_storm_layer"
@export var base_wind_acceleration: Vector2 = Vector2(-18.0, 8.0)
@export var gust_acceleration: Vector2 = Vector2(12.0, 92.0)
@export_range(0.01, 5.0, 0.01, "or_greater") var gust_frequency_hz: float = 0.38
@export_range(0.0, 1.0, 0.01) var maximum_assist_wind_reduction: float = 0.7
@export_range(0.1, 1.0, 0.05) var slow_motion_time_scale: float = 0.55

@onready var _asteroid_container: Node = get_node_or_null(asteroid_container_path)
@onready var _lightning_container: Node = get_node_or_null(lightning_container_path)

var _flight_ship: FlightLabShip
var _flight_camera: Camera2D
var _settings_service: SettingsServiceModel
var _storm_active: bool = false
var _storm_elapsed_seconds: float = 0.0
var _current_wind_acceleration: Vector2 = Vector2.ZERO
var _slow_motion_active: bool = false
var _previous_time_scale: float = 1.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		cancel_slow_motion()


func bind(
	flight_ship: FlightLabShip,
	route_origin_x: float,
	settings_service: SettingsServiceModel = null,
	flight_camera: Camera2D = null
) -> bool:
	_flight_ship = flight_ship
	_settings_service = settings_service
	_flight_camera = flight_camera
	var validation_errors: PackedStringArray = validate()
	if not validation_errors.is_empty():
		for validation_error: String in validation_errors:
			push_error("Red Sand hazards: %s" % validation_error)
		return false
	for strike: FlightLightningStrike in get_lightning_strikes():
		strike.configure(route_origin_x)
		if not strike.warning_started.is_connected(_on_lightning_warning_started):
			strike.warning_started.connect(_on_lightning_warning_started)
		if not strike.strike_started.is_connected(_on_lightning_strike_started):
			strike.strike_started.connect(_on_lightning_strike_started)
	reset_for_checkpoint(0.0)
	return true


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if _asteroid_container == null:
		errors.append("Asteroid container is missing.")
	if _lightning_container == null:
		errors.append("Lightning container is missing.")
	if storm_segment_id.is_empty():
		errors.append("Storm segment ID is empty.")
	if gust_frequency_hz <= 0.0:
		errors.append("Storm gust frequency must be positive.")
	if slow_motion_time_scale <= 0.0 or slow_motion_time_scale > 1.0:
		errors.append("Slow-motion time scale must stay in (0, 1].")

	var asteroid_ids: Dictionary[StringName, bool] = {}
	for asteroid: DestructibleAsteroid in get_asteroids():
		if asteroid.target_id.is_empty():
			errors.append("An asteroid has an empty target ID.")
		elif asteroid_ids.has(asteroid.target_id):
			errors.append("Asteroid ID '%s' is repeated." % asteroid.target_id)
		else:
			asteroid_ids[asteroid.target_id] = true
	if not errors.has("Asteroid container is missing.") and get_asteroids().is_empty():
		errors.append("Fixed asteroid route has no destructible obstacles.")

	var strike_ids: Dictionary[StringName, bool] = {}
	for strike: FlightLightningStrike in get_lightning_strikes():
		if strike.strike_id.is_empty():
			errors.append("A lightning strike has an empty ID.")
		elif strike_ids.has(strike.strike_id):
			errors.append("Lightning ID '%s' is repeated." % strike.strike_id)
		else:
			strike_ids[strike.strike_id] = true
		if strike.trigger_route_distance >= strike.strike_route_distance:
			errors.append(
				"Lightning '%s' must warn before its strike distance." % strike.strike_id
			)
		if strike.tracking_seconds < 0.6 or strike.tracking_seconds > 1.0:
			errors.append(
				"Lightning '%s' tracking must stay within 0.6-1.0 seconds."
				% strike.strike_id
			)
		if strike.lock_seconds < 0.4 or strike.lock_seconds > 0.8:
			errors.append(
				"Lightning '%s' lock must stay within 0.4-0.8 seconds."
				% strike.strike_id
			)
		if strike.strike_seconds < 0.1 or strike.strike_seconds > 0.25:
			errors.append(
				"Lightning '%s' strike must stay within 0.1-0.25 seconds."
				% strike.strike_id
			)
	if not errors.has("Lightning container is missing.") and get_lightning_strikes().is_empty():
		errors.append("Storm route has no fixed lightning strikes.")
	return errors


func set_active_segment(segment_id: StringName) -> void:
	var was_storm_active: bool = _storm_active
	_storm_active = segment_id == storm_segment_id
	if _storm_active and not was_storm_active:
		_storm_elapsed_seconds = 0.0
	if not _storm_active:
		_current_wind_acceleration = Vector2.ZERO
		cancel_slow_motion()


func step_physics(delta: float) -> Vector2:
	if (
		not _storm_active
		or _flight_ship == null
		or _flight_ship.is_failed
		or delta <= 0.0
	):
		_current_wind_acceleration = Vector2.ZERO
		return _current_wind_acceleration
	_storm_elapsed_seconds += delta
	_current_wind_acceleration = FlightHazardModel.calculate_storm_wind(
		base_wind_acceleration,
		gust_acceleration,
		gust_frequency_hz,
		_storm_elapsed_seconds,
		_flight_ship.assist_strength,
		maximum_assist_wind_reduction
	)
	var maximum_speed: float = (
		_flight_ship.tuning.max_total_speed
		if _flight_ship.tuning != null
		else 0.0
	)
	_flight_ship.velocity = FlightHazardModel.step_velocity(
		_flight_ship.velocity,
		_current_wind_acceleration,
		delta,
		maximum_speed
	)
	return _current_wind_acceleration


func advance_hazards(delta: float, maximum_route_distance: float) -> void:
	if not _storm_active or _flight_ship == null or _flight_ship.is_failed:
		return
	for strike: FlightLightningStrike in get_lightning_strikes():
		strike.advance(
			delta,
			maximum_route_distance,
			_flight_ship.global_position,
			_flight_ship.velocity,
			_flight_camera.global_position if _flight_camera != null else Vector2.ZERO,
			Vector2(640.0, 360.0)
		)


func reset_for_checkpoint(route_distance: float) -> void:
	cancel_slow_motion()
	_storm_elapsed_seconds = 0.0
	_current_wind_acceleration = Vector2.ZERO
	for asteroid: DestructibleAsteroid in get_asteroids():
		asteroid.reset_asteroid()
	for strike: FlightLightningStrike in get_lightning_strikes():
		strike.reset_for_route(route_distance)


func cancel_slow_motion() -> void:
	if not _slow_motion_active:
		return
	Engine.time_scale = _previous_time_scale
	_slow_motion_active = false


func get_asteroids() -> Array[DestructibleAsteroid]:
	var asteroids: Array[DestructibleAsteroid] = []
	if _asteroid_container == null:
		return asteroids
	for child: Node in _asteroid_container.get_children():
		if child is DestructibleAsteroid:
			asteroids.append(child as DestructibleAsteroid)
	return asteroids


func get_lightning_strikes() -> Array[FlightLightningStrike]:
	var strikes: Array[FlightLightningStrike] = []
	if _lightning_container == null:
		return strikes
	for child: Node in _lightning_container.get_children():
		if child is FlightLightningStrike:
			strikes.append(child as FlightLightningStrike)
	return strikes


func get_current_wind_acceleration() -> Vector2:
	return _current_wind_acceleration


func get_assist_wind_mitigation() -> float:
	if _flight_ship == null:
		return 0.0
	return FlightHazardModel.calculate_assist_mitigation(
		_flight_ship.assist_strength,
		maximum_assist_wind_reduction
	)


func is_storm_active() -> bool:
	return _storm_active


func is_slow_motion_active() -> bool:
	return _slow_motion_active


func _on_lightning_warning_started(
	strike_id: StringName,
	warning_seconds: float
) -> void:
	if _resolve_slow_motion_enabled():
		_activate_slow_motion()
	lightning_warning_started.emit(
		strike_id,
		warning_seconds,
		_slow_motion_active
	)


func _on_lightning_strike_started(
	strike_id: StringName,
	hit_ship: bool,
	damage: float,
	cargo_damage: float
) -> void:
	cancel_slow_motion()
	if hit_ship and _flight_ship != null:
		_flight_ship.apply_environment_damage(
			damage,
			cargo_damage,
			LIGHTNING_FAILURE_KEY
		)
	lightning_resolved.emit(strike_id, hit_ship, damage)


func _activate_slow_motion() -> void:
	if _slow_motion_active:
		return
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = _previous_time_scale * clampf(
		slow_motion_time_scale,
		0.1,
		1.0
	)
	_slow_motion_active = true


func _resolve_slow_motion_enabled() -> bool:
	var settings_service: SettingsServiceModel = _settings_service
	if settings_service == null:
		settings_service = get_node_or_null(
			"/root/SettingsService"
		) as SettingsServiceModel
	return (
		settings_service != null
		and settings_service.settings.slow_motion_assist
	)
