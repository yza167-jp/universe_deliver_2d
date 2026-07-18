class_name FlightLab
extends Node2D

const RESTART_ACTION: StringName = &"flight_restart"
const HUD_TOGGLE_ACTION: StringName = &"flight_debug_toggle"
const ENVIRONMENT_CYCLE_ACTION: StringName = &"flight_environment_cycle"
const ASSIST_CYCLE_ACTION: StringName = &"flight_assist_cycle"
const ASSIST_PRESETS: Array[float] = [0.0, 0.75, 1.0]

@onready var flight_ship: FlightLabShip = %FlightShip
@onready var flight_camera: Camera2D = %FlightCamera
@onready var debug_hud: FlightDebugHUD = %FlightDebugHUD
@onready var atmosphere_tint: ColorRect = %AtmosphereTint

@export var environment_profiles: Array[FlightEnvironmentProfile] = []

var settings_service_override: SettingsServiceModel
var _active_environment_index: int = 0
var _active_assist_index: int = 1
var _active_assist_strength: float = FlightLabShip.DEFAULT_ASSIST_STRENGTH


func _ready() -> void:
	_active_assist_strength = _resolve_assist_strength()
	_active_assist_index = _find_nearest_assist_index(_active_assist_strength)
	_active_environment_index = _find_environment_index(flight_ship.environment_profile)
	debug_hud.bind_ship(flight_ship)
	reset_lab()


func _process(_delta: float) -> void:
	_sync_camera_to_ship()
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
	if event.is_action_pressed(RESTART_ACTION):
		reset_lab()
		get_viewport().set_input_as_handled()


func reset_lab() -> bool:
	if flight_ship == null or flight_camera == null or debug_hud == null:
		return false
	flight_ship.reset_to_start(
		_active_assist_strength,
		get_active_environment_profile(),
		true
	)
	_sync_camera_to_ship()
	_update_environment_visuals()
	debug_hud.refresh()
	debug_hud.show_reset_feedback()
	return true


func cycle_environment_profile() -> bool:
	if environment_profiles.is_empty() or flight_ship == null:
		return false
	_active_environment_index = (
		_active_environment_index + 1
	) % environment_profiles.size()
	var profile: FlightEnvironmentProfile = get_active_environment_profile()
	flight_ship.set_environment_profile(profile, false)
	debug_hud.show_environment_feedback(profile.display_name_key)
	return true


func cycle_assist_preset() -> float:
	_active_assist_index = (_active_assist_index + 1) % ASSIST_PRESETS.size()
	_active_assist_strength = ASSIST_PRESETS[_active_assist_index]
	if flight_ship != null:
		flight_ship.set_assist_strength(_active_assist_strength)
	if debug_hud != null:
		debug_hud.show_assist_feedback(_active_assist_strength)
	return _active_assist_strength


func toggle_debug_hud() -> bool:
	if debug_hud == null:
		return false
	debug_hud.visible = not debug_hud.visible
	return debug_hud.visible


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


func _sync_camera_to_ship() -> void:
	if flight_ship == null or flight_camera == null:
		return
	flight_camera.position = Vector2(
		roundf(flight_ship.position.x),
		roundf(flight_ship.position.y)
	)


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
