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
const LASER_LOOP_SECONDS: float = 0.36

@export var tuning: FlightTuning

@onready var _beam: Line2D = %Beam
@onready var _muzzle_flash: Polygon2D = %MuzzleFlash
@onready var _shot_audio: AudioStreamPlayer2D = %ShotAudio

var _laser_enabled: bool = false
var _beam_active: bool = false
var _tap_release_pending: bool = false
var _minimum_visible_remaining: float = 0.0
var _release_remaining: float = 0.0
var _damage_tick_remaining: float = 0.0
var _damage_tick_count: int = 0
var _last_beam_end_global: Vector2 = Vector2.ZERO


func _ready() -> void:
	if _shot_audio != null:
		_shot_audio.stream = _create_laser_stream()
	_reset_visual_feedback()


func _physics_process(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	_minimum_visible_remaining = maxf(
		_minimum_visible_remaining - safe_delta,
		0.0
	)
	if _beam_active:
		_damage_tick_remaining = maxf(_damage_tick_remaining - safe_delta, 0.0)
		var apply_damage: bool = _damage_tick_remaining <= 0.0
		_cast_laser(apply_damage)
		if apply_damage:
			_damage_tick_remaining = _get_damage_tick_seconds()
		if _tap_release_pending:
			_tap_release_pending = false
			stop_beam()
		return
	if _minimum_visible_remaining > 0.0 or _release_remaining > 0.0:
		_release_remaining = maxf(_release_remaining - safe_delta, 0.0)
		if _minimum_visible_remaining <= 0.0 and _release_remaining <= 0.0:
			_reset_visual_feedback()
			return
		_apply_release_fade()
		return
	_reset_visual_feedback()


## Starts the shared keyboard/mouse held beam. Damage ticks never control visibility.
func begin_beam() -> FireResult:
	if not _laser_enabled:
		fire_rejected.emit(FIRE_UNAVAILABLE_KEY)
		return FireResult.UNAVAILABLE
	if _beam_active:
		return FireResult.FIRED
	_beam_active = true
	_tap_release_pending = false
	_release_remaining = 0.0
	_minimum_visible_remaining = _get_minimum_visible_seconds()
	_damage_tick_remaining = _get_damage_tick_seconds()
	var hit_target: bool = _cast_laser(true)
	if _shot_audio != null and DisplayServer.get_name() != "headless":
		_shot_audio.play()
	fired.emit(hit_target)
	return FireResult.FIRED


## Compatibility tap API: the beam starts now and releases on the next physics update.
func request_fire() -> FireResult:
	var result: FireResult = begin_beam()
	if result == FireResult.FIRED:
		_tap_release_pending = true
	return result


func stop_beam() -> void:
	if not _beam_active and not _tap_release_pending:
		return
	_beam_active = false
	_tap_release_pending = false
	_release_remaining = maxf(
		_get_release_fade_seconds(),
		_minimum_visible_remaining
	)
	if _shot_audio != null:
		_shot_audio.stop()


func set_laser_enabled(enabled: bool) -> void:
	_laser_enabled = enabled
	if not _laser_enabled:
		reset_weapon()


func is_laser_enabled() -> bool:
	return _laser_enabled


func is_ready_to_fire() -> bool:
	return _laser_enabled


func is_beam_active() -> bool:
	return _beam_active


func is_beam_visible() -> bool:
	return _beam != null and _beam.visible


func get_cooldown_remaining() -> float:
	return 0.0


func get_beam() -> Line2D:
	return _beam


func get_shot_audio() -> AudioStreamPlayer2D:
	return _shot_audio


func get_damage_tick_count() -> int:
	return _damage_tick_count


func get_last_beam_end_global() -> Vector2:
	return _last_beam_end_global


func reset_weapon() -> void:
	_beam_active = false
	_tap_release_pending = false
	_minimum_visible_remaining = 0.0
	_release_remaining = 0.0
	_damage_tick_remaining = 0.0
	_damage_tick_count = 0
	_last_beam_end_global = global_position
	if _shot_audio != null:
		_shot_audio.stop()
	_reset_visual_feedback()


func _cast_laser(apply_damage: bool) -> bool:
	var laser_range: float = 0.0
	var laser_damage: int = 0
	if tuning != null:
		laser_range = maxf(tuning.beam_max_range, 0.0)
		laser_damage = maxi(tuning.beam_damage_per_tick, 0)
	var start_position: Vector2 = global_position
	var forward: Vector2 = global_transform.x.normalized()
	var end_position: Vector2 = start_position + forward * laser_range
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
			if apply_damage and collider is DestructibleAsteroid:
				var asteroid: DestructibleAsteroid = collider as DestructibleAsteroid
				hit_target = asteroid.apply_laser_damage(laser_damage)
				if hit_target:
					_damage_tick_count += 1
					target_hit.emit(
						asteroid.target_id,
						asteroid.get_current_durability(),
						asteroid.is_destroyed()
					)
	_last_beam_end_global = end_position
	_show_beam(end_position)
	return hit_target


func _show_beam(end_position: Vector2) -> void:
	if _beam != null:
		_beam.points = PackedVector2Array([Vector2.ZERO, to_local(end_position)])
		_beam.width = tuning.beam_width if tuning != null else 3.0
		_beam.modulate.a = 1.0
		_beam.visible = true
	if _muzzle_flash != null:
		_muzzle_flash.modulate.a = 1.0
		_muzzle_flash.visible = true


func _apply_release_fade() -> void:
	var fade_seconds: float = _get_release_fade_seconds()
	var alpha: float = 1.0
	if _minimum_visible_remaining <= 0.0 and fade_seconds > 0.0:
		alpha = clampf(_release_remaining / fade_seconds, 0.0, 1.0)
	if _beam != null:
		_beam.visible = true
		_beam.modulate.a = alpha
	if _muzzle_flash != null:
		_muzzle_flash.visible = true
		_muzzle_flash.modulate.a = alpha


func _reset_visual_feedback() -> void:
	if _beam != null:
		_beam.visible = false
		_beam.modulate.a = 1.0
	if _muzzle_flash != null:
		_muzzle_flash.visible = false
		_muzzle_flash.modulate.a = 1.0


func _get_damage_tick_seconds() -> float:
	return maxf(tuning.beam_damage_tick_seconds if tuning != null else 0.1, 0.01)


func _get_minimum_visible_seconds() -> float:
	return maxf(tuning.beam_min_visible_seconds if tuning != null else 0.08, 0.01)


func _get_release_fade_seconds() -> float:
	return maxf(tuning.beam_release_fade_seconds if tuning != null else 0.04, 0.0)


func _create_laser_stream() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = LASER_SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var frame_count: int = maxi(int(LASER_SAMPLE_RATE * LASER_LOOP_SECONDS), 1)
	stream.loop_begin = 0
	stream.loop_end = frame_count
	var audio_data: PackedByteArray = PackedByteArray()
	audio_data.resize(frame_count * 2)
	for frame_index: int in frame_count:
		var progress: float = float(frame_index) / float(frame_count)
		var time_seconds: float = float(frame_index) / float(LASER_SAMPLE_RATE)
		var carrier: float = sin(TAU * 720.0 * time_seconds) * 0.24
		var harmonic: float = sin(TAU * 1440.0 * time_seconds + progress) * 0.1
		var shimmer: float = sin(TAU * 54.0 * time_seconds) * 0.06
		var sample: float = clampf(carrier + harmonic + shimmer, -0.62, 0.62)
		var encoded_sample: int = int(round(sample * 32767.0)) & 0xffff
		audio_data[frame_index * 2] = encoded_sample & 0xff
		audio_data[frame_index * 2 + 1] = (encoded_sample >> 8) & 0xff
	stream.data = audio_data
	return stream
