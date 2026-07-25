class_name DeliveryLab
extends Node2D

signal delivery_result_ready(result: LowAltitudeDropResult)

const DROP_ACTION: StringName = &"delivery_drop"
const RESTART_ACTION: StringName = &"flight_restart"
const LAB_CHECKPOINT_ID: StringName = &"checkpoint_delivery_lab_start"
const DEFAULT_ASSIST_STRENGTH: float = 0.75
const FEEDBACK_DURATION_SECONDS: float = 2.4

const COLOR_READY: Color = Color(0.40, 0.94, 0.72, 1.0)
const COLOR_WARNING: Color = Color(1.0, 0.72, 0.30, 1.0)
const COLOR_FAILURE: Color = Color(1.0, 0.38, 0.36, 1.0)
const COLOR_NEUTRAL: Color = Color(0.78, 0.88, 0.88, 1.0)
const COLOR_CORE_ZONE: Color = Color(0.28, 0.93, 0.62, 0.70)
const COLOR_OUTER_ZONE: Color = Color(0.95, 0.74, 0.27, 0.42)

@export var drop_profile: LowAltitudeDropProfile
@export var environment_profile: FlightEnvironmentProfile
@export var target_center_x: float = 1450.0
@export var surface_y: float = 264.0
@export var checkpoint_position: Vector2 = Vector2(300.0, 84.0)
@export var checkpoint_velocity: Vector2 = Vector2(120.0, 0.0)

@onready var flight_ship: FlightLabShip = %FlightShip
@onready var flight_camera: Camera2D = %FlightCamera
@onready var cargo_marker: Polygon2D = %CargoMarker
@onready var prediction_marker: Polygon2D = %PredictionMarker
@onready var prediction_line: Line2D = %PredictionLine
@onready var core_zone: Polygon2D = %CoreZone
@onready var outer_zone: Polygon2D = %OuterZone
@onready var core_left_guide: Line2D = %CoreLeftGuide
@onready var core_right_guide: Line2D = %CoreRightGuide
@onready var outer_left_guide: Line2D = %OuterLeftGuide
@onready var outer_right_guide: Line2D = %OuterRightGuide
@onready var target_beacon: Line2D = %TargetBeacon
@onready var target_label: Label = %TargetLabel
@onready var title_label: Label = %TitleLabel
@onready var window_label: Label = %WindowLabel
@onready var zone_label: Label = %ZoneLabel
@onready var altitude_label: Label = %AltitudeLabel
@onready var speed_label: Label = %SpeedLabel
@onready var prediction_label: Label = %PredictionLabel
@onready var cargo_label: Label = %CargoLabel
@onready var result_label: Label = %ResultLabel
@onready var controls_label: Label = %ControlsLabel

var _drop_model: LowAltitudeDropModel = LowAltitudeDropModel.new()
var _active_drop_result: LowAltitudeDropResult
var _cargo_in_flight: bool = false
var _cargo_fall_elapsed: float = 0.0
var _result_settled: bool = false
var _feedback_reason_key: StringName = &""
var _feedback_remaining: float = 0.0


func _ready() -> void:
	if not _validate_dependencies():
		return
	_configure_static_visuals()
	flight_ship.stable_start_position = checkpoint_position
	flight_ship.reset_to_start(
		DEFAULT_ASSIST_STRENGTH,
		environment_profile,
		true
	)
	flight_ship.position = checkpoint_position
	flight_ship.velocity = checkpoint_velocity
	flight_ship.set_laser_enabled(false)
	if not flight_ship.capture_checkpoint(LAB_CHECKPOINT_ID):
		push_error("Delivery Lab could not capture its stable checkpoint.")
		return
	restart_from_checkpoint(false)


func _process(delta: float) -> void:
	_update_camera()
	_update_feedback_timer(delta)
	_update_cargo_fall(delta)
	_update_prediction_visual()
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(DROP_ACTION):
		request_drop()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(RESTART_ACTION):
		restart_from_checkpoint()
		get_viewport().set_input_as_handled()


