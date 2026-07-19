class_name RedSandFlight
extends Node2D

const RESTART_ACTION: StringName = &"flight_restart"
const NO_RETRY_PENDING: float = -1.0
const NO_ARRIVAL_TRANSITION_PENDING: float = -1.0
const ENTRY_START_SEGMENT_INDEX: int = 3
const ENTRY_FINALIZE_SEGMENT_INDEX: int = 7

@onready var flight_ship: FlightLabShip = %FlightShip
@onready var flight_camera: Camera2D = %FlightCamera
@onready var route_hud: RedSandRouteHUD = %RedSandRouteHUD
@onready var route_visuals: RedSandRouteVisuals = %RouteGeometry
@onready var hazard_director: RedSandHazardDirector = %Hazards
@onready var environment_feedback: RedSandEnvironmentFeedback = %EnvironmentFeedback
@onready var low_flight_course: RedSandLowFlightCourse = %LowFlightCourse
@onready var landing_zone: RedSandLandingZone = %LandingZone

@export var route_definition: FlightRouteDefinition
@export var data_registry: GameDataRegistry
@export var route_origin_x: float = 320.0
@export var initial_ship_y: float = 190.0

var settings_service_override: SettingsServiceModel
var game_state_override: GameStateModel
var scene_router_override: SceneRouterService
var _active_segment_index: int = 0
var _maximum_route_distance: float = 0.0
var _route_elapsed_seconds: float = 0.0
var _route_completed: bool = false
var _auto_retry_remaining: float = NO_RETRY_PENDING
var _arrival_transition_remaining: float = NO_ARRIVAL_TRANSITION_PENDING
var _landing_result: StringName = &""
var _entry_style_tracker: FlightStyleTracker = FlightStyleTracker.new()
var _local_order_run_state: OrderRunState = OrderRunState.new()
var _camera_shake_remaining: float = 0.0
var _camera_shake_duration: float = 0.0
var _camera_shake_elapsed: float = 0.0
var _camera_shake_amplitude: float = 0.0


func _ready() -> void:
	if not _validate_runtime_dependencies():
		set_process(false)
		set_physics_process(false)
		return
	if not route_visuals.configure(route_definition, route_origin_x):
		push_error("Red Sand route could not build its graybox visuals.")
		return
	if not hazard_director.bind(
		flight_ship,
		route_origin_x,
		_resolve_settings_service()
	):
		push_error("Red Sand route could not configure its fixed hazards.")
		return
	if not low_flight_course.bind(
		flight_ship,
		route_origin_x,
		_resolve_settings_service()
	):
		push_error("Red Sand route could not configure its low-flight course.")
		return
	if not landing_zone.bind(
		flight_ship,
		route_origin_x,
		_resolve_settings_service()
	):
		push_error("Red Sand route could not configure its landing zone.")
		return
	_connect_ship_signals()
	_connect_hazard_signals()
	_connect_low_flight_signals()
	_connect_landing_signals()
	_entry_style_tracker.bind_run_state(_resolve_order_run_state())
	flight_ship.set_laser_enabled(_resolve_laser_enabled_from_loadout())
	var assist_strength: float = _resolve_assist_strength()
	var first_segment: FlightRouteSegment = route_definition.segments[0]
	flight_ship.stable_start_position = Vector2(route_origin_x, initial_ship_y)
	if not flight_ship.configure_stable_checkpoint(
		first_segment.checkpoint_id,
		assist_strength,
		first_segment.environment_profile
	):
		push_error("Red Sand route could not configure its initial checkpoint.")
		return
	flight_ship.restore_checkpoint()
	_active_segment_index = 0
	_maximum_route_distance = 0.0
	hazard_director.set_active_segment(first_segment.id)
	environment_feedback.set_segment(first_segment)
	low_flight_course.set_active_segment(first_segment.id)
	landing_zone.set_active_segment(first_segment.id)
	_sync_order_run_checkpoint(first_segment.checkpoint_id)
	route_hud.bind(flight_ship, route_definition)
	_sync_camera_to_ship()
	_update_route_visuals()
	_refresh_hud()
	_sync_low_flight_feedback()
	_sync_landing_feedback()


