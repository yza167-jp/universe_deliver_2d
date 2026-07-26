class_name WhiteNoiseFlight
extends Node2D

const RESTART_ACTION: StringName = &"flight_restart"
const CONTROLS_HELP_ACTION: StringName = &"flight_controls_help"
const HUD_TOGGLE_ACTION: StringName = &"flight_debug_toggle"
const ASSIST_CYCLE_ACTION: StringName = &"flight_assist_cycle"
const ROUTE_ORIGIN_X: float = WhiteNoiseRouteVisuals.ROUTE_ORIGIN_X
const BASE_PLANET_GRAVITY: float = 200.0
const NO_RETRY_PENDING: float = -1.0
const ROUTE_COMPLETE_HOLD_DISTANCE: float = 180.0
const ASSIST_PRESETS: Array[float] = [
	FlightAssistMode.OFF,
	FlightAssistMode.LIMITED,
	FlightAssistMode.UNLIMITED,
]

@onready var flight_ship: FlightLabShip = %FlightShip
@onready var flight_camera: Camera2D = %FlightCamera
@onready var debug_hud: FlightDebugHUD = %FlightDebugHUD
@onready var route_hud: WhiteNoiseRouteHUD = %WhiteNoiseRouteHUD
@onready var route_visuals: WhiteNoiseRouteVisuals = %RouteVisuals
@onready var storm_controller: WhiteNoiseStormController = %StormController
@onready var environment_feedback: WhiteNoiseEnvironmentFeedback = (
	%EnvironmentPresentation
)

@export var route_definition: WhiteNoiseRouteDefinition
@export var planet_definition: PlanetDefinition
@export var data_registry: GameDataRegistry

var game_state_override: GameStateModel
var settings_service_override: SettingsServiceModel
var _active_segment_index: int = 0
var _maximum_route_distance: float = 0.0
var _active_branch_id: StringName = &""
var _branch_rejoined: bool = false
var _route_completed: bool = false
var _auto_retry_remaining: float = NO_RETRY_PENDING
var _controls_help_open: bool = false
var _was_tree_paused: bool = false
var _active_assist_index: int = 1
var _settings_service: SettingsServiceModel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	flight_ship.process_mode = Node.PROCESS_MODE_PAUSABLE
	if not _validate_configuration():
		return
	route_visuals.route_definition = route_definition
	flight_ship.set_environment_profile(
		route_definition.segments[0].environment_profile,
		true
	)
	flight_ship.set_assist_strength(FlightAssistMode.LIMITED)
	_active_assist_index = 1
	_configure_ship_loadout()
	_settings_service = _resolve_settings_service()
	environment_feedback.bind(_settings_service)
	environment_feedback.set_segment(route_definition.segments[0])
	debug_hud.bind_ship(flight_ship)
	debug_hud.set_route_guide_visible(false)
	route_hud.bind(self, flight_ship)
	if not storm_controller.bind(
		self,
		flight_ship,
		route_hud,
		route_visuals,
		_settings_service
	):
		return
	_connect_ship_signals()
	_configure_checkpoint(0)
	restart_from_checkpoint(false)