func request_drop() -> LowAltitudeDropResult:
	if flight_ship == null or drop_profile == null:
		return null
	var result: LowAltitudeDropResult = _drop_model.try_release(
		drop_profile,
		flight_ship.global_position,
		target_center_x,
		get_current_altitude(),
		get_current_horizontal_speed()
	)
	if result.status == LowAltitudeDropModel.Status.INVALID_RELEASE:
		_feedback_reason_key = result.reason_key
		_feedback_remaining = FEEDBACK_DURATION_SECONDS
		_refresh_hud()
		return result

	_active_drop_result = result
	_cargo_in_flight = true
	_cargo_fall_elapsed = 0.0
	_result_settled = false
	_feedback_reason_key = &""
	_feedback_remaining = 0.0
	cargo_marker.global_position = result.release_position
	cargo_marker.visible = true
	prediction_marker.visible = false
	prediction_line.visible = true
	_refresh_hud()
	return result


func restart_from_checkpoint(show_feedback: bool = true) -> bool:
	if flight_ship == null or not flight_ship.restore_checkpoint():
		return false
	_drop_model.reset()
	_active_drop_result = null
	_cargo_in_flight = false
	_cargo_fall_elapsed = 0.0
	_result_settled = false
	cargo_marker.visible = false
	prediction_marker.visible = true
	prediction_line.visible = true
	_reset_zone_colors()
	if show_feedback:
		_feedback_reason_key = &"UI_DELIVERY_LAB_RETRY_RESTORED"
		_feedback_remaining = FEEDBACK_DURATION_SECONDS
	else:
		_feedback_reason_key = &""
		_feedback_remaining = 0.0
	_update_camera()
	_update_prediction_visual()
	_refresh_hud()
	return true


func get_current_altitude() -> float:
	if flight_ship == null:
		return 0.0
	return maxf(surface_y - flight_ship.global_position.y, 0.0)


func get_current_horizontal_speed() -> float:
	return 0.0 if flight_ship == null else flight_ship.velocity.x


func get_predicted_landing_x() -> float:
	if flight_ship == null or drop_profile == null:
		return target_center_x
	if _active_drop_result != null:
		return _active_drop_result.predicted_landing_x
	return _drop_model.predict_landing_x(
		drop_profile,
		flight_ship.global_position.x,
		get_current_altitude(),
		get_current_horizontal_speed()
	)


func get_drop_profile() -> LowAltitudeDropProfile:
	return drop_profile


func get_drop_model() -> LowAltitudeDropModel:
	return _drop_model


func get_flight_ship() -> FlightLabShip:
	return flight_ship


func get_settled_result() -> LowAltitudeDropResult:
	return _drop_model.get_settled_result()


func is_cargo_available() -> bool:
	return not _drop_model.has_released_cargo()


func is_cargo_in_flight() -> bool:
	return _cargo_in_flight


func is_result_settled() -> bool:
	return _result_settled


func get_result_text() -> String:
	return "" if result_label == null else result_label.text


func get_telemetry_text() -> String:
	if altitude_label == null or speed_label == null or prediction_label == null:
		return ""
	return "\n".join([altitude_label.text, speed_label.text, prediction_label.text])


func get_hud_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for node_name: StringName in [
		&"WindowPanel",
		&"TelemetryPanel",
		&"ResultPanel",
	]:
		var control: Control = get_node_or_null("HUD/%s" % node_name) as Control
		if control != null:
			rects.append(control.get_global_rect())
	return rects


func debug_set_ship_state(
	release_x: float,
	release_altitude: float,
	horizontal_speed: float
) -> void:
	if flight_ship == null:
		return
	flight_ship.global_position = Vector2(
		release_x,
		surface_y - maxf(release_altitude, 0.0)
	)
	flight_ship.velocity = Vector2(horizontal_speed, 0.0)
	flight_ship.rotation = 0.0
	flight_ship.angular_velocity = 0.0
	_update_camera()
	_update_prediction_visual()
	_refresh_hud()


func debug_complete_cargo_fall() -> void:
	if not _cargo_in_flight or _active_drop_result == null:
		return
	_update_cargo_fall(_active_drop_result.fall_duration + 0.01)
	_refresh_hud()