func _physics_process(delta: float) -> void:
	if (
		hazard_director == null
		or environment_feedback == null
		or low_flight_course == null
		or landing_zone == null
	):
		return
	var wind_acceleration: Vector2 = hazard_director.step_physics(delta)
	environment_feedback.set_wind_acceleration(wind_acceleration)
	low_flight_course.step_physics(delta)
	landing_zone.step_physics(delta)
	_sync_low_flight_feedback()
	_sync_landing_feedback()


func _process(delta: float) -> void:
	_update_auto_retry(delta)
	_update_arrival_transition(delta)
	if not flight_ship.is_failed and not _route_completed:
		_route_elapsed_seconds += maxf(delta, 0.0)
		_update_entry_style_tracking(delta)
		advance_route_state()
	enforce_forward_route_limit()
	if not _route_completed:
		hazard_director.advance_hazards(delta, _maximum_route_distance)
	_sync_camera_to_ship()
	_update_camera_shake(delta)
	_update_route_visuals()
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(RESTART_ACTION):
		restart_from_checkpoint(false)
		get_viewport().set_input_as_handled()


func get_flight_ship() -> FlightLabShip:
	return flight_ship


func get_flight_camera() -> Camera2D:
	return flight_camera


func get_route_hud() -> RedSandRouteHUD:
	return route_hud


func get_route_definition() -> FlightRouteDefinition:
	return route_definition


func get_hazard_director() -> RedSandHazardDirector:
	return hazard_director


func get_environment_feedback() -> RedSandEnvironmentFeedback:
	return environment_feedback


func get_low_flight_course() -> RedSandLowFlightCourse:
	return low_flight_course


func get_landing_zone() -> RedSandLandingZone:
	return landing_zone


func get_active_segment_index() -> int:
	return _active_segment_index


func get_active_segment() -> FlightRouteSegment:
	if route_definition == null or route_definition.segments.is_empty():
		return null
	return route_definition.segments[clampi(
		_active_segment_index,
		0,
		route_definition.segments.size() - 1
	)]


func get_route_distance() -> float:
	if flight_ship == null:
		return 0.0
	return maxf(flight_ship.position.x - route_origin_x, 0.0)


func get_route_progress() -> float:
	if route_definition == null:
		return 0.0
	return route_definition.get_overall_progress(_maximum_route_distance)


func get_route_elapsed_seconds() -> float:
	return _route_elapsed_seconds


func get_planet_visual_scale() -> float:
	if route_visuals == null:
		return 0.0
	return route_visuals.get_planet_scale()


func is_route_completed() -> bool:
	return _route_completed


func is_retry_pending() -> bool:
	return _auto_retry_remaining >= 0.0


func is_arrival_transition_pending() -> bool:
	return _arrival_transition_remaining >= 0.0


func get_landing_result() -> StringName:
	return _landing_result


## Advances only route orchestration; it never rewrites position, velocity, or rotation.
func advance_route_state() -> bool:
	if route_definition == null or flight_ship == null:
		return false
	var route_distance: float = get_route_distance()
	_maximum_route_distance = maxf(_maximum_route_distance, route_distance)
	var requested_index: int = route_definition.get_segment_index(
		_maximum_route_distance
	)
	var changed: bool = false
	while requested_index > _active_segment_index:
		_active_segment_index += 1
		_enter_segment(_active_segment_index)
		changed = true
	return changed


## Keeps reverse useful for corrections without allowing a return to prior route acts.
func enforce_forward_route_limit() -> bool:
	if flight_ship == null or route_definition == null:
		return false
	var active_segment: FlightRouteSegment = get_active_segment()
	if active_segment == null:
		return false
	var minimum_x: float = (
		route_origin_x
		+ active_segment.start_distance
		- route_definition.reverse_allowance_distance
	)
	var maximum_x: float = (
		route_origin_x
		+ route_definition.get_total_distance()
		+ route_definition.finish_hold_distance
	)
	if flight_ship.position.x < minimum_x:
		flight_ship.position.x = minimum_x
		flight_ship.velocity.x = maxf(flight_ship.velocity.x, 0.0)
		return true
	if flight_ship.position.x > maximum_x:
		flight_ship.position.x = maximum_x
		flight_ship.velocity.x = minf(flight_ship.velocity.x, 0.0)
		return true
	return false


