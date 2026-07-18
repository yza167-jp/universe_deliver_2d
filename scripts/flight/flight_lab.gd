class_name FlightLab
extends Node2D

const RESTART_ACTION: StringName = &"flight_restart"
const HUD_TOGGLE_ACTION: StringName = &"flight_debug_toggle"

@onready var flight_ship: FlightLabShip = %FlightShip
@onready var flight_camera: Camera2D = %FlightCamera
@onready var debug_hud: FlightDebugHUD = %FlightDebugHUD

var settings_service_override: SettingsServiceModel


func _ready() -> void:
	debug_hud.bind_ship(flight_ship)
	reset_lab()


func _process(_delta: float) -> void:
	_sync_camera_to_ship()
	debug_hud.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(HUD_TOGGLE_ACTION):
		toggle_debug_hud()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(RESTART_ACTION):
		reset_lab()
		get_viewport().set_input_as_handled()


func reset_lab() -> bool:
	if flight_ship == null or flight_camera == null or debug_hud == null:
		return false
	flight_ship.reset_to_start(_resolve_assist_strength())
	_sync_camera_to_ship()
	debug_hud.refresh()
	debug_hud.show_reset_feedback()
	return true


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


func _sync_camera_to_ship() -> void:
	if flight_ship == null or flight_camera == null:
		return
	flight_camera.position = Vector2(
		roundf(flight_ship.position.x),
		roundf(flight_ship.position.y)
	)


func _resolve_assist_strength() -> float:
	var settings_service: SettingsServiceModel = settings_service_override
	if settings_service == null:
		settings_service = get_node_or_null("/root/SettingsService") as SettingsServiceModel
	if settings_service == null:
		return FlightLabShip.DEFAULT_ASSIST_STRENGTH
	return settings_service.settings.flight_assist_strength
