class_name RedSandFlight
extends Node2D

const RESTART_ACTION: StringName = &"flight_restart"
const CONTROLS_HELP_ACTION: StringName = &"flight_controls_help"
const HUD_TOGGLE_ACTION: StringName = &"flight_debug_toggle"
const ROUTE_DETAILS_ACTION: StringName = &"flight_route_hint"
const ASSIST_CYCLE_ACTION: StringName = &"flight_assist_cycle"
const LASER_TOGGLE_ACTION: StringName = &"flight_laser_toggle"
const NO_RETRY_PENDING: float = -1.0
const NO_ARRIVAL_TRANSITION_PENDING: float = -1.0
const ENTRY_START_SEGMENT_INDEX: int = 3
const ENTRY_FINALIZE_SEGMENT_INDEX: int = 7
const ALTITUDE_INVARIANT_WINDOW_SECONDS: float = 0.45
const ALTITUDE_INVARIANT_EXPECTED_CHANGE_METERS: float = 12.0
const ALTITUDE_INVARIANT_MAX_FINAL_CHANGE_METERS: float = 0.75

@onready var flight_ship: FlightLabShip = %FlightShip
@onready var altitude_reference_point: Node2D = %AltitudeReferencePoint
@onready var flight_camera: Camera2D = %FlightCamera
@onready var route_hud: RedSandRouteHUD = %RedSandRouteHUD
@onready var route_visuals: RedSandRouteVisuals = %RouteGeometry
@onready var hazard_director: RedSandHazardDirector = %Hazards
@onready var environment_feedback: RedSandEnvironmentFeedback = %EnvironmentFeedback
@onready var low_flight_course: RedSandLowFlightCourse = %LowFlightCourse
@onready var landing_zone: RedSandLandingZone = %LandingZone
@onready var scenic_triggers: Node2D = %ScenicTriggers

