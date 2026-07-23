class_name FlightLightningStrike
extends Node2D

signal warning_started(strike_id: StringName, warning_seconds: float)
signal strike_started(
	strike_id: StringName,
	hit_ship: bool,
	damage: float,
	cargo_damage: float
)
signal strike_finished(strike_id: StringName, hit_ship: bool)

enum State {
	IDLE,
	TRACKING,
	LOCKED,
	STRIKE,
	COOLDOWN,
}

const AUDIO_SAMPLE_RATE: int = 22050
const WARNING_SOUND_SECONDS: float = 0.14
const STRIKE_SOUND_SECONDS: float = 0.22

@export var strike_id: StringName = &"red_sand_lightning"
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var trigger_route_distance: float = 0.0
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var strike_route_distance: float = 0.0
@export_range(-2000.0, 2000.0, 1.0) var target_y: float = 180.0
@export_range(0.1, 3.0, 0.05, "or_greater") var tracking_seconds: float = 0.8
@export_range(0.1, 3.0, 0.05, "or_greater") var lock_seconds: float = 0.65
@export_range(0.05, 1.0, 0.01, "or_greater") var strike_seconds: float = 0.18
@export_range(0.0, 3.0, 0.05, "or_greater") var cooldown_seconds: float = 0.45
@export_range(0.1, 30.0, 0.1, "or_greater") var tracking_smoothing: float = 10.0
@export_range(0.0, 1.0, 0.01) var velocity_lead_seconds: float = 0.65
@export var viewport_safe_margin: Vector2 = Vector2(72.0, 60.0)
@export_range(1.0, 500.0, 1.0, "or_greater") var hit_half_width: float = 42.0
@export_range(1.0, 500.0, 1.0, "or_greater") var hit_half_height: float = 48.0
@export_range(0.0, 500.0, 1.0, "or_greater") var damage: float = 28.0
@export_range(0.0, 100.0, 1.0, "or_greater") var cargo_damage: float = 0.0

@onready var _warning_visual: Node2D = %WarningVisual
@onready var _warning_column: Line2D = %WarningColumn
@onready var _target_box: Line2D = get_node_or_null("WarningVisual/TargetBox") as Line2D
@onready var _strike_visual: Node2D = %StrikeVisual
@onready var _warning_audio: AudioStreamPlayer2D = %WarningAudio
@onready var _strike_audio: AudioStreamPlayer2D = %StrikeAudio

var _state: State = State.IDLE
var _state_remaining: float = 0.0
var _last_hit_ship: bool = false
var _has_resolved: bool = false
var _route_origin_x: float = 0.0
var _target_global_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	if _warning_audio != null:
		_warning_audio.stream = _create_warning_stream()
	if _strike_audio != null:
		_strike_audio.stream = _create_strike_stream()
	_apply_visual_state()


func configure(route_origin_x: float) -> void:
	_route_origin_x = route_origin_x
	position = Vector2(route_origin_x + trigger_route_distance, target_y)
	_target_global_position = global_position
	_apply_visual_state()


func advance(
	delta: float,
	maximum_route_distance: float,
	ship_global_position: Vector2,
	ship_velocity: Vector2 = Vector2.ZERO,
	camera_global_position: Vector2 = Vector2.ZERO,
	viewport_size: Vector2 = Vector2(640.0, 360.0)
) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	var camera_center: Vector2 = (
		ship_global_position
		if camera_global_position == Vector2.ZERO
		else camera_global_position
	)
	if (
		_state == State.IDLE
		and not _has_resolved
		and maximum_route_distance >= trigger_route_distance
	):
		_begin_tracking(
			ship_global_position,
			ship_velocity,
			camera_center,
			viewport_size
		)
	if _state == State.TRACKING:
		_update_tracking_target(
			ship_global_position,
			ship_velocity,
			camera_center,
			viewport_size,
			safe_delta
		)
		_state_remaining = maxf(_state_remaining - safe_delta, 0.0)
		_update_warning_pulse()
		if _state_remaining <= 0.0:
			_begin_lock()
	elif _state == State.LOCKED:
		_state_remaining = maxf(_state_remaining - safe_delta, 0.0)
		_update_warning_pulse()
		if _state_remaining <= 0.0:
			_begin_strike(ship_global_position)
	elif _state == State.STRIKE:
		_state_remaining = maxf(_state_remaining - safe_delta, 0.0)
		if _state_remaining <= 0.0:
			_begin_cooldown()
	elif _state == State.COOLDOWN:
		_state_remaining = maxf(_state_remaining - safe_delta, 0.0)
		if _state_remaining <= 0.0:
			_state = State.IDLE
			_has_resolved = true
			_apply_visual_state()


