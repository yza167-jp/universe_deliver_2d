class_name FlightLaserWeapon
extends Node2D

signal fired(hit_target: bool)
signal fire_rejected(reason_key: StringName)
signal target_hit(
	target_id: StringName,
	remaining_durability: int,
	target_destroyed: bool
)

enum FireResult {
	FIRED,
	COOLDOWN,
	UNAVAILABLE,
}

const FIRE_UNAVAILABLE_KEY: StringName = &"UI_FLIGHT_LAB_STATUS_LASER_UNAVAILABLE"
const FIRE_COOLDOWN_KEY: StringName = &"UI_FLIGHT_LAB_STATUS_LASER_COOLDOWN"
const LASER_SAMPLE_RATE: int = 22050
const LASER_SOUND_SECONDS: float = 0.09

@export var tuning: FlightTuning

@onready var _beam: Line2D = %Beam
@onready var _muzzle_flash: Polygon2D = %MuzzleFlash
@onready var _shot_audio: AudioStreamPlayer2D = %ShotAudio

var _laser_enabled: bool = false
var _cooldown_remaining: float = 0.0
var _beam_remaining: float = 0.0


func _ready() -> void:
	if _shot_audio != null:
		_shot_audio.stream = _create_laser_stream()
	_reset_visual_feedback()


func _physics_process(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	_cooldown_remaining = maxf(_cooldown_remaining - safe_delta, 0.0)
	_beam_remaining = maxf(_beam_remaining - safe_delta, 0.0)
	if _beam != null:
		_beam.visible = _beam_remaining > 0.0
	if _muzzle_flash != null:
		_muzzle_flash.visible = _beam_remaining > 0.0


func request_fire() -> FireResult:
	if not _laser_enabled:
		fire_rejected.emit(FIRE_UNAVAILABLE_KEY)
		return FireResult.UNAVAILABLE
	if _cooldown_remaining > 0.0:
		fire_rejected.emit(FIRE_COOLDOWN_KEY)
		return FireResult.COOLDOWN

	var cooldown_seconds: float = 0.0
	var beam_seconds: float = 0.0
	if tuning != null:
		cooldown_seconds = maxf(tuning.laser_cooldown_seconds, 0.0)
		beam_seconds = maxf(tuning.laser_beam_duration_seconds, 0.0)
	_cooldown_remaining = cooldown_seconds
	_beam_remaining = beam_seconds
	var hit_target: bool = _cast_laser()
	if _shot_audio != null and DisplayServer.get_name() != "headless":
		_shot_audio.play()
	fired.emit(hit_target)
	return FireResult.FIRED


func set_laser_enabled(enabled: bool) -> void:
	_laser_enabled = enabled
	if not _laser_enabled:
		reset_weapon()


func is_laser_enabled() -> bool:
	return _laser_enabled


func is_ready_to_fire() -> bool:
	return _laser_enabled and _cooldown_remaining <= 0.0


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func get_beam() -> Line2D:
	return _beam


func get_shot_audio() -> AudioStreamPlayer2D:
	return _shot_audio


func reset_weapon() -> void:
	_cooldown_remaining = 0.0
	_beam_remaining = 0.0
	if _shot_audio != null:
		_shot_audio.stop()
	_reset_visual_feedback()


func _cast_laser() -> bool:
	var laser_range: float = 0.0
	var laser_damage: int = 0
	if tuning != null:
		laser_range = maxf(tuning.laser_range, 0.0)
		laser_damage = maxi(tuning.laser_damage, 0)
	var start_position: Vector2 = global_position
	var end_position: Vector2 = start_position + global_transform.x.normalized() * laser_range
	var hit_target: bool = false
	if is_inside_tree() and laser_range > 0.0:
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			start_position,
			end_position,
			FlightWeaponRules.LASER_TARGET_MASK
		)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var hit_position: Variant = hit.get("position", end_position)
			if hit_position is Vector2:
				end_position = hit_position as Vector2
			var collider: Object = hit.get("collider") as Object
			if collider is DestructibleAsteroid:
				var asteroid: DestructibleAsteroid = collider as DestructibleAsteroid
				hit_target = asteroid.apply_laser_damage(laser_damage)
				if hit_target:
					target_hit.emit(
						asteroid.target_id,
						asteroid.get_current_durability(),
						asteroid.is_destroyed()
					)
	_show_beam(end_position)
	return hit_target


func _show_beam(end_position: Vector2) -> void:
	if _beam != null:
		_beam.points = PackedVector2Array([Vector2.ZERO, to_local(end_position)])
		_beam.visible = true
	if _muzzle_flash != null:
		_muzzle_flash.visible = true


func _reset_visual_feedback() -> void:
	if _beam != null:
		_beam.visible = false
	if _muzzle_flash != null:
		_muzzle_flash.visible = false


func _create_laser_stream() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = LASER_SAMPLE_RATE
	stream.stereo = false
	var frame_count: int = maxi(int(LASER_SAMPLE_RATE * LASER_SOUND_SECONDS), 1)
	var audio_data: PackedByteArray = PackedByteArray()
	audio_data.resize(frame_count * 2)
	for frame_index: int in frame_count:
		var progress: float = float(frame_index) / float(frame_count)
		var time_seconds: float = float(frame_index) / float(LASER_SAMPLE_RATE)
		var frequency: float = lerpf(1480.0, 620.0, progress)
		var envelope: float = (1.0 - progress) * (1.0 - progress)
		var sample: float = clampf(
			sin(TAU * frequency * time_seconds) * envelope * 0.42,
			-0.75,
			0.75
		)
		var encoded_sample: int = int(round(sample * 32767.0)) & 0xffff
		audio_data[frame_index * 2] = encoded_sample & 0xff
		audio_data[frame_index * 2 + 1] = (encoded_sample >> 8) & 0xff
	stream.data = audio_data
	return stream