func _validate_dependencies() -> bool:
	if flight_ship == null or flight_camera == null or cargo_marker == null:
		push_error("Delivery Lab is missing its ship, camera, or cargo marker.")
		return false
	if drop_profile == null:
		push_error("Delivery Lab requires a LowAltitudeDropProfile.")
		return false
	var profile_errors: PackedStringArray = drop_profile.validate()
	if not profile_errors.is_empty():
		push_error(
			"Delivery Lab profile is invalid: %s"
			% "; ".join(profile_errors)
		)
		return false
	if environment_profile == null:
		push_error("Delivery Lab requires a flight environment profile.")
		return false
	return true


func _configure_static_visuals() -> void:
	title_label.text = tr("UI_DELIVERY_LAB_TITLE")
	window_label.text = tr("UI_DELIVERY_LAB_WINDOW_FORMAT") % [
		roundi(drop_profile.minimum_release_altitude),
		roundi(drop_profile.maximum_release_altitude),
		roundi(drop_profile.minimum_release_speed),
		roundi(drop_profile.maximum_release_speed),
	]
	zone_label.text = tr("UI_DELIVERY_LAB_ZONE_FORMAT") % [
		roundi(drop_profile.core_zone_half_width),
		roundi(drop_profile.outer_zone_half_width),
	]
	controls_label.text = tr("UI_DELIVERY_LAB_CONTROLS")
	target_label.text = tr("UI_DELIVERY_LAB_TARGET_LABEL")
	target_label.position = Vector2(target_center_x - 72.0, surface_y - 68.0)
	target_beacon.position = Vector2(target_center_x, surface_y)

	outer_zone.polygon = _make_zone_polygon(drop_profile.outer_zone_half_width, 18.0)
	outer_zone.position = Vector2(target_center_x, surface_y)
	core_zone.polygon = _make_zone_polygon(drop_profile.core_zone_half_width, 12.0)
	core_zone.position = Vector2(target_center_x, surface_y)
	_configure_zone_guide(
		core_left_guide,
		target_center_x - drop_profile.core_zone_half_width,
		44.0
	)
	_configure_zone_guide(
		core_right_guide,
		target_center_x + drop_profile.core_zone_half_width,
		44.0
	)
	_configure_zone_guide(
		outer_left_guide,
		target_center_x - drop_profile.outer_zone_half_width,
		28.0
	)
	_configure_zone_guide(
		outer_right_guide,
		target_center_x + drop_profile.outer_zone_half_width,
		28.0
	)
	_reset_zone_colors()


func _make_zone_polygon(half_width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half_width, -height),
		Vector2(half_width, -height),
		Vector2(half_width, 0.0),
		Vector2(-half_width, 0.0),
	])


func _configure_zone_guide(
	guide: Line2D,
	world_x: float,
	height: float
) -> void:
	if guide == null:
		return
	guide.points = PackedVector2Array([
		Vector2(world_x, surface_y),
		Vector2(world_x, surface_y - height),
	])


func _update_camera() -> void:
	if flight_camera == null or flight_ship == null:
		return
	flight_camera.position = Vector2(
		roundf(flight_ship.global_position.x),
		180.0
	)


func _update_feedback_timer(delta: float) -> void:
	if _feedback_remaining <= 0.0:
		return
	_feedback_remaining = maxf(_feedback_remaining - maxf(delta, 0.0), 0.0)
	if _feedback_remaining <= 0.0:
		_feedback_reason_key = &""


func _update_cargo_fall(delta: float) -> void:
	if not _cargo_in_flight or _active_drop_result == null:
		return
	_cargo_fall_elapsed += maxf(delta, 0.0)
	var duration: float = maxf(_active_drop_result.fall_duration, 0.001)
	var progress: float = clampf(_cargo_fall_elapsed / duration, 0.0, 1.0)
	cargo_marker.global_position = _active_drop_result.release_position.lerp(
		Vector2(_active_drop_result.predicted_landing_x, surface_y - 5.0),
		progress
	)
	cargo_marker.rotation = progress * TAU
	prediction_line.points = PackedVector2Array([
		_active_drop_result.release_position,
		Vector2(_active_drop_result.predicted_landing_x, surface_y - 5.0),
	])
	if progress < 1.0:
		return
	_cargo_in_flight = false
	_result_settled = true
	_feedback_reason_key = &""
	_feedback_remaining = 0.0
	cargo_marker.rotation = 0.0
	_apply_result_zone_color(_active_drop_result.status)
	delivery_result_ready.emit(_active_drop_result)