func restart_from_checkpoint(is_automatic: bool = false) -> bool:
	if flight_ship == null or not flight_ship.restore_checkpoint():
		return false
	_auto_retry_remaining = NO_RETRY_PENDING
	_clear_camera_shake()
	_active_segment_index = route_definition.get_segment_index(get_route_distance())
	_maximum_route_distance = maxf(
		get_route_distance(),
		get_active_segment().start_distance
	)
	_route_completed = false
	_arrival_transition_remaining = NO_ARRIVAL_TRANSITION_PENDING
	_landing_result = &""
	hazard_director.reset_for_checkpoint(_maximum_route_distance)
	hazard_director.set_active_segment(get_active_segment().id)
	environment_feedback.set_segment(get_active_segment())
	low_flight_course.reset_for_checkpoint()
	low_flight_course.set_active_segment(get_active_segment().id)
	landing_zone.reset_for_checkpoint()
	landing_zone.set_active_segment(get_active_segment().id)
	if (
		_active_segment_index >= ENTRY_START_SEGMENT_INDEX
		and _active_segment_index < ENTRY_FINALIZE_SEGMENT_INDEX
	):
		_begin_entry_style_tracking()
	_sync_camera_to_ship()
	_update_route_visuals()
	_refresh_hud()
	_sync_low_flight_feedback()
	_sync_landing_feedback()
	if is_automatic:
		route_hud.show_auto_retry(flight_ship.get_checkpoint_id())
	else:
		route_hud.show_checkpoint_restored(flight_ship.get_checkpoint_id())
	return true


func _validate_runtime_dependencies() -> bool:
	if (
		flight_ship == null
		or flight_camera == null
		or route_hud == null
		or route_visuals == null
		or hazard_director == null
		or environment_feedback == null
		or low_flight_course == null
		or landing_zone == null
		or route_definition == null
	):
		push_error("Red Sand route is missing required scene dependencies.")
		return false
	var validation_errors: PackedStringArray = route_definition.validate()
	if validation_errors.is_empty():
		return true
	for validation_error: String in validation_errors:
		push_error("Red Sand route data: %s" % validation_error)
	return false


func _enter_segment(segment_index: int) -> void:
	var segment: FlightRouteSegment = route_definition.segments[segment_index]
	flight_ship.set_environment_profile(segment.environment_profile, false)
	hazard_director.set_active_segment(segment.id)
	environment_feedback.set_segment(segment)
	low_flight_course.set_active_segment(segment.id)
	landing_zone.set_active_segment(segment.id)
	flight_ship.capture_checkpoint(segment.checkpoint_id)
	_sync_order_run_checkpoint(segment.checkpoint_id)
	if segment_index == ENTRY_START_SEGMENT_INDEX:
		_begin_entry_style_tracking()
	elif segment_index == ENTRY_FINALIZE_SEGMENT_INDEX:
		_finalize_entry_style()
		_configure_landing_checkpoint(segment)
	route_hud.show_stage_transition(segment)


func _complete_landing(
	quality: int,
	cargo_damage: float,
	landed_global_position: Vector2
) -> void:
	if _route_completed or flight_ship == null:
		return
	if not flight_ship.complete_landing(landed_global_position):
		return
	var applied_cargo_damage: float = flight_ship.apply_delivery_cargo_damage(cargo_damage)
	_route_completed = true
	_maximum_route_distance = route_definition.get_total_distance()
	hazard_director.cancel_slow_motion()
	low_flight_course.set_active_segment(&"")
	landing_zone.set_active_segment(&"")
	_sync_low_flight_feedback()
	_sync_landing_feedback()
	_finalize_entry_style()
	_landing_result = FlightLandingModel.get_result_id(quality)
	_record_landing_result(_landing_result, applied_cargo_damage)
	_sync_order_run_resources()
	route_hud.show_landing_result(_landing_result, flight_ship.cargo_integrity)
	_arrival_transition_remaining = maxf(
		flight_ship.tuning.landing_arrival_transition_delay_seconds
		if flight_ship.tuning != null
		else 0.0,
		0.0
	)