func reset_for_route(route_distance: float) -> void:
	_state_remaining = 0.0
	_last_hit_ship = false
	_has_resolved = route_distance > trigger_route_distance
	_state = State.IDLE
	position = Vector2(_route_origin_x + trigger_route_distance, target_y)
	_target_global_position = global_position
	if _warning_audio != null:
		_warning_audio.stop()
	if _strike_audio != null:
		_strike_audio.stop()
	_apply_visual_state()


## Public hit-zone queries are valid only during the short STRIKE phase.
func is_position_in_hit_zone(global_point: Vector2) -> bool:
	return _state == State.STRIKE and _is_point_in_target_zone(global_point)


func get_state() -> State:
	return _state


func get_warning_remaining() -> float:
	if _state not in [State.TRACKING, State.LOCKED]:
		return 0.0
	return _state_remaining + (lock_seconds if _state == State.TRACKING else 0.0)


func get_target_global_position() -> Vector2:
	return _target_global_position


func did_hit_ship() -> bool:
	return _last_hit_ship


func has_resolved() -> bool:
	return _has_resolved


func get_prediction_seconds() -> float:
	return clampf(velocity_lead_seconds, 0.0, 1.0)


func _begin_tracking(
	ship_global_position: Vector2,
	ship_velocity: Vector2,
	camera_center: Vector2,
	viewport_size: Vector2
) -> void:
	_state = State.TRACKING
	_state_remaining = maxf(tracking_seconds, 0.1)
	_last_hit_ship = false
	_update_tracking_target(
		ship_global_position,
		ship_velocity,
		camera_center,
		viewport_size,
		0.0,
		true
	)
	_apply_visual_state()
	if _warning_audio != null and DisplayServer.get_name() != "headless":
		_warning_audio.pitch_scale = 0.92
		_warning_audio.play()
	warning_started.emit(
		strike_id,
		maxf(tracking_seconds, 0.1) + maxf(lock_seconds, 0.1)
	)


func _begin_lock() -> void:
	_state = State.LOCKED
	_state_remaining = maxf(lock_seconds, 0.1)
	_apply_visual_state()
	if _warning_audio != null and DisplayServer.get_name() != "headless":
		_warning_audio.pitch_scale = 1.35
		_warning_audio.play()


func _begin_strike(ship_global_position: Vector2) -> void:
	_state = State.STRIKE
	_state_remaining = maxf(strike_seconds, 0.05)
	_last_hit_ship = _is_point_in_target_zone(ship_global_position)
	_apply_visual_state()
	if _strike_audio != null and DisplayServer.get_name() != "headless":
		_strike_audio.play()
	strike_started.emit(strike_id, _last_hit_ship, damage, cargo_damage)


func _begin_cooldown() -> void:
	_state = State.COOLDOWN
	_state_remaining = maxf(cooldown_seconds, 0.0)
	_apply_visual_state()
	strike_finished.emit(strike_id, _last_hit_ship)
	if _state_remaining <= 0.0:
		_state = State.IDLE
		_has_resolved = true
		_apply_visual_state()