func _update_prediction_visual() -> void:
	if flight_ship == null or drop_profile == null:
		return
	if _cargo_in_flight or _result_settled:
		return
	var predicted_x: float = get_predicted_landing_x()
	prediction_marker.global_position = Vector2(predicted_x, surface_y - 7.0)
	prediction_marker.visible = not _drop_model.has_released_cargo()
	prediction_line.visible = not _drop_model.has_released_cargo()
	prediction_line.points = PackedVector2Array([
		flight_ship.global_position,
		Vector2(predicted_x, surface_y - 7.0),
	])
	var release_window_valid: bool = _is_release_window_valid()
	prediction_marker.color = _get_prediction_color(
		predicted_x,
		release_window_valid
	)
	prediction_line.default_color = Color(
		prediction_marker.color.r,
		prediction_marker.color.g,
		prediction_marker.color.b,
		0.42
	)


func _refresh_hud() -> void:
	if drop_profile == null or flight_ship == null or result_label == null:
		return
	var altitude: float = get_current_altitude()
	var speed: float = get_current_horizontal_speed()
	var predicted_offset: float = get_predicted_landing_x() - target_center_x
	altitude_label.text = tr("UI_DELIVERY_LAB_ALTITUDE_FORMAT") % [
		roundi(altitude),
		tr(_get_altitude_state_key(altitude)),
	]
	speed_label.text = tr("UI_DELIVERY_LAB_SPEED_FORMAT") % [
		roundi(speed),
		tr(_get_speed_state_key(speed)),
	]
	prediction_label.text = tr("UI_DELIVERY_LAB_PREDICTION_FORMAT") % roundi(
		predicted_offset
	)
	cargo_label.text = tr(_get_cargo_state_key())
	result_label.text = _get_result_message()
	result_label.modulate = _get_result_color()


func _get_altitude_state_key(altitude: float) -> StringName:
	if altitude < drop_profile.minimum_release_altitude:
		return &"UI_DELIVERY_LAB_STATE_LOW"
	if altitude > drop_profile.maximum_release_altitude:
		return &"UI_DELIVERY_LAB_STATE_HIGH"
	return &"UI_DELIVERY_LAB_STATE_VALID"


func _get_speed_state_key(speed: float) -> StringName:
	if speed < drop_profile.minimum_release_speed:
		return &"UI_DELIVERY_LAB_STATE_SLOW"
	if speed > drop_profile.maximum_release_speed:
		return &"UI_DELIVERY_LAB_STATE_FAST"
	return &"UI_DELIVERY_LAB_STATE_VALID"


func _get_cargo_state_key() -> StringName:
	if _cargo_in_flight:
		return &"UI_DELIVERY_LAB_CARGO_DESCENDING"
	if _drop_model.has_released_cargo():
		return &"UI_DELIVERY_LAB_CARGO_RELEASED"
	return &"UI_DELIVERY_LAB_CARGO_READY"


