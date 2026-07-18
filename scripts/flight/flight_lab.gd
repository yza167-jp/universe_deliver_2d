class_name FlightLab
extends Node2D

const RESTART_ACTION: StringName = &"flight_restart"
const HUD_TOGGLE_ACTION: StringName = &"flight_debug_toggle"
const ENVIRONMENT_CYCLE_ACTION: StringName = &"flight_environment_cycle"
const ASSIST_CYCLE_ACTION: StringName = &"flight_assist_cycle"
const LASER_TOGGLE_ACTION: StringName = &"flight_laser_toggle"
const ASSIST_PRESETS: Array[float] = [0.0, 0.75, 1.0]
const LAB_CHECKPOINT_ID: StringName = &"checkpoint_flight_lab_start"
const NO_RETRY_PENDING: float = -1.0

@onready var flight_ship: FlightLabShip = %FlightShip
@onready var flight_camera: Camera2D = %FlightCamera
@onready var debug_hud: FlightDebugHUD = %FlightDebugHUD
@onready var atmosphere_tint: ColorRect = %AtmosphereTint
@onready var destructible_asteroids: Node2D = %DestructibleAsteroids

@export var environment_profiles: Array[FlightEnvironmentProfile] = []
@export var data_registry: GameDataRegistry

var settings_service_override: SettingsServiceModel
var _active_environment_index: int = 0
var _active_assist_index: int = 1
var _active_assist_strength: float = FlightLabShip.DEFAULT_ASSIST_STRENGTH
var _auto_retry_remaining: float = NO_RETRY_PENDING
var _camera_shake_remaining: float = 0.0
var _camera_shake_duration: float = 0.0
var _camera_shake_elapsed: float = 0.0
var _camera_shake_amplitude: float = 0.0


func _ready() -> void:
	_active_assist_strength = _resolve_assist_strength()
	_active_assist_index = _find_nearest_assist_index(_active_assist_strength)
	_active_environment_index = _find_environment_index(flight_ship.environment_profile)
	_connect_ship_signals()
	flight_ship.set_laser_enabled(_resolve_laser_enabled_from_loadout())
	debug_hud.bind_ship(flight_ship)
	reset_lab()


func _process(delta: float) -> void:
	_update_auto_retry(delta)
	_sync_camera_to_ship()
	_update_camera_shake(delta)
	_update_environment_visuals()
	debug_hud.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(HUD_TOGGLE_ACTION):
		toggle_debug_hud()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(ENVIRONMENT_CYCLE_ACTION):
		cycle_environment_profile()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(ASSIST_CYCLE_ACTION):
		cycle_assist_preset()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(LASER_TOGGLE_ACTION):
		toggle_debug_laser_loadout()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(RESTART_ACTION):
		restart_from_checkpoint(false)
		get_viewport().set_input_as_handled()


func reset_lab() -> bool:
	if flight_ship == null or flight_camera == null or debug_hud == null:
		return false
	if not flight_ship.configure_stable_checkpoint(
		LAB_CHECKPOINT_ID,
		_active_assist_strength,
		get_active_environment_profile()
	):
		return false
	return restart_from_checkpoint(false)


func restart_from_checkpoint(is_automatic: bool = false) -> bool:
	if flight_ship == null or flight_camera == null or debug_hud == null:
		return false
	if not flight_ship.restore_checkpoint():
		return false
	_reset_destructible_asteroids()
	_auto_retry_remaining = NO_RETRY_PENDING
	_clear_camera_shake()
	_sync_camera_to_ship()
	_update_environment_visuals()
	debug_hud.refresh()
	if is_automatic:
		debug_hud.show_auto_retry_feedback(flight_ship.get_checkpoint_id())
	else:
		debug_hud.show_reset_feedback(flight_ship.get_checkpoint_id())
	return true