func _update_tracking_target(
	ship_global_position: Vector2,
	ship_velocity: Vector2,
	camera_center: Vector2,
	viewport_size: Vector2,
	delta: float,
	snap: bool = false
) -> void:
	var predicted_position: Vector2 = (
		ship_global_position + ship_velocity * get_prediction_seconds()
	)
	var half_safe_size: Vector2 = Vector2(
		maxf(viewport_size.x * 0.5 - viewport_safe_margin.x, hit_half_width),
		maxf(viewport_size.y * 0.5 - viewport_safe_margin.y, hit_half_height)
	)
	var clamped_target: Vector2 = Vector2(
		clampf(
			predicted_position.x,
			camera_center.x - half_safe_size.x,
			camera_center.x + half_safe_size.x
		),
		clampf(
			predicted_position.y,
			camera_center.y - half_safe_size.y,
			camera_center.y + half_safe_size.y
		)
	)
	if snap or delta <= 0.0:
		_target_global_position = clamped_target
	else:
		var blend: float = 1.0 - exp(-maxf(tracking_smoothing, 0.1) * delta)
		_target_global_position = _target_global_position.lerp(clamped_target, blend)
	global_position = _target_global_position


func _is_point_in_target_zone(global_point: Vector2) -> bool:
	var local_point: Vector2 = to_local(global_point)
	return (
		absf(local_point.x) <= hit_half_width
		and absf(local_point.y) <= hit_half_height
	)


func _apply_visual_state() -> void:
	var warning_visible: bool = _state in [State.TRACKING, State.LOCKED]
	if _warning_visual != null:
		_warning_visual.visible = warning_visible
		_warning_visual.scale = Vector2.ONE * (1.08 if _state == State.LOCKED else 1.0)
	if _strike_visual != null:
		_strike_visual.visible = _state == State.STRIKE
	if _warning_column != null:
		_warning_column.modulate = (
			Color(1.0, 0.3, 0.24, 1.0)
			if _state == State.LOCKED
			else Color.WHITE
		)
	if _target_box != null:
		_target_box.default_color = (
			Color(1.0, 0.33, 0.24, 1.0)
			if _state == State.LOCKED
			else Color(0.952941, 0.686275, 0.258824, 0.9)
		)


func _update_warning_pulse() -> void:
	if _warning_column == null:
		return
	var base_seconds: float = tracking_seconds if _state == State.TRACKING else lock_seconds
	var elapsed: float = maxf(base_seconds - _state_remaining, 0.0)
	_warning_column.modulate.a = lerpf(
		0.4 if _state == State.TRACKING else 0.68,
		1.0,
		0.5 + 0.5 * sin(elapsed * TAU * (4.0 if _state == State.TRACKING else 7.0))
	)


func _create_warning_stream() -> AudioStreamWAV:
	return _create_tone_stream(880.0, WARNING_SOUND_SECONDS, 0.28, false)


func _create_strike_stream() -> AudioStreamWAV:
	return _create_tone_stream(116.0, STRIKE_SOUND_SECONDS, 0.5, true)


func _create_tone_stream(
	base_frequency: float,
	duration_seconds: float,
	amplitude: float,
	add_crackle: bool
) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_SAMPLE_RATE
	stream.stereo = false
	var frame_count: int = maxi(int(AUDIO_SAMPLE_RATE * duration_seconds), 1)
	var audio_data: PackedByteArray = PackedByteArray()
	audio_data.resize(frame_count * 2)
	for frame_index: int in frame_count:
		var progress: float = float(frame_index) / float(frame_count)
		var time_seconds: float = float(frame_index) / float(AUDIO_SAMPLE_RATE)
		var envelope: float = (1.0 - progress) * (1.0 - progress)
		var tone: float = sin(TAU * base_frequency * time_seconds)
		var crackle: float = 0.0
		if add_crackle:
			crackle = sin(TAU * (930.0 + 1700.0 * progress) * time_seconds) * 0.3
		var sample: float = clampf(
			(tone + crackle) * amplitude * envelope,
			-0.8,
			0.8
		)
		var encoded_sample: int = int(round(sample * 32767.0)) & 0xffff
		audio_data[frame_index * 2] = encoded_sample & 0xff
		audio_data[frame_index * 2 + 1] = (encoded_sample >> 8) & 0xff
	stream.data = audio_data
	return stream