func _process(delta: float) -> void:
	if flight_ship == null or route_definition == null:
		return
	if not _controls_help_open and not get_tree().paused:
		advance_route_state()
		_enforce_route_bounds()
		_update_branch_state()
		storm_controller.advance(delta, _maximum_route_distance)
		_try_complete_landing()
		_update_auto_retry(delta)
		_sync_camera()
		debug_hud.refresh()
		route_hud.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(CONTROLS_HELP_ACTION):
		if _controls_help_open:
			close_controls_help()
		else:
			open_controls_help()
		get_viewport().set_input_as_handled()
		return
	if _controls_help_open:
		return
	if event.is_action_pressed(RESTART_ACTION):
		restart_from_checkpoint(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(HUD_TOGGLE_ACTION):
		debug_hud.toggle_full_diagnostics()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(ASSIST_CYCLE_ACTION):
		cycle_assist_mode()
		get_viewport().set_input_as_handled()


func get_flight_ship() -> FlightLabShip:
	return flight_ship


func get_flight_camera() -> Camera2D:
	return flight_camera


func get_route_hud() -> WhiteNoiseRouteHUD:
	return route_hud


func get_route_visuals() -> WhiteNoiseRouteVisuals:
	return route_visuals


func get_storm_controller() -> WhiteNoiseStormController:
	return storm_controller


func get_environment_feedback() -> WhiteNoiseEnvironmentFeedback:
	return environment_feedback


func get_route_definition() -> WhiteNoiseRouteDefinition:
	return route_definition


func get_route_distance() -> float:
	if flight_ship == null:
		return 0.0
	return maxf(flight_ship.position.x - ROUTE_ORIGIN_X, 0.0)


func get_overall_progress() -> float:
	return route_definition.get_overall_progress(get_route_distance())


func get_active_segment_index() -> int:
	return _active_segment_index


func get_active_segment() -> FlightRouteSegment:
	if (
		route_definition == null
		or _active_segment_index < 0
		or _active_segment_index >= route_definition.segments.size()
	):
		return null
	return route_definition.segments[_active_segment_index]


func get_active_branch_id() -> StringName:
	return _active_branch_id


func has_branch_rejoined() -> bool:
	return _branch_rejoined


func is_route_completed() -> bool:
	return _route_completed


func is_retry_pending() -> bool:
	return _auto_retry_remaining >= 0.0


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


func restart_from_checkpoint(is_automatic: bool = false) -> bool:
	if flight_ship == null or not flight_ship.restore_checkpoint():
		return false
	_auto_retry_remaining = NO_RETRY_PENDING
	_route_completed = false
	_active_segment_index = route_definition.get_segment_index(
		get_route_distance()
	)
	_maximum_route_distance = maxf(
		float(get_active_segment().start_distance),
		get_route_distance()
	)
	if _maximum_route_distance < route_definition.get_branch_split_distance():
		_active_branch_id = &""
		_branch_rejoined = false
	elif _active_branch_id.is_empty():
		_active_branch_id = &"white_noise_balanced"
		_branch_rejoined = (
			_maximum_route_distance >= route_definition.get_branch_join_distance()
		)
	storm_controller.reset_for_route(_maximum_route_distance)
	environment_feedback.set_segment(get_active_segment())
	_sync_camera()
	route_hud.refresh()
	if is_automatic:
		route_hud.show_retry()
	return true


func open_controls_help() -> bool:
	if _controls_help_open:
		return false
	_controls_help_open = true
	_was_tree_paused = get_tree().paused
	flight_ship.cancel_held_fire(true)
	route_hud.show_controls_help()
	get_tree().paused = true
	return true


func close_controls_help() -> bool:
	if not _controls_help_open:
		return false
	_controls_help_open = false
	route_hud.hide_controls_help()
	get_tree().paused = _was_tree_paused
	return true


func cycle_assist_mode() -> float:
	_active_assist_index = (_active_assist_index + 1) % ASSIST_PRESETS.size()
	var assist_strength: float = ASSIST_PRESETS[_active_assist_index]
	flight_ship.set_assist_strength(assist_strength)
	return assist_strength


func debug_set_route_state(
	route_distance: float,
	branch_id: StringName = &"white_noise_balanced"
) -> bool:
	if not OS.is_debug_build() or route_definition == null or flight_ship == null:
		return false
	var clamped_distance: float = clampf(
		route_distance,
		0.0,
		route_definition.get_total_distance()
	)
	var branch: WhiteNoiseRouteBranch = route_definition.get_branch(branch_id)
	var ship_y: float = _get_safe_retry_y(
		route_definition.get_segment_index(clamped_distance)
	)
	if (
		branch != null
		and clamped_distance >= branch.split_distance
		and clamped_distance < branch.join_distance
	):
		ship_y = branch.retry_y
		_active_branch_id = branch.id
		_branch_rejoined = false
	elif clamped_distance >= route_definition.get_branch_join_distance():
		_active_branch_id = branch_id
		_branch_rejoined = true
	flight_ship.position = Vector2(ROUTE_ORIGIN_X + clamped_distance, ship_y)
	flight_ship.velocity = Vector2.ZERO
	flight_ship.rotation = 0.0
	_maximum_route_distance = clamped_distance
	_active_segment_index = route_definition.get_segment_index(clamped_distance)
	flight_ship.set_environment_profile(
		get_active_segment().environment_profile,
		true
	)
	_configure_checkpoint(_active_segment_index)
	storm_controller.reset_for_route(clamped_distance)
	environment_feedback.set_segment(get_active_segment())
	_sync_camera()
	route_hud.refresh()
	return true


func debug_set_storm_state(
	state: WhiteNoiseInterferenceModel.State,
	elapsed_seconds: float = 0.0
) -> bool:
	if storm_controller == null:
		return false
	return storm_controller.debug_set_state(state, elapsed_seconds)


func _enter_segment(segment_index: int) -> void:
	if segment_index < 0 or segment_index >= route_definition.segments.size():
		return
	var segment: FlightRouteSegment = route_definition.segments[segment_index]
	flight_ship.set_environment_profile(segment.environment_profile, false)
	environment_feedback.set_segment(segment)
	_configure_checkpoint(segment_index)
	route_hud.show_checkpoint(segment.checkpoint_id)


func _configure_checkpoint(segment_index: int) -> bool:
	var segment: FlightRouteSegment = route_definition.segments[segment_index]
	var checkpoint_x: float = (
		ROUTE_ORIGIN_X + segment.start_distance + 96.0
	)
	var checkpoint_y: float = _get_safe_retry_y(segment_index)
	if (
		segment_index == 2
		and not _active_branch_id.is_empty()
	):
		var branch: WhiteNoiseRouteBranch = (
			route_definition.get_branch(_active_branch_id)
		)
		if branch != null:
			checkpoint_y = branch.retry_y
	return flight_ship.configure_safe_checkpoint(
		segment.checkpoint_id,
		Vector2(checkpoint_x, checkpoint_y),
		Vector2(120.0, 0.0),
		0.0,
		segment.checkpoint_fuel_floor
	)


func _get_safe_retry_y(segment_index: int) -> float:
	match segment_index:
		0:
			return 180.0
		1:
			return 240.0
		2:
			return 325.0
		3:
			return 260.0
		4:
			return 280.0
		5:
			return 300.0
	return 240.0


func _update_branch_state() -> void:
	var distance: float = _maximum_route_distance
	if (
		_active_branch_id.is_empty()
		and distance >= route_definition.get_branch_split_distance()
		and distance < route_definition.get_branch_join_distance()
	):
		var branch: WhiteNoiseRouteBranch = (
			route_definition.choose_branch(flight_ship.position.y)
		)
		if branch != null:
			_active_branch_id = branch.id
	if (
		not _active_branch_id.is_empty()
		and distance >= route_definition.get_branch_join_distance()
	):
		_branch_rejoined = true


func _try_complete_landing() -> bool:
	if _route_completed or flight_ship.is_failed or flight_ship.is_landed:
		return false
	if get_route_distance() < route_visuals.get_landing_contact_distance():
		return false
	var horizontal_speed: float = absf(flight_ship.velocity.x)
	var descent_speed: float = maxf(flight_ship.velocity.y, 0.0)
	var pitch_degrees: float = absf(flight_ship.get_pitch_degrees())
	var tuning: FlightTuning = flight_ship.tuning
	if (
		flight_ship.position.y < route_visuals.get_landing_pad_y() - 42.0
		or horizontal_speed > tuning.landing_success_max_horizontal_speed
		or descent_speed > tuning.landing_success_max_descent_speed
		or pitch_degrees > tuning.landing_success_max_pitch_degrees
	):
		return false
	flight_ship.complete_landing(Vector2(
		ROUTE_ORIGIN_X + route_visuals.get_landing_contact_distance(),
		route_visuals.get_landing_pad_y() - 10.0
	))
	_route_completed = true
	route_hud.show_route_complete()
	return true


func _enforce_route_bounds() -> void:
	var minimum_x: float = (
		ROUTE_ORIGIN_X
		+ get_active_segment().start_distance
		- route_definition.reverse_allowance_distance
	)
	var maximum_x: float = (
		ROUTE_ORIGIN_X
		+ route_definition.get_total_distance()
		+ ROUTE_COMPLETE_HOLD_DISTANCE
	)
	if flight_ship.position.x < minimum_x:
		flight_ship.position.x = minimum_x
		flight_ship.velocity.x = maxf(flight_ship.velocity.x, 0.0)
	elif flight_ship.position.x > maximum_x:
		flight_ship.position.x = maximum_x
		flight_ship.velocity.x = minf(flight_ship.velocity.x, 0.0)


func _sync_camera() -> void:
	flight_camera.global_position = flight_ship.global_position


func _update_auto_retry(delta: float) -> void:
	if _auto_retry_remaining < 0.0:
		return
	_auto_retry_remaining = maxf(
		_auto_retry_remaining - maxf(delta, 0.0),
		0.0
	)
	if _auto_retry_remaining <= 0.0:
		restart_from_checkpoint(true)


func _connect_ship_signals() -> void:
	if not flight_ship.flight_failed.is_connected(_on_flight_failed):
		flight_ship.flight_failed.connect(_on_flight_failed)


func _on_flight_failed(_reason_key: StringName) -> void:
	_auto_retry_remaining = maxf(
		flight_ship.tuning.failure_retry_delay_seconds,
		0.1
	)


func _configure_ship_loadout() -> void:
	var state: GameStateModel = _resolve_game_state()
	if data_registry == null or state == null:
		flight_ship.configure_high_voltage_shielding(
			ShipLoadoutRules.create_default_configuration(),
			[]
		)
		return
	flight_ship.configure_high_voltage_shielding(
		state.ship_configuration,
		data_registry.modules
	)
	flight_ship.set_shield_backup_power_enabled(
		ShipLoadoutRules.has_capability(
			state.ship_configuration,
			data_registry.modules,
			ShipLoadoutRules.SHIELD_REGENERATION_CAPABILITY
		)
	)
	flight_ship.set_laser_enabled(
		FlightWeaponRules.has_asteroid_laser(
			state.ship_configuration,
			data_registry.modules
		)
	)


func _resolve_game_state() -> GameStateModel:
	if game_state_override != null:
		return game_state_override
	return get_node_or_null("/root/GameState") as GameStateModel


func _resolve_settings_service() -> SettingsServiceModel:
	if settings_service_override != null:
		return settings_service_override
	return get_node_or_null("/root/SettingsService") as SettingsServiceModel


func _validate_configuration() -> bool:
	if (
		route_definition == null
		or planet_definition == null
		or flight_ship == null
		or flight_camera == null
		or route_hud == null
		or route_visuals == null
		or storm_controller == null
		or environment_feedback == null
		or storm_controller.profile == null
	):
		push_error("White Noise route configuration is incomplete.")
		return false
	var errors: PackedStringArray = route_definition.validate()
	var authoritative_gravity: float = (
		BASE_PLANET_GRAVITY * planet_definition.gravity_scale
	)
	for segment: FlightRouteSegment in route_definition.segments:
		if (
			segment != null
			and segment.environment_profile != null
			and segment.environment_profile.planet_gravity > 0.0
			and not is_equal_approx(
				segment.environment_profile.planet_gravity,
				authoritative_gravity
			)
		):
			errors.append(
				"White Noise environment '%s' does not match planet gravity %.1f."
				% [segment.environment_profile.id, authoritative_gravity]
			)
	var storm_errors: PackedStringArray = storm_controller.profile.validate()
	errors.append_array(storm_errors)
	var storm_segment: FlightRouteSegment = route_definition.get_segment(
		storm_controller.profile.trigger_distance
	)
	if (
		storm_segment == null
		or storm_segment.id != &"white_noise_aurora_blizzard"
		or not is_equal_approx(
			storm_segment.start_distance,
			storm_controller.profile.trigger_distance
		)
		or not is_equal_approx(
			storm_segment.end_distance,
			storm_controller.profile.end_distance
		)
	):
		errors.append(
			"White Noise storm profile must match the aurora route window."
		)
	if not errors.is_empty():
		push_error("White Noise route rejected: %s" % "; ".join(errors))
		return false
	return true