func _begin_entry_style_tracking() -> void:
	if _entry_style_tracker.is_tracking():
		return
	_entry_style_tracker.begin(_resolve_order_run_state())


func _finalize_entry_style() -> void:
	if not _entry_style_tracker.is_tracking() or flight_ship.tuning == null:
		return
	_entry_style_tracker.finalize(flight_ship.tuning)


func _update_entry_style_tracking(delta: float) -> void:
	if (
		flight_ship == null
		or flight_ship.tuning == null
		or not _entry_style_tracker.is_tracking()
	):
		return
	var risk: float = FlightStyleTracker.calculate_normalized_risk(
		flight_ship.get_vertical_speed(),
		flight_ship.get_terminal_fall_speed_safety()
	)
	_entry_style_tracker.record_sample(
		delta,
		flight_ship.velocity,
		risk,
		flight_ship.tuning
	)


func _sync_camera_to_ship() -> void:
	if flight_ship == null or flight_camera == null:
		return
	flight_camera.position = Vector2(
		roundf(flight_ship.position.x),
		roundf(flight_ship.position.y)
	)


func _update_route_visuals() -> void:
	if route_visuals == null:
		return
	route_visuals.update_visuals(_maximum_route_distance)


func _refresh_hud() -> void:
	if route_hud == null or flight_ship == null:
		return
	route_hud.set_route_state(
		_active_segment_index,
		_maximum_route_distance,
		_route_elapsed_seconds,
		flight_ship.get_checkpoint_id()
	)


func _connect_ship_signals() -> void:
	if not flight_ship.impact_resolved.is_connected(_on_impact_resolved):
		flight_ship.impact_resolved.connect(_on_impact_resolved)
	if not flight_ship.flight_failed.is_connected(_on_flight_failed):
		flight_ship.flight_failed.connect(_on_flight_failed)
	if not flight_ship.company_warning_requested.is_connected(
		_on_company_warning_requested
	):
		flight_ship.company_warning_requested.connect(_on_company_warning_requested)
	if not flight_ship.laser_fire_rejected.is_connected(_on_laser_fire_rejected):
		flight_ship.laser_fire_rejected.connect(_on_laser_fire_rejected)
	if not flight_ship.laser_fired.is_connected(_on_laser_fired):
		flight_ship.laser_fired.connect(_on_laser_fired)
	if not flight_ship.boost_blocked.is_connected(_on_boost_blocked):
		flight_ship.boost_blocked.connect(_on_boost_blocked)


func _connect_hazard_signals() -> void:
	if not hazard_director.lightning_warning_started.is_connected(
		_on_lightning_warning_started
	):
		hazard_director.lightning_warning_started.connect(
			_on_lightning_warning_started
		)
	if not hazard_director.lightning_resolved.is_connected(
		_on_lightning_resolved
	):
		hazard_director.lightning_resolved.connect(_on_lightning_resolved)


func _connect_low_flight_signals() -> void:
	if not low_flight_course.notice_requested.is_connected(
		_on_radar_notice_requested
	):
		low_flight_course.notice_requested.connect(_on_radar_notice_requested)


func _connect_landing_signals() -> void:
	if not landing_zone.landing_resolved.is_connected(_on_landing_resolved):
		landing_zone.landing_resolved.connect(_on_landing_resolved)
	if not landing_zone.landing_failed.is_connected(_on_landing_failed):
		landing_zone.landing_failed.connect(_on_landing_failed)


func _on_impact_resolved(severity: int, impact_speed: float) -> void:
	route_hud.show_impact(severity, impact_speed)
	_start_camera_shake(severity)


func _on_flight_failed(reason_key: StringName) -> void:
	hazard_director.cancel_slow_motion()
	var retry_delay: float = maxf(
		flight_ship.tuning.failure_retry_delay_seconds
		if flight_ship.tuning != null
		else 0.0,
		0.0
	)
	_auto_retry_remaining = retry_delay
	route_hud.show_failure(reason_key, retry_delay)


func _on_company_warning_requested(
	warning_key: StringName,
	cargo_integrity: float
) -> void:
	route_hud.show_company_warning(warning_key, cargo_integrity)


