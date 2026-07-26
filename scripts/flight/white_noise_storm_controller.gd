class_name WhiteNoiseStormController
extends Control

## Scene-local White Noise hazard coordinator and bounded screen-space feedback.

signal storm_state_changed(state_name: StringName)
signal high_voltage_pulse_resolved(result: FlightDamageResult)

const HIGH_VOLTAGE_REASON_KEY: StringName = (
	&"UI_WHITE_NOISE_HIGH_VOLTAGE_FAILURE"
)
const PULSE_FLASH_SECONDS: float = 0.22

@export var profile: WhiteNoiseStormProfile

var _flight: WhiteNoiseFlight
var _ship: FlightLabShip
var _hud: WhiteNoiseRouteHUD
var _visuals: WhiteNoiseRouteVisuals
var _settings_service: SettingsServiceModel
var _model: WhiteNoiseInterferenceModel = WhiteNoiseInterferenceModel.new()
var _last_state: WhiteNoiseInterferenceModel.State = (
	WhiteNoiseInterferenceModel.State.CLEAR
)
var _last_pulse_result: FlightDamageResult = FlightDamageResult.new()
var _visual_elapsed_seconds: float = 0.0
var _pulse_flash_remaining: float = 0.0
var _slow_motion_active: bool = false
var _previous_time_scale: float = 1.0
var _route_hints_enabled: bool = LocalSettingsData.DEFAULT_ROUTE_HINTS_ENABLED
var _high_contrast_enabled: bool = LocalSettingsData.DEFAULT_HIGH_CONTRAST_TERRAIN


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_cancel_slow_motion()
		_disconnect_settings_service()


func _draw() -> void:
	if profile == null or _model.get_state() == WhiteNoiseInterferenceModel.State.CLEAR:
		return
	var effective_interference: float = get_effective_interference()
	var visibility: float = get_visibility_intensity()
	if visibility <= 0.001:
		return
	var overlay_alpha: float = lerpf(0.035, 0.21, visibility)
	if _high_contrast_enabled:
		overlay_alpha *= 0.68
	draw_rect(
		Rect2(Vector2.ZERO, size),
		Color(0.035, 0.12, 0.2, overlay_alpha),
		true
	)

	var line_count: int = get_feedback_line_count()
	var drift: float = _visual_elapsed_seconds * lerpf(
		70.0,
		180.0,
		effective_interference
	)
	for index: int in line_count:
		var x: float = fposmod(float(index * 47) + drift, size.x + 96.0) - 48.0
		var y: float = float((index * 71) % 348) + 6.0
		var length: float = 16.0 + float((index * 13) % 34)
		draw_line(
			Vector2(x, y),
			Vector2(x - length, y + length * 0.34),
			Color(0.76, 0.96, 1.0, 0.08 + visibility * 0.18),
			1.0 if index % 3 else 2.0
		)
	for scanline_y: int in range(8, roundi(size.y), 14):
		draw_line(
			Vector2(0.0, float(scanline_y)),
			Vector2(size.x, float(scanline_y)),
			Color(0.26, 0.88, 0.9, 0.015 + visibility * 0.025),
			1.0
		)

	var border_color := Color(0.3, 0.95, 0.9, 0.36)
	if _model.get_state() == WhiteNoiseInterferenceModel.State.WARNING:
		border_color = Color(1.0, 0.76, 0.26, 0.62)
	elif _model.get_state() == WhiteNoiseInterferenceModel.State.ACTIVE:
		border_color = Color(0.42, 0.92, 1.0, 0.42 + visibility * 0.22)
	draw_rect(
		Rect2(Vector2(3.0, 3.0), size - Vector2(6.0, 6.0)),
		border_color,
		false,
		2.0
	)
	if _pulse_flash_remaining > 0.0:
		var flash_progress: float = clampf(
			_pulse_flash_remaining / PULSE_FLASH_SECONDS,
			0.0,
			1.0
		)
		draw_rect(
			Rect2(Vector2.ZERO, size),
			Color(
				0.5,
				0.95,
				1.0,
				flash_progress * 0.24 * get_pulse_flash_alpha_scale()
			),
			true
		)