@export var route_definition: FlightRouteDefinition
@export var data_registry: GameDataRegistry
@export var route_origin_x: float = 320.0
@export var initial_ship_y: float = 190.0
@export var force_direct_test_mode: bool = false

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
var _altitude_failure_latched: bool = false
var _altitude_invariant_latched: bool = false
var _altitude_invariant_elapsed: float = 0.0
var _altitude_invariant_start_ship_y: float = 0.0
var _altitude_invariant_start_ground_y: float = 0.0
var _altitude_invariant_start_final_agl: float = 0.0
var _controls_help_open: bool = false
var _was_tree_paused: bool = false
var _direct_test_mode: bool = false
var _active_assist_index: int = 1
var _altitude_reference_provider: FlightAltitudeReferenceProvider = (
	FlightAltitudeReferenceProvider.new()
)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	flight_ship.process_mode = Node.PROCESS_MODE_PAUSABLE
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
		_resolve_settings_service(),
		flight_camera
	):
		push_error("Red Sand route could not configure its fixed hazards.")
		return
	if not low_flight_course.bind(
		flight_ship,
		route_origin_x,
		_resolve_settings_service(),
		_altitude_reference_provider
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
	_connect_scenic_triggers()
	if not route_hud.controls_help_close_requested.is_connected(
		close_controls_help
	):
		route_hud.controls_help_close_requested.connect(close_controls_help)
	_entry_style_tracker.bind_run_state(_resolve_order_run_state())
	flight_ship.set_laser_enabled(_resolve_laser_enabled_from_loadout())
	var assist_strength: float = _resolve_assist_strength()
	_active_assist_index = FlightAssistMode.get_nearest_preset_index(assist_strength)
	_direct_test_mode = (
		force_direct_test_mode
		or (
			OS.is_debug_build()
			and OS.get_cmdline_user_args().has(
				UniverseDeliverApp.DEBUG_RED_SAND_ROUTE_ARGUMENT
			)
		)
	)
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
	_reset_altitude_reference()
	_sync_order_run_checkpoint(first_segment.checkpoint_id)
	route_hud.bind(
		flight_ship,
		route_definition,
		_altitude_reference_provider,
		landing_zone.get_landing_center_route_distance()
	)
	_sync_camera_to_ship()
	_update_route_visuals()
	_refresh_hud()
	_sync_low_flight_feedback()
	_sync_landing_feedback()
	call_deferred("_open_initial_controls_help")


func _exit_tree() -> void:
	if _controls_help_open and get_tree() != null:
		get_tree().paused = _was_tree_paused
	_controls_help_open = false
	if flight_ship != null:
		flight_ship.cancel_held_fire(true)
	if hazard_director != null:
		hazard_director.cancel_slow_motion()
	if landing_zone != null:
		landing_zone.clear_touchdown_effects()


func _physics_process(delta: float) -> void:
	if _controls_help_open:
		return
	if (
		hazard_director == null
		or environment_feedback == null
		or low_flight_course == null
		or landing_zone == null
	):
		return
	var wind_acceleration: Vector2 = hazard_director.step_physics(delta)
	environment_feedback.set_wind_acceleration(wind_acceleration)
	_update_altitude_reference(delta)
	low_flight_course.step_physics(delta)
	landing_zone.step_physics(delta)
	_sync_low_flight_feedback()
	_sync_landing_feedback()


func _process(delta: float) -> void:
	if _controls_help_open:
		return
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
	_update_route_visuals(delta)
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if _controls_help_open:
		if (
			event.is_action_pressed(CONTROLS_HELP_ACTION)
			or event.is_action_pressed(&"pause")
			or event.is_action_pressed(&"interact")
			or event.is_action_pressed(&"ui_accept")
		):
			close_controls_help()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(CONTROLS_HELP_ACTION):
		open_controls_help()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(HUD_TOGGLE_ACTION):
		route_hud.toggle_full_diagnostics()
		get_viewport().set_input_as_handled()
		return
	if _direct_test_mode and event.is_action_pressed(ROUTE_DETAILS_ACTION):
		route_hud.toggle_route_details()
		get_viewport().set_input_as_handled()
		return
	if _direct_test_mode and event.is_action_pressed(ASSIST_CYCLE_ACTION):
		cycle_test_assist_mode()
		get_viewport().set_input_as_handled()
		return
	if _direct_test_mode and event.is_action_pressed(LASER_TOGGLE_ACTION):
		toggle_test_laser_loadout()
		get_viewport().set_input_as_handled()
		return
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


func get_altitude_reference_provider() -> FlightAltitudeReferenceProvider:
	return _altitude_reference_provider


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


func is_controls_help_open() -> bool:
	return _controls_help_open


func is_direct_test_mode() -> bool:
	return _direct_test_mode


func open_controls_help() -> bool:
	if _controls_help_open or route_hud == null or flight_ship == null:
		return false
	_controls_help_open = true
	_was_tree_paused = get_tree().paused
	flight_ship.cancel_held_fire(true)
	route_hud.show_controls_help(
		_direct_test_mode,
		flight_ship.is_laser_enabled()
	)
	get_tree().paused = true
	return true


func close_controls_help() -> bool:
	if not _controls_help_open:
		return false
	_controls_help_open = false
	if route_hud != null:
		route_hud.hide_controls_help()
	if get_tree() != null:
		get_tree().paused = _was_tree_paused
	return true


func _open_initial_controls_help() -> void:
	if is_inside_tree() and not _route_completed:
		open_controls_help()


func cycle_test_assist_mode() -> float:
	if not _direct_test_mode or flight_ship == null:
		return flight_ship.assist_strength if flight_ship != null else 0.0
	var presets: Array[float] = FlightAssistMode.get_presets()
	_active_assist_index = (_active_assist_index + 1) % presets.size()
	var assist_strength: float = presets[_active_assist_index]
	flight_ship.set_assist_strength(assist_strength)
	var segment: FlightRouteSegment = get_active_segment()
	if segment != null:
		flight_ship.capture_checkpoint(
			segment.checkpoint_id,
			segment.checkpoint_fuel_floor
		)
	route_hud.show_assist_changed(assist_strength)
	return assist_strength


func toggle_test_laser_loadout() -> bool:
	if not _direct_test_mode or not OS.is_debug_build() or flight_ship == null:
		return false
	var enabled: bool = not flight_ship.is_laser_enabled()
	flight_ship.set_laser_enabled(enabled)
	route_hud.update_controls_help_laser_state(enabled)
	route_hud.show_laser_loadout_changed(enabled)
	return enabled


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
	route_visuals.reset_to_distance(_maximum_route_distance)
	_reset_altitude_reference()
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
		or altitude_reference_point == null
		or flight_camera == null
		or route_hud == null
		or route_visuals == null
		or hazard_director == null
		or environment_feedback == null
		or low_flight_course == null
		or landing_zone == null
		or scenic_triggers == null
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
	_update_altitude_reference(0.0)
	var altitude_handoff_valid: bool = (
		_altitude_reference_provider.get_mode_name() != &"AGL"
		or _altitude_reference_provider.is_current_source_valid()
	)
	if altitude_handoff_valid:
		flight_ship.capture_checkpoint(
			segment.checkpoint_id,
			segment.checkpoint_fuel_floor
		)
		_sync_order_run_checkpoint(segment.checkpoint_id)
	else:
		push_error(
			"Red Sand refused an invalid Stage %d altitude checkpoint: %s"
			% [segment_index + 1, get_altitude_diagnostic_snapshot()]
		)
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
	landing_zone.burst_touchdown_dust(landed_global_position)
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
	if _entry_style_tracker.begin(_resolve_order_run_state()):
		_reset_scenic_triggers()


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
	var boost_strength: float = flight_ship.get_boost_feedback_strength()
	flight_camera.position = Vector2(
		roundf(flight_ship.position.x + boost_strength * 18.0),
		roundf(flight_ship.position.y)
	)
	var boost_zoom: float = lerpf(1.0, 0.96, boost_strength)
	flight_camera.zoom = Vector2.ONE * boost_zoom


func _update_route_visuals(delta: float = 0.0) -> void:
	if route_visuals != null:
		route_visuals.update_visuals(_maximum_route_distance, delta)
	if environment_feedback != null and flight_ship != null:
		if route_visuals != null:
			environment_feedback.set_orbit_to_atmosphere_visual_progress(
				route_visuals.get_orbit_to_atmosphere_visual_progress()
			)
		environment_feedback.set_ship_feedback(
			flight_ship.get_speed(),
			flight_ship.effective_throttle_input,
			flight_ship.get_boost_feedback_strength(),
			flight_ship.air_density,
			flight_ship.is_failed or flight_ship.is_landed or _route_completed
		)


func _update_altitude_reference(delta: float) -> void:
	if (
		_altitude_reference_provider == null
		or flight_ship == null
		or altitude_reference_point == null
		or route_definition == null
	):
		return
	var segment: FlightRouteSegment = get_active_segment()
	if segment == null:
		return
	var route_distance: float = get_route_distance()
	var profile_ground_y: float = _get_canonical_ground_route_y(route_distance)
	var profile_valid: bool = (
		_active_segment_index >= FlightAltitudeReferenceProvider.ATMOSPHERE_FINAL_SEGMENT_INDEX
		and route_definition.has_ground_profile(_active_segment_index)
	)
	_altitude_reference_provider.update_from_canonical_frame(
		_active_segment_index,
		segment.get_progress(_maximum_route_distance),
		route_distance,
		to_local(altitude_reference_point.global_position).y,
		profile_ground_y,
		profile_valid,
		route_definition.get_ground_profile_segment_id(_active_segment_index),
		altitude_reference_point,
		flight_ship,
		self,
		delta
	)
	_validate_agl_source()
	_update_altitude_invariant(delta)


func _reset_altitude_reference() -> void:
	if (
		_altitude_reference_provider == null
		or flight_ship == null
		or altitude_reference_point == null
		or route_definition == null
	):
		return
	var segment: FlightRouteSegment = get_active_segment()
	if segment == null:
		return
	var route_distance: float = get_route_distance()
	_altitude_reference_provider.reset_to_canonical_frame(
		_active_segment_index,
		segment.get_progress(_maximum_route_distance),
		route_distance,
		to_local(altitude_reference_point.global_position).y,
		_get_canonical_ground_route_y(route_distance),
		_active_segment_index >= FlightAltitudeReferenceProvider.ATMOSPHERE_FINAL_SEGMENT_INDEX
		and route_definition.has_ground_profile(_active_segment_index),
		route_definition.get_ground_profile_segment_id(_active_segment_index),
		altitude_reference_point,
		flight_ship,
		self
	)
	_altitude_invariant_latched = false
	_reset_altitude_invariant_window()
	_validate_agl_source()


func _validate_agl_source() -> void:
	if _altitude_reference_provider == null:
		return
	var agl_failed: bool = (
		_altitude_reference_provider.get_mode_name() == &"AGL"
		and not _altitude_reference_provider.has_numeric_altitude()
	)
	var source_mismatch: bool = (
		_altitude_reference_provider.get_mode_name() == &"AGL"
		and _altitude_reference_provider.has_cross_source_mismatch()
	)
	if (agl_failed or source_mismatch) and not _altitude_failure_latched:
		push_error(
			"Red Sand AGL source failed in stage %d: %s"
			% [
				_active_segment_index + 1,
				get_altitude_diagnostic_snapshot(),
			]
		)
	_altitude_failure_latched = agl_failed or source_mismatch


func _get_canonical_ground_route_y(route_distance: float) -> float:
	var ground_y: float = route_definition.get_ground_route_y(
		route_distance,
		_active_segment_index
	)
	if (
		landing_zone != null
		and landing_zone.has_altitude_surface_override(route_distance)
	):
		ground_y = to_local(
			landing_zone.get_altitude_surface_global_position()
		).y
	return ground_y


func _update_altitude_invariant(delta: float) -> void:
	if not OS.is_debug_build() or delta <= 0.0:
		return
	if (
		_altitude_reference_provider.get_mode_name() != &"AGL"
		or not _altitude_reference_provider.is_current_source_valid()
		or not _altitude_reference_provider.has_numeric_altitude()
		or flight_ship.is_on_floor()
	):
		_reset_altitude_invariant_window()
		return
	if _altitude_invariant_elapsed <= 0.0:
		_altitude_invariant_start_ship_y = (
			_altitude_reference_provider.ship_reference_route_y
		)
		_altitude_invariant_start_ground_y = (
			_altitude_reference_provider.ground_route_y
		)
		_altitude_invariant_start_final_agl = (
			_altitude_reference_provider.final_agl_altitude_meters
		)
	_altitude_invariant_elapsed += delta
	if _altitude_invariant_elapsed < ALTITUDE_INVARIANT_WINDOW_SECONDS:
		return
	if (
		FlightAltitudeReferenceProvider.is_motion_invariant_violated(
			_altitude_invariant_start_ship_y,
			_altitude_reference_provider.ship_reference_route_y,
			_altitude_invariant_start_ground_y,
			_altitude_reference_provider.ground_route_y,
			_altitude_invariant_start_final_agl,
			_altitude_reference_provider.final_agl_altitude_meters,
			_altitude_reference_provider.meters_per_route_unit,
			ALTITUDE_INVARIANT_EXPECTED_CHANGE_METERS,
			ALTITUDE_INVARIANT_MAX_FINAL_CHANGE_METERS
		)
		and not _altitude_invariant_latched
	):
		_altitude_invariant_latched = true
		push_error(
			"Altitude invariant violated: vertical_velocity=%.2f %s"
			% [flight_ship.get_vertical_speed(), get_altitude_diagnostic_snapshot()]
		)
	_reset_altitude_invariant_window()


func _reset_altitude_invariant_window() -> void:
	_altitude_invariant_elapsed = 0.0
	_altitude_invariant_start_ship_y = 0.0
	_altitude_invariant_start_ground_y = 0.0
	_altitude_invariant_start_final_agl = 0.0


func has_altitude_invariant_violation() -> bool:
	return _altitude_invariant_latched


func get_altitude_diagnostic_snapshot() -> String:
	if _altitude_reference_provider == null:
		return "provider=<missing>"
	return (
		"stage=%d route=%.2f source=%s valid=%s ship_y=%.2f ground_y=%.2f "
		+ "agl=%.2f raw_ray=%.2f raw_profile=%.2f last=%.2f invalid=%.3f "
		+ "ray_hit=%s profile=%s blend=%.3f failure=%s"
	) % [
		_active_segment_index + 1,
		_altitude_reference_provider.canonical_route_distance,
		_altitude_reference_provider.get_source_name(),
		_altitude_reference_provider.has_numeric_altitude(),
		_altitude_reference_provider.ship_reference_route_y,
		_altitude_reference_provider.ground_route_y,
		_altitude_reference_provider.final_agl_altitude_meters,
		_altitude_reference_provider.raw_raycast_altitude_meters,
		_altitude_reference_provider.raw_profile_altitude_meters,
		_altitude_reference_provider.last_valid_agl_meters,
		_altitude_reference_provider.invalid_duration_seconds,
		_altitude_reference_provider.get_ground_node_path(),
		_altitude_reference_provider.terrain_profile_segment_id,
		_altitude_reference_provider.atmosphere_to_agl_blend,
		_altitude_reference_provider.get_failure_reason(),
	]


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
	if not low_flight_course.lock_consequence_requested.is_connected(
		_on_radar_lock_consequence_requested
	):
		low_flight_course.lock_consequence_requested.connect(
			_on_radar_lock_consequence_requested
		)


func _connect_landing_signals() -> void:
	if not landing_zone.landing_resolved.is_connected(_on_landing_resolved):
		landing_zone.landing_resolved.connect(_on_landing_resolved)
	if not landing_zone.landing_failed.is_connected(_on_landing_failed):
		landing_zone.landing_failed.connect(_on_landing_failed)


func _connect_scenic_triggers() -> void:
	if scenic_triggers == null:
		return
	for child: Node in scenic_triggers.get_children():
		if not child is FlightScenicTrigger:
			continue
		var trigger: FlightScenicTrigger = child as FlightScenicTrigger
		if not trigger.triggered.is_connected(_on_scenic_triggered):
			trigger.triggered.connect(_on_scenic_triggered)


func _reset_scenic_triggers() -> void:
	if scenic_triggers == null:
		return
	for child: Node in scenic_triggers.get_children():
		if child is FlightScenicTrigger:
			(child as FlightScenicTrigger).reset_trigger()


func _on_impact_resolved(severity: int, impact_speed: float) -> void:
	if severity != FlightCollisionResult.Severity.NONE:
		_entry_style_tracker.record_collision()
	route_hud.show_impact(severity, impact_speed)
	_start_camera_shake(severity)


func _on_scenic_triggered(trigger_id: StringName) -> void:
	_entry_style_tracker.record_scenic_trigger(trigger_id)


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


func _on_radar_lock_consequence_requested(
	damage: float,
	cargo_damage: float,
	reason_key: StringName
) -> void:
	if flight_ship == null:
		return
	if flight_ship.apply_environment_damage(damage, cargo_damage, reason_key):
		environment_feedback.trigger_radar_pulse()
		route_hud.show_radar_consequence(damage, cargo_damage)
		_start_camera_shake(FlightCollisionResult.Severity.GRAZE)


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
	if (
		low_flight_course == null
		or route_hud == null
		or environment_feedback == null
		or _altitude_reference_provider == null
	):
		return
	var altitude: float = _altitude_reference_provider.get_radar_altitude_meters()
	var landing_preparation_active: bool = (
		get_active_segment() != null
		and get_active_segment().id == &"red_sand_landing_preparation"
	)
	var radar_state_key: StringName = low_flight_course.get_radar_state_key()
	if landing_preparation_active:
		radar_state_key = &"UI_RED_SAND_RADAR_STATE_LANDING_BUFFER"
	route_hud.set_radar_state(
		radar_state_key,
		low_flight_course.get_lock_risk(),
		altitude,
		low_flight_course.get_minimum_safe_altitude_meters(),
		landing_preparation_active
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
		0.0,
		segment.checkpoint_fuel_floor
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
