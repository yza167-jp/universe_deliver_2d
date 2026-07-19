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
	PENDING,
	WARNING,
	ACTIVE,
	SPENT,
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
@export_range(0.1, 10.0, 0.05, "or_greater") var warning_seconds: float = 1.25
@export_range(0.05, 2.0, 0.01, "or_greater") var active_seconds: float = 0.18
@export_range(1.0, 500.0, 1.0, "or_greater") var hit_half_width: float = 42.0
@export_range(1.0, 500.0, 1.0, "or_greater") var hit_half_height: float = 48.0
@export_range(0.0, 500.0, 1.0, "or_greater") var damage: float = 28.0
@export_range(0.0, 100.0, 1.0, "or_greater") var cargo_damage: float = 0.0

@onready var _warning_visual: Node2D = %WarningVisual
@onready var _warning_column: Line2D = %WarningColumn
@onready var _strike_visual: Node2D = %StrikeVisual
@onready var _warning_audio: AudioStreamPlayer2D = %WarningAudio
@onready var _strike_audio: AudioStreamPlayer2D = %StrikeAudio

var _state: State = State.PENDING
var _warning_remaining: float = 0.0
var _active_remaining: float = 0.0
var _last_hit_ship: bool = false


func _ready() -> void:
	if _warning_audio != null:
		_warning_audio.stream = _create_warning_stream()
	if _strike_audio != null:
		_strike_audio.stream = _create_strike_stream()
	_apply_visual_state()


func configure(route_origin_x: float) -> void:
	position = Vector2(route_origin_x + strike_route_distance, target_y)
	_apply_visual_state()


func advance(
	delta: float,
	maximum_route_distance: float,
	ship_global_position: Vector2
) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	if (
		_state == State.PENDING
		and maximum_route_distance >= trigger_route_distance
	):
		_begin_warning()
	if _state == State.WARNING:
		_warning_remaining = maxf(_warning_remaining - safe_delta, 0.0)
		_update_warning_pulse()
		if _warning_remaining <= 0.0:
			_begin_strike(ship_global_position)
	elif _state == State.ACTIVE:
		_active_remaining = maxf(_active_remaining - safe_delta, 0.0)
		if _active_remaining <= 0.0:
			_finish_strike()


func reset_for_route(route_distance: float) -> void:
	_warning_remaining = 0.0
	_active_remaining = 0.0
	_last_hit_ship = false
	_state = (
		State.SPENT
		if route_distance > strike_route_distance + hit_half_width
		else State.PENDING
	)
	if _warning_audio != null:
		_warning_audio.stop()
	if _strike_audio != null:
		_strike_audio.stop()
	_apply_visual_state()


func is_position_in_hit_zone(global_point: Vector2) -> bool:
	var local_point: Vector2 = to_local(global_point)
	return (
		absf(local_point.x) <= hit_half_width
		and absf(local_point.y) <= hit_half_height
	)


func get_state() -> State:
	return _state


func get_warning_remaining() -> float:
	return _warning_remaining


func did_hit_ship() -> bool:
	return _last_hit_ship


func _begin_warning() -> void:
	_state = State.WARNING
	_warning_remaining = maxf(warning_seconds, 0.1)
	_active_remaining = 0.0
	_last_hit_ship = false
	_apply_visual_state()
	if _warning_audio != null and DisplayServer.get_name() != "headless":
		_warning_audio.play()
	warning_started.emit(strike_id, _warning_remaining)


func _begin_strike(ship_global_position: Vector2) -> void:
	_state = State.ACTIVE
	_warning_remaining = 0.0
	_active_remaining = maxf(active_seconds, 0.05)
	_last_hit_ship = is_position_in_hit_zone(ship_global_position)
	_apply_visual_state()
	if _strike_audio != null and DisplayServer.get_name() != "headless":
		_strike_audio.play()
	strike_started.emit(strike_id, _last_hit_ship, damage, cargo_damage)


func _finish_strike() -> void:
	_state = State.SPENT
	_active_remaining = 0.0
	_apply_visual_state()
	strike_finished.emit(strike_id, _last_hit_ship)


func _apply_visual_state() -> void:
	if _warning_visual != null:
		_warning_visual.visible = _state == State.WARNING
	if _strike_visual != null:
		_strike_visual.visible = _state == State.ACTIVE
	if _warning_column != null and _state != State.WARNING:
		_warning_column.modulate.a = 1.0


func _update_warning_pulse() -> void:
	if _warning_column == null:
		return
	var elapsed: float = maxf(warning_seconds - _warning_remaining, 0.0)
	_warning_column.modulate.a = lerpf(
		0.35,
		1.0,
		0.5 + 0.5 * sin(elapsed * TAU * 4.0)
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