func bind(
	flight: WhiteNoiseFlight,
	ship: FlightLabShip,
	hud: WhiteNoiseRouteHUD,
	visuals: WhiteNoiseRouteVisuals,
	settings_service: SettingsServiceModel = null
) -> bool:
	_flight = flight
	_ship = ship
	_hud = hud
	_visuals = visuals
	_bind_settings_service(settings_service)
	if profile == null:
		push_error("White Noise storm profile is missing.")
		return false
	var validation_errors: PackedStringArray = profile.validate()
	if not validation_errors.is_empty():
		push_error(
			"White Noise storm profile rejected: %s"
			% "; ".join(validation_errors)
		)
		return false
	if not _model.configure(profile):
		push_error("White Noise interference model could not configure.")
		return false
	reset_for_route(0.0)
	return true


func advance(delta: float, route_distance: float) -> int:
	if profile == null or _ship == null or _ship.is_failed:
		return 0
	var previous_state: WhiteNoiseInterferenceModel.State = _model.get_state()
	var emitted_pulses: int = _model.step(delta, route_distance)
	_visual_elapsed_seconds += maxf(delta, 0.0)
	_pulse_flash_remaining = maxf(
		_pulse_flash_remaining - maxf(delta, 0.0),
		0.0
	)
	if _model.get_state() != previous_state:
		_handle_state_changed(previous_state)
	for _pulse_index: int in emitted_pulses:
		_apply_high_voltage_pulse()
	_sync_feedback()
	queue_redraw()
	return emitted_pulses


func reset_for_route(route_distance: float) -> void:
	_cancel_slow_motion()
	_model.reset(route_distance)
	_last_state = _model.get_state()
	_last_pulse_result = FlightDamageResult.new()
	_visual_elapsed_seconds = 0.0
	_pulse_flash_remaining = 0.0
	if _last_state == WhiteNoiseInterferenceModel.State.WARNING:
		_activate_slow_motion_if_enabled()
		if _hud != null:
			_hud.show_storm_warning()
	_sync_accessibility()
	_sync_feedback()
	queue_redraw()


func debug_set_state(
	state: WhiteNoiseInterferenceModel.State,
	elapsed_seconds: float = 0.0
) -> bool:
	if not OS.is_debug_build():
		return false
	var previous_state: WhiteNoiseInterferenceModel.State = _model.get_state()
	_model.debug_set_state(state, elapsed_seconds)
	_handle_state_changed(previous_state)
	_sync_feedback()
	queue_redraw()
	return true


func refresh_accessibility() -> void:
	_sync_accessibility()
	_sync_feedback()
	queue_redraw()


func get_state() -> WhiteNoiseInterferenceModel.State:
	return _model.get_state()


func get_state_name() -> StringName:
	return _model.get_state_name()


func get_state_progress() -> float:
	return _model.get_state_progress()


func get_effective_interference() -> float:
	var multiplier: float = (
		1.0
		if _ship == null
		else _ship.get_electromagnetic_interference_multiplier()
	)
	return _model.get_effective_interference(multiplier)


func get_visibility_intensity() -> float:
	if profile == null or profile.interference_intensity <= 0.0:
		return 0.0
	var normalized_interference: float = clampf(
		get_effective_interference() / profile.interference_intensity,
		0.0,
		1.0
	)
	return profile.visibility_intensity * normalized_interference


func get_feedback_line_count() -> int:
	var line_count: int = 18 + roundi(get_visibility_intensity() * 18.0)
	if _high_contrast_enabled:
		line_count = maxi(roundi(float(line_count) * 0.56), 10)
	return line_count


func get_pulse_flash_alpha_scale() -> float:
	return 0.42 if _high_contrast_enabled else 1.0


func get_total_pulse_count() -> int:
	return _model.get_total_pulse_count()


func get_last_pulse_result() -> FlightDamageResult:
	return _last_pulse_result


func get_profile() -> WhiteNoiseStormProfile:
	return profile


func is_active() -> bool:
	return _model.get_state() != WhiteNoiseInterferenceModel.State.CLEAR


func is_slow_motion_active() -> bool:
	return _slow_motion_active


func _apply_high_voltage_pulse() -> void:
	if _ship == null or _ship.is_failed:
		return
	if not _ship.apply_high_voltage_damage(
		profile.high_voltage_damage,
		profile.cargo_damage,
		HIGH_VOLTAGE_REASON_KEY
	):
		return
	_last_pulse_result = _ship.get_last_damage_result()
	_pulse_flash_remaining = PULSE_FLASH_SECONDS
	if _hud != null:
		_hud.show_high_voltage_pulse(_last_pulse_result)
	high_voltage_pulse_resolved.emit(_last_pulse_result)