func cycle_environment_profile() -> bool:
	if environment_profiles.is_empty() or flight_ship == null:
		return false
	_active_environment_index = (
		_active_environment_index + 1
	) % environment_profiles.size()
	var profile: FlightEnvironmentProfile = get_active_environment_profile()
	flight_ship.set_environment_profile(profile, false)
	_refresh_lab_checkpoint()
	debug_hud.show_environment_feedback(profile.display_name_key)
	return true


func cycle_assist_preset() -> float:
	_active_assist_index = (_active_assist_index + 1) % ASSIST_PRESETS.size()
	_active_assist_strength = ASSIST_PRESETS[_active_assist_index]
	if flight_ship != null:
		flight_ship.set_assist_strength(_active_assist_strength)
	_refresh_lab_checkpoint()
	if debug_hud != null:
		debug_hud.show_assist_feedback(_active_assist_strength)
	return _active_assist_strength


func toggle_debug_hud() -> bool:
	if debug_hud == null:
		return false
	debug_hud.visible = not debug_hud.visible
	return debug_hud.visible


func toggle_debug_laser_loadout() -> bool:
	if not OS.is_debug_build() or flight_ship == null:
		return false
	var enabled: bool = not flight_ship.is_laser_enabled()
	flight_ship.set_laser_enabled(enabled)
	if debug_hud != null:
		debug_hud.show_laser_loadout_feedback(enabled)
	return enabled


func get_flight_ship() -> FlightLabShip:
	return flight_ship


func get_flight_camera() -> Camera2D:
	return flight_camera


func get_debug_hud() -> FlightDebugHUD:
	return debug_hud


func get_active_environment_profile() -> FlightEnvironmentProfile:
	if environment_profiles.is_empty():
		return null if flight_ship == null else flight_ship.environment_profile
	return environment_profiles[clampi(
		_active_environment_index,
		0,
		environment_profiles.size() - 1
	)]


func get_active_assist_strength() -> float:
	return _active_assist_strength


func is_retry_pending() -> bool:
	return _auto_retry_remaining >= 0.0


func _sync_camera_to_ship() -> void:
	if flight_ship == null or flight_camera == null:
		return
	flight_camera.position = Vector2(
		roundf(flight_ship.position.x),
		roundf(flight_ship.position.y)
	)


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
	flight_camera.offset = Vector2(
		sin(phase),
		cos(phase * 1.37)
	) * _camera_shake_amplitude * fade * _resolve_screen_shake_strength()


func _update_environment_visuals() -> void:
	if atmosphere_tint == null or flight_ship == null:
		return
	var tint_color: Color = atmosphere_tint.color
	tint_color.a = lerpf(0.0, 0.34, flight_ship.air_density)
	atmosphere_tint.color = tint_color


func _resolve_assist_strength() -> float:
	var settings_service: SettingsServiceModel = settings_service_override
	if settings_service == null:
		settings_service = get_node_or_null("/root/SettingsService") as SettingsServiceModel
	if settings_service == null:
		return FlightLabShip.DEFAULT_ASSIST_STRENGTH
	return settings_service.settings.flight_assist_strength


func _resolve_screen_shake_strength() -> float:
	var settings_service: SettingsServiceModel = settings_service_override
	if settings_service == null:
		settings_service = get_node_or_null("/root/SettingsService") as SettingsServiceModel
	if settings_service == null:
		return LocalSettingsData.DEFAULT_SCREEN_SHAKE_STRENGTH
	return clampf(settings_service.settings.screen_shake_strength, 0.0, 1.0)


func _find_nearest_assist_index(requested_strength: float) -> int:
	var nearest_index: int = 0
	var nearest_distance: float = INF
	for index: int in ASSIST_PRESETS.size():
		var distance: float = absf(ASSIST_PRESETS[index] - requested_strength)
		if distance < nearest_distance:
			nearest_index = index
			nearest_distance = distance
	return nearest_index


func _find_environment_index(profile: FlightEnvironmentProfile) -> int:
	if profile == null:
		return 0
	for index: int in environment_profiles.size():
		var candidate: FlightEnvironmentProfile = environment_profiles[index]
		if candidate == profile or (
			candidate != null and candidate.id == profile.id
		):
			return index
	return 0