func _on_laser_fire_rejected(reason_key: StringName) -> void:
	route_hud.show_laser_rejected(
		reason_key,
		flight_ship.get_laser_cooldown_remaining()
	)


func _on_laser_fired(hit_target: bool) -> void:
	if not hit_target:
		route_hud.show_laser_miss()


func _on_boost_blocked(reason_key: StringName) -> void:
	route_hud.show_boost_blocked(reason_key)


func _on_lightning_warning_started(
	_strike_id: StringName,
	warning_seconds: float,
	slow_motion_active: bool
) -> void:
	route_hud.show_lightning_warning(warning_seconds, slow_motion_active)


func _on_lightning_resolved(
	_strike_id: StringName,
	hit_ship: bool,
	damage: float
) -> void:
	environment_feedback.flash_lightning(hit_ship)
	if hit_ship:
		route_hud.show_lightning_hit(damage)
		_start_camera_shake(FlightCollisionResult.Severity.HARD)
	else:
		route_hud.show_lightning_avoided()


func _on_radar_notice_requested(message_key: StringName) -> void:
	route_hud.show_radar_notice(message_key)


func _on_landing_resolved(
	quality: int,
	cargo_damage: float,
	landed_global_position: Vector2
) -> void:
	_complete_landing(
		quality,
		cargo_damage,
		landed_global_position
	)


func _on_landing_failed(reason_key: StringName) -> void:
	if flight_ship != null:
		flight_ship.fail_flight(reason_key)


func _sync_low_flight_feedback() -> void:
	if low_flight_course == null or route_hud == null or environment_feedback == null:
		return
	route_hud.set_radar_state(
		low_flight_course.get_radar_state_key(),
		low_flight_course.get_lock_risk()
	)
	environment_feedback.set_radar_pressure(
		low_flight_course.get_lock_risk(),
		low_flight_course.is_locked()
	)


func _sync_landing_feedback() -> void:
	if landing_zone == null or route_hud == null or flight_ship == null:
		return
	var metrics: Vector3 = landing_zone.get_landing_metrics()
	route_hud.set_landing_guidance(
		landing_zone.get_guidance_state_key(),
		metrics,
		flight_ship.tuning
	)


func _update_auto_retry(delta: float) -> void:
	if _auto_retry_remaining < 0.0:
		return
	_auto_retry_remaining = maxf(
		_auto_retry_remaining - maxf(delta, 0.0),
		0.0
	)
	if _auto_retry_remaining <= 0.0:
		restart_from_checkpoint(true)


func _update_arrival_transition(delta: float) -> void:
	if _arrival_transition_remaining < 0.0:
		return
	_arrival_transition_remaining = maxf(
		_arrival_transition_remaining - maxf(delta, 0.0),
		0.0
	)
	if _arrival_transition_remaining > 0.0:
		return
	_arrival_transition_remaining = NO_ARRIVAL_TRANSITION_PENDING
	var scene_router: SceneRouterService = _resolve_scene_router()
	if (
		scene_router == null
		or scene_router.current_stage != SceneRouterService.Stage.FLIGHT
	):
		return
	if not scene_router.request_stage(SceneRouterService.Stage.ARRIVAL):
		push_error("Landing could not enter ARRIVAL: %s" % scene_router.last_error)


func _start_camera_shake(severity: int) -> void:
	if flight_ship.tuning == null:
		return
	match severity:
		FlightCollisionResult.Severity.GRAZE:
			_camera_shake_amplitude = flight_ship.tuning.graze_camera_shake
		FlightCollisionResult.Severity.HARD:
			_camera_shake_amplitude = flight_ship.tuning.hard_camera_shake
		FlightCollisionResult.Severity.FATAL:
			_camera_shake_amplitude = flight_ship.tuning.fatal_camera_shake
		_:
			return
	_camera_shake_duration = maxf(
		flight_ship.tuning.collision_camera_shake_duration,
		0.0
	)
	_camera_shake_remaining = _camera_shake_duration
	_camera_shake_elapsed = 0.0