func _handle_state_changed(
	_previous_state: WhiteNoiseInterferenceModel.State
) -> void:
	_last_state = _model.get_state()
	match _last_state:
		WhiteNoiseInterferenceModel.State.WARNING:
			_activate_slow_motion_if_enabled()
			if _hud != null:
				_hud.show_storm_warning()
		WhiteNoiseInterferenceModel.State.ACTIVE:
			_cancel_slow_motion()
			if _hud != null:
				_hud.show_storm_active()
		WhiteNoiseInterferenceModel.State.RECOVERY:
			_cancel_slow_motion()
			if _hud != null:
				_hud.show_storm_recovery()
		WhiteNoiseInterferenceModel.State.CLEAR:
			_cancel_slow_motion()
			if _hud != null:
				_hud.show_signal_recovered()
	storm_state_changed.emit(_model.get_state_name())


func _sync_feedback() -> void:
	_sync_accessibility()
	var shielding_enabled: bool = (
		_ship != null and _ship.is_high_voltage_shielding_enabled()
	)
	if _hud != null:
		_hud.set_storm_telemetry(
			_model.get_state_name(),
			_model.get_state_progress(),
			get_effective_interference(),
			shielding_enabled,
			_route_hints_enabled,
			profile.noncritical_hud_update_seconds if profile != null else 0.34
		)
	if _visuals != null:
		_visuals.set_accessibility(
			_route_hints_enabled,
			_high_contrast_enabled
		)
		_visuals.set_storm_feedback(
			get_effective_interference(),
			_model.get_state_progress(),
			_model.get_state_name()
		)


func _sync_accessibility() -> void:
	_route_hints_enabled = LocalSettingsData.DEFAULT_ROUTE_HINTS_ENABLED
	_high_contrast_enabled = LocalSettingsData.DEFAULT_HIGH_CONTRAST_TERRAIN
	if _settings_service != null:
		_route_hints_enabled = _settings_service.settings.route_hints_enabled
		_high_contrast_enabled = _settings_service.settings.high_contrast_terrain


func _bind_settings_service(settings_service: SettingsServiceModel) -> void:
	_disconnect_settings_service()
	_settings_service = settings_service
	if _settings_service == null:
		_settings_service = get_node_or_null(
			"/root/SettingsService"
		) as SettingsServiceModel
	if (
		_settings_service != null
		and not _settings_service.assist_option_changed.is_connected(
			_on_assist_option_changed
		)
	):
		_settings_service.assist_option_changed.connect(_on_assist_option_changed)


func _disconnect_settings_service() -> void:
	if _settings_service == null:
		return
	if _settings_service.assist_option_changed.is_connected(
		_on_assist_option_changed
	):
		_settings_service.assist_option_changed.disconnect(
			_on_assist_option_changed
		)
	_settings_service = null


func _on_assist_option_changed(
	option_id: StringName,
	_enabled: bool
) -> void:
	if option_id == SettingsServiceModel.SLOW_MOTION_ASSIST:
		if _model.get_state() == WhiteNoiseInterferenceModel.State.WARNING:
			if _resolve_slow_motion_enabled():
				_activate_slow_motion_if_enabled()
			else:
				_cancel_slow_motion()
		return
	if option_id in [
		SettingsServiceModel.ROUTE_HINTS_ENABLED,
		SettingsServiceModel.HIGH_CONTRAST_TERRAIN,
	]:
		refresh_accessibility()


func _activate_slow_motion_if_enabled() -> void:
	if _slow_motion_active or not _resolve_slow_motion_enabled() or profile == null:
		return
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = _previous_time_scale * clampf(
		profile.slow_motion_time_scale,
		0.1,
		1.0
	)
	_slow_motion_active = true


func _cancel_slow_motion() -> void:
	if not _slow_motion_active:
		return
	Engine.time_scale = _previous_time_scale
	_slow_motion_active = false


func _resolve_slow_motion_enabled() -> bool:
	return (
		_settings_service != null
		and _settings_service.settings.slow_motion_assist
	)