func _get_result_message() -> String:
	if not _feedback_reason_key.is_empty() and _feedback_remaining > 0.0:
		return _format_feedback_reason(_feedback_reason_key)
	if _cargo_in_flight:
		return tr("UI_DELIVERY_LAB_DROP_IN_PROGRESS")
	if _result_settled and _active_drop_result != null:
		match _active_drop_result.status:
			LowAltitudeDropModel.Status.CORE_SUCCESS:
				return tr("UI_DELIVERY_LAB_RESULT_CORE_FORMAT") % [
					roundi(_active_drop_result.horizontal_offset),
					roundi(_active_drop_result.quality_ratio * 100.0),
					roundi(_active_drop_result.reward_ratio * 100.0),
				]
			LowAltitudeDropModel.Status.OUTER_PARTIAL:
				return tr("UI_DELIVERY_LAB_RESULT_OUTER_FORMAT") % [
					roundi(_active_drop_result.horizontal_offset),
					roundi(_active_drop_result.quality_ratio * 100.0),
					roundi(_active_drop_result.reward_ratio * 100.0),
				]
			LowAltitudeDropModel.Status.MISSED:
				return tr("UI_DELIVERY_LAB_RESULT_MISSED_FORMAT") % roundi(
					_active_drop_result.horizontal_offset
				)
	if flight_ship.is_failed:
		return tr("UI_DELIVERY_LAB_SHIP_FAILED")
	if _is_release_window_valid():
		return tr("UI_DELIVERY_LAB_READY_TO_DROP")
	return tr("UI_DELIVERY_LAB_GUIDANCE")


func _format_feedback_reason(reason_key: StringName) -> String:
	match reason_key:
		LowAltitudeDropModel.REASON_ALTITUDE_TOO_LOW:
			return tr(reason_key) % roundi(drop_profile.minimum_release_altitude)
		LowAltitudeDropModel.REASON_ALTITUDE_TOO_HIGH:
			return tr(reason_key) % roundi(drop_profile.maximum_release_altitude)
		LowAltitudeDropModel.REASON_SPEED_TOO_LOW:
			return tr(reason_key) % roundi(drop_profile.minimum_release_speed)
		LowAltitudeDropModel.REASON_SPEED_TOO_HIGH:
			return tr(reason_key) % roundi(drop_profile.maximum_release_speed)
		_:
			return tr(reason_key)


func _get_result_color() -> Color:
	if not _feedback_reason_key.is_empty() and _feedback_remaining > 0.0:
		if _feedback_reason_key == &"UI_DELIVERY_LAB_RETRY_RESTORED":
			return COLOR_READY
		return COLOR_WARNING
	if _cargo_in_flight:
		return COLOR_WARNING
	if _result_settled and _active_drop_result != null:
		match _active_drop_result.status:
			LowAltitudeDropModel.Status.CORE_SUCCESS:
				return COLOR_READY
			LowAltitudeDropModel.Status.OUTER_PARTIAL:
				return COLOR_WARNING
			LowAltitudeDropModel.Status.MISSED:
				return COLOR_FAILURE
	if flight_ship.is_failed:
		return COLOR_FAILURE
	return COLOR_READY if _is_release_window_valid() else COLOR_NEUTRAL


func _is_release_window_valid() -> bool:
	var altitude: float = get_current_altitude()
	var speed: float = get_current_horizontal_speed()
	return (
		altitude >= drop_profile.minimum_release_altitude
		and altitude <= drop_profile.maximum_release_altitude
		and speed >= drop_profile.minimum_release_speed
		and speed <= drop_profile.maximum_release_speed
	)


func _get_prediction_color(
	predicted_x: float,
	release_window_valid: bool
) -> Color:
	if not release_window_valid:
		return COLOR_FAILURE
	var offset: float = absf(predicted_x - target_center_x)
	if offset <= drop_profile.core_zone_half_width:
		return COLOR_READY
	if offset <= drop_profile.outer_zone_half_width:
		return COLOR_WARNING
	return COLOR_FAILURE


func _reset_zone_colors() -> void:
	if core_zone != null:
		core_zone.color = COLOR_CORE_ZONE
	if outer_zone != null:
		outer_zone.color = COLOR_OUTER_ZONE


func _apply_result_zone_color(status: int) -> void:
	_reset_zone_colors()
	match status:
		LowAltitudeDropModel.Status.CORE_SUCCESS:
			core_zone.color = Color(0.40, 1.0, 0.70, 0.95)
		LowAltitudeDropModel.Status.OUTER_PARTIAL:
			outer_zone.color = Color(1.0, 0.78, 0.30, 0.78)
		LowAltitudeDropModel.Status.MISSED:
			core_zone.color = Color(0.42, 0.48, 0.48, 0.44)
			outer_zone.color = Color(0.50, 0.42, 0.36, 0.40)