func _connect_ship_signals() -> void:
	if flight_ship == null:
		return
	if not flight_ship.impact_resolved.is_connected(_on_impact_resolved):
		flight_ship.impact_resolved.connect(_on_impact_resolved)
	if not flight_ship.flight_failed.is_connected(_on_flight_failed):
		flight_ship.flight_failed.connect(_on_flight_failed)
	if not flight_ship.company_warning_requested.is_connected(
		_on_company_warning_requested
	):
		flight_ship.company_warning_requested.connect(_on_company_warning_requested)
	if not flight_ship.laser_fired.is_connected(_on_laser_fired):
		flight_ship.laser_fired.connect(_on_laser_fired)
	if not flight_ship.laser_fire_rejected.is_connected(_on_laser_fire_rejected):
		flight_ship.laser_fire_rejected.connect(_on_laser_fire_rejected)
	if not flight_ship.laser_target_hit.is_connected(_on_laser_target_hit):
		flight_ship.laser_target_hit.connect(_on_laser_target_hit)


func _refresh_lab_checkpoint() -> void:
	if flight_ship == null:
		return
	flight_ship.configure_stable_checkpoint(
		LAB_CHECKPOINT_ID,
		_active_assist_strength,
		get_active_environment_profile()
	)


func _on_impact_resolved(severity: int, impact_speed: float) -> void:
	if debug_hud != null:
		debug_hud.show_impact_feedback(severity, impact_speed)
	_start_camera_shake(severity)


func _on_flight_failed(reason_key: StringName) -> void:
	var retry_delay: float = 0.0
	if flight_ship != null and flight_ship.tuning != null:
		retry_delay = maxf(flight_ship.tuning.failure_retry_delay_seconds, 0.0)
	_auto_retry_remaining = retry_delay
	if debug_hud != null:
		debug_hud.show_failure_feedback(reason_key, retry_delay)


func _on_company_warning_requested(
	warning_key: StringName,
	cargo_integrity: float
) -> void:
	if debug_hud != null:
		debug_hud.show_company_warning(warning_key, cargo_integrity)


func _on_laser_fired(hit_target: bool) -> void:
	if not hit_target and debug_hud != null:
		debug_hud.show_laser_miss_feedback()


func _on_laser_fire_rejected(reason_key: StringName) -> void:
	if debug_hud != null:
		debug_hud.show_laser_rejected_feedback(reason_key)


func _on_laser_target_hit(
	_target_id: StringName,
	remaining_durability: int,
	target_destroyed: bool
) -> void:
	if debug_hud != null:
		debug_hud.show_laser_hit_feedback(remaining_durability, target_destroyed)


func _update_auto_retry(delta: float) -> void:
	if _auto_retry_remaining < 0.0:
		return
	_auto_retry_remaining = maxf(
		_auto_retry_remaining - maxf(delta, 0.0),
		0.0
	)
	if _auto_retry_remaining <= 0.0:
		restart_from_checkpoint(true)


func _start_camera_shake(severity: int) -> void:
	if flight_ship == null or flight_ship.tuning == null:
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


func _clear_camera_shake() -> void:
	_camera_shake_remaining = 0.0
	_camera_shake_duration = 0.0
	_camera_shake_elapsed = 0.0
	_camera_shake_amplitude = 0.0
	if flight_camera != null:
		flight_camera.offset = Vector2.ZERO


func _resolve_laser_enabled_from_loadout() -> bool:
	if data_registry == null:
		return false
	var game_state: GameStateModel = get_node_or_null("/root/GameState") as GameStateModel
	if game_state == null:
		return false
	return FlightWeaponRules.has_asteroid_laser(
		game_state.ship_configuration,
		data_registry.modules
	)


func _reset_destructible_asteroids() -> void:
	if destructible_asteroids == null:
		return
	for child: Node in destructible_asteroids.get_children():
		if child is DestructibleAsteroid:
			(child as DestructibleAsteroid).reset_asteroid()
