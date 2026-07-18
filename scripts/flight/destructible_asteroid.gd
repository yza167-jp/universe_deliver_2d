class_name DestructibleAsteroid
extends StaticBody2D

signal hit_received(target_id: StringName, remaining_durability: int)
signal destroyed(target_id: StringName)

const DESTRUCTION_SAMPLE_RATE: int = 22050
const DESTRUCTION_SOUND_SECONDS: float = 0.16
const HIT_FLASH_SECONDS: float = 0.08

@export var target_id: StringName = &"destructible_asteroid"
@export_range(1, 20, 1, "or_greater") var max_durability: int = 1

@onready var _visual_root: Node2D = %VisualRoot
@onready var _hit_flash: Polygon2D = %HitFlash
@onready var _destruction_fragments: CPUParticles2D = %DestructionFragments
@onready var _destruction_audio: AudioStreamPlayer2D = %DestructionAudio

var _current_durability: int = 1
var _is_destroyed: bool = false
var _hit_flash_remaining: float = 0.0


func _ready() -> void:
	if _destruction_audio != null:
		_destruction_audio.stream = _create_destruction_stream()
	reset_asteroid()


func _process(delta: float) -> void:
	if _hit_flash_remaining <= 0.0:
		return
	_hit_flash_remaining = maxf(_hit_flash_remaining - maxf(delta, 0.0), 0.0)
	if _hit_flash != null:
		_hit_flash.visible = _hit_flash_remaining > 0.0 and not _is_destroyed


func apply_laser_damage(damage: int) -> bool:
	if _is_destroyed or damage <= 0:
		return false
	_current_durability = maxi(_current_durability - damage, 0)
	_hit_flash_remaining = HIT_FLASH_SECONDS
	if _hit_flash != null:
		_hit_flash.visible = true
	hit_received.emit(target_id, _current_durability)
	if _current_durability <= 0:
		_destroy_asteroid()
	return true


func reset_asteroid() -> void:
	_current_durability = maxi(max_durability, 1)
	_is_destroyed = false
	_hit_flash_remaining = 0.0
	collision_layer = FlightWeaponRules.DESTRUCTIBLE_ASTEROID_LAYER
	collision_mask = 0
	if _visual_root != null:
		_visual_root.visible = true
	if _hit_flash != null:
		_hit_flash.visible = false
	if _destruction_fragments != null:
		_destruction_fragments.emitting = false
		_destruction_fragments.restart()
		_destruction_fragments.emitting = false
	if _destruction_audio != null:
		_destruction_audio.stop()


func is_destroyed() -> bool:
	return _is_destroyed


func get_current_durability() -> int:
	return _current_durability


func get_destruction_fragments() -> CPUParticles2D:
	return _destruction_fragments


func get_visual_root() -> Node2D:
	return _visual_root


func _destroy_asteroid() -> void:
	_is_destroyed = true
	collision_layer = 0
	if _visual_root != null:
		_visual_root.visible = false
	if _hit_flash != null:
		_hit_flash.visible = false
	if _destruction_fragments != null:
		_destruction_fragments.restart()
		_destruction_fragments.emitting = true
	if _destruction_audio != null and DisplayServer.get_name() != "headless":
		_destruction_audio.play()
	destroyed.emit(target_id)


func _create_destruction_stream() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = DESTRUCTION_SAMPLE_RATE
	stream.stereo = false
	var frame_count: int = maxi(
		int(DESTRUCTION_SAMPLE_RATE * DESTRUCTION_SOUND_SECONDS),
		1
	)
	var audio_data: PackedByteArray = PackedByteArray()
	audio_data.resize(frame_count * 2)
	for frame_index: int in frame_count:
		var progress: float = float(frame_index) / float(frame_count)
		var time_seconds: float = float(frame_index) / float(DESTRUCTION_SAMPLE_RATE)
		var envelope: float = (1.0 - progress) * (1.0 - progress)
		var crackle: float = sin(TAU * (120.0 + 760.0 * progress) * time_seconds)
		var rumble: float = sin(TAU * 74.0 * time_seconds)
		var sample: float = clampf(
			(crackle * 0.32 + rumble * 0.24) * envelope,
			-0.8,
			0.8
		)
		var encoded_sample: int = int(round(sample * 32767.0)) & 0xffff
		audio_data[frame_index * 2] = encoded_sample & 0xff
		audio_data[frame_index * 2 + 1] = (encoded_sample >> 8) & 0xff
	stream.data = audio_data
	return stream