func _update_camera_shake(delta: float) -> void:
	if flight_camera == null:
		return
	if _camera_shake_remaining <= 0.0 or _camera_shake_duration <= 0.0:
		flight_camera.offset = Vector2.ZERO
		return
	_camera_shake_elapsed += maxf(delta, 0.0)
	_camera_shake_remaining = maxf(_camera_shake_remaining - maxf(delta, 0.0), 0.0)
	var fade: float = _camera_shake_remaining / _camera_shake_duration
	var phase: float = _camera_shake_elapsed * 82.0
	flight_camera.offset = Vector2(sin(phase), cos(phase * 1.37)) * (
		_camera_shake_amplitude * fade * _resolve_screen_shake_strength()
	)


func _clear_camera_shake() -> void:
	_camera_shake_remaining = 0.0
	_camera_shake_duration = 0.0
	_camera_shake_elapsed = 0.0
	_camera_shake_amplitude = 0.0
	if flight_camera != null:
		flight_camera.offset = Vector2.ZERO


func _resolve_assist_strength() -> float:
	var settings_service: SettingsServiceModel = _resolve_settings_service()
	if settings_service == null:
		return FlightLabShip.DEFAULT_ASSIST_STRENGTH
	return settings_service.settings.flight_assist_strength


func _resolve_screen_shake_strength() -> float:
	var settings_service: SettingsServiceModel = _resolve_settings_service()
	if settings_service == null:
		return LocalSettingsData.DEFAULT_SCREEN_SHAKE_STRENGTH
	return clampf(settings_service.settings.screen_shake_strength, 0.0, 1.0)


func _resolve_settings_service() -> SettingsServiceModel:
	if settings_service_override != null:
		return settings_service_override
	return get_node_or_null("/root/SettingsService") as SettingsServiceModel


func _resolve_game_state() -> GameStateModel:
	if game_state_override != null:
		return game_state_override
	return get_node_or_null("/root/GameState") as GameStateModel


func _resolve_scene_router() -> SceneRouterService:
	if scene_router_override != null:
		return scene_router_override
	return get_node_or_null("/root/SceneRouter") as SceneRouterService


func _resolve_order_run_state() -> OrderRunState:
	var game_state: GameStateModel = _resolve_game_state()
	if game_state != null:
		var run_state: OrderRunState = game_state.get_active_order_run_state()
		if run_state != null:
			return run_state
	if _local_order_run_state == null:
		_local_order_run_state = OrderRunState.new()
	return _local_order_run_state


func _resolve_laser_enabled_from_loadout() -> bool:
	if data_registry == null:
		return false
	var game_state: GameStateModel = _resolve_game_state()
	if game_state == null:
		return false
	return FlightWeaponRules.has_asteroid_laser(
		game_state.ship_configuration,
		data_registry.modules
	)


func _sync_order_run_checkpoint(checkpoint_id: StringName) -> void:
	var run_state: OrderRunState = _resolve_order_run_state()
	if run_state != null:
		run_state.active_checkpoint_id = checkpoint_id


func _configure_landing_checkpoint(segment: FlightRouteSegment) -> void:
	if segment == null or landing_zone == null or flight_ship == null:
		return
	if not flight_ship.configure_safe_checkpoint(
		segment.checkpoint_id,
		landing_zone.get_safe_checkpoint_position(),
		landing_zone.get_safe_checkpoint_velocity(),
		0.0
	):
		push_error("Red Sand landing checkpoint could not be configured.")
		return
	_sync_order_run_checkpoint(segment.checkpoint_id)


func _record_landing_result(result_id: StringName, cargo_damage: float) -> void:
	var run_state: OrderRunState = _resolve_order_run_state()
	if run_state != null and not run_state.record_landing_result(result_id, cargo_damage):
		push_error("Red Sand landing produced an unsupported result: %s" % result_id)


func _sync_order_run_resources() -> void:
	var run_state: OrderRunState = _resolve_order_run_state()
	if run_state == null or flight_ship == null:
		return
	run_state.cargo_integrity = flight_ship.cargo_integrity
	run_state.hull = flight_ship.hull
	run_state.shield = flight_ship.shield
	run_state.fuel = flight_ship.fuel
	run_state.boost_energy = flight_ship.boost_energy
	run_state.active_checkpoint_id = flight_ship.get_checkpoint_id()
