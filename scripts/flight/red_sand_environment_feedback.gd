class_name RedSandEnvironmentFeedback
extends CanvasLayer

const AMBIENCE_SAMPLE_RATE: int = 11025
const AMBIENCE_LOOP_SECONDS: float = 1.0
const MUSIC_SAMPLE_RATE: int = 11025
const MUSIC_LOOP_SECONDS: float = 4.0
const LIGHTNING_FLASH_SECONDS: float = 0.18
const RADAR_PULSE_SECONDS: float = 0.18
const RADAR_PULSE_SAMPLE_RATE: int = 11025
const MUSIC_QUIET_VOLUME_DB: float = -30.0
const MUSIC_DANGER_VOLUME_DB: float = -17.0

@onready var _environment_tint: ColorRect = %EnvironmentTint
@onready var _lightning_flash: ColorRect = %LightningFlash
@onready var _ambience_audio: AudioStreamPlayer = %AmbienceAudio
@onready var _music_audio: AudioStreamPlayer = %MusicAudio
@onready var _radar_pressure_tint: ColorRect = %RadarPressureTint
@onready var _radar_pulse_flash: ColorRect = %RadarPulseFlash
@onready var _radar_pulse_audio: AudioStreamPlayer = %RadarPulseAudio
@onready var _speed_streak_particles: CPUParticles2D = %SpeedStreakParticles
@onready var _entry_particles: CPUParticles2D = %AtmosphereEntryParticles
@onready var _storm_particles: CPUParticles2D = %StormParticles
@onready var _wind_bands: Array[ColorRect] = [
	%WindBandA,
	%WindBandB,
	%WindBandC,
]
@onready var _radar_sweeps: Array[ColorRect] = [
	%RadarSweepA,
	%RadarSweepB,
]

var _active_environment_id: StringName = &""
var _active_audio_signature: StringName = &""
var _ambience_cache: Dictionary[StringName, AudioStreamWAV] = {}
var _wind_acceleration: Vector2 = Vector2.ZERO
var _wind_elapsed_seconds: float = 0.0
var _lightning_flash_remaining: float = 0.0
var _lightning_flash_peak_alpha: float = 0.0
var _radar_pressure: float = 0.0
var _radar_locked: bool = false
var _radar_elapsed_seconds: float = 0.0
var _radar_pulse_remaining: float = 0.0
var _radar_pulse_peak_alpha: float = 0.0
var _radar_pulse_count: int = 0
var _base_tint: Color = Color.TRANSPARENT
var _current_tint: Color = Color.TRANSPARENT
var _orbit_to_atmosphere_visual_progress: float = 0.0
var _segment_music_intensity: float = 0.0
var _target_music_intensity: float = 0.0
var _music_intensity: float = 0.0


func _ready() -> void:
	_set_mouse_passthrough(self)
	_apply_wind_visibility(false)
	_apply_radar_visibility(false)
	_set_environment_particles(&"")
	if _lightning_flash != null:
		_lightning_flash.color.a = 0.0
	if _radar_pulse_flash != null:
		_radar_pulse_flash.color.a = 0.0
	if _radar_pulse_audio != null:
		_radar_pulse_audio.stream = _create_radar_pulse_stream()
	if _music_audio != null:
		_music_audio.stream = _create_music_stream()
		_music_audio.volume_db = MUSIC_QUIET_VOLUME_DB
		if DisplayServer.get_name() != "headless":
			_music_audio.play()


func _process(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	_update_environment_tint(safe_delta)
	_update_wind_bands(safe_delta)
	_update_radar_feedback(safe_delta)
	_update_radar_pulse(safe_delta)
	_update_lightning_flash(safe_delta)
	_update_music_mix(safe_delta)


func set_segment(segment: FlightRouteSegment) -> void:
	if segment == null:
		return
	_active_environment_id = segment.id
	_active_audio_signature = _resolve_audio_signature(segment.id)
	_base_tint = _resolve_tint(segment.id)
	_segment_music_intensity = _resolve_music_intensity(segment.id)
	_refresh_music_target()
	_apply_wind_visibility(segment.id == &"red_sand_storm_layer")
	_set_environment_particles(segment.id)
	if segment.id != &"red_sand_low_altitude_control":
		set_radar_pressure(0.0, false)
		_clear_radar_pulse()
	_set_ambience_stream(_active_audio_signature)


func set_wind_acceleration(acceleration: Vector2) -> void:
	_wind_acceleration = acceleration


## Entry heat belongs to the same cross-stage visual curve as the planet geometry.
func set_orbit_to_atmosphere_visual_progress(progress: float) -> void:
	_orbit_to_atmosphere_visual_progress = clampf(progress, 0.0, 1.0)
	if _entry_particles != null:
		_entry_particles.emitting = (
			_orbit_to_atmosphere_visual_progress > 0.08
			and _orbit_to_atmosphere_visual_progress < 0.98
		)


func get_orbit_to_atmosphere_visual_progress() -> float:
	return _orbit_to_atmosphere_visual_progress


func set_ship_feedback(
	speed: float,
	throttle_strength: float,
	boost_strength: float,
	air_density: float,
	inactive: bool
) -> void:
	if _speed_streak_particles == null:
		return
	var normalized_speed: float = clampf(maxf(speed, 0.0) / 520.0, 0.0, 1.0)
	var propulsion_strength: float = clampf(
		maxf(throttle_strength, boost_strength),
		0.0,
		1.0
	)
	_speed_streak_particles.emitting = (
		not inactive
		and normalized_speed >= 0.16
		and (normalized_speed >= 0.34 or propulsion_strength > 0.05)
	)
	_speed_streak_particles.speed_scale = lerpf(
		0.62,
		1.5 + clampf(boost_strength, 0.0, 1.0) * 0.65,
		normalized_speed
	)
	_speed_streak_particles.modulate.a = lerpf(
		0.22,
		0.7 + clampf(boost_strength, 0.0, 1.0) * 0.22,
		maxf(
			maxf(
				normalized_speed,
				clampf(air_density, 0.0, 1.0) * 0.72
			),
			clampf(boost_strength, 0.0, 1.0) * 0.86
		)
	)


func stop_travel_feedback() -> void:
	if _speed_streak_particles != null:
		_speed_streak_particles.emitting = false
	if _entry_particles != null:
		_entry_particles.emitting = false
	if _storm_particles != null:
		_storm_particles.emitting = false
	_clear_radar_pulse()


func set_radar_pressure(lock_risk: float, locked: bool) -> void:
	_radar_pressure = clampf(lock_risk, 0.0, 1.0)
	_radar_locked = locked and _radar_pressure > 0.0
	_apply_radar_visibility(_radar_pressure > 0.0)
	if _radar_pressure_tint != null:
		var tint_color: Color = (
			Color(0.72, 0.08, 0.13, 0.05 + _radar_pressure * 0.12)
			if _radar_locked
			else Color(0.45, 0.12, 0.24, 0.02 + _radar_pressure * 0.07)
		)
		_radar_pressure_tint.color = tint_color
	_refresh_music_target()


func trigger_radar_pulse() -> void:
	_radar_pulse_count += 1
	_radar_pulse_remaining = RADAR_PULSE_SECONDS
	if _radar_pulse_flash != null:
		var pulse_color: Color = Color(1.0, 0.18, 0.1, 0.34)
		_radar_pulse_peak_alpha = pulse_color.a
		_radar_pulse_flash.color = pulse_color
	if _radar_pulse_audio != null and DisplayServer.get_name() != "headless":
		_radar_pulse_audio.stop()
		_radar_pulse_audio.play()


func flash_lightning(hit_ship: bool) -> void:
	_lightning_flash_remaining = LIGHTNING_FLASH_SECONDS
	if _lightning_flash != null:
		var flash_color: Color = (
			Color(0.96, 0.94, 1.0, 0.68)
			if hit_ship
			else Color(0.72, 0.64, 1.0, 0.42)
		)
		_lightning_flash_peak_alpha = flash_color.a
		_lightning_flash.color = flash_color


func get_active_environment_id() -> StringName:
	return _active_environment_id


func get_active_audio_signature() -> StringName:
	return _active_audio_signature


func get_environment_tint() -> Color:
	return Color.TRANSPARENT if _environment_tint == null else _environment_tint.color


func are_wind_bands_visible() -> bool:
	return not _wind_bands.is_empty() and _wind_bands[0].visible


func is_radar_pressure_visible() -> bool:
	return (
		_radar_pressure > 0.0
		and _radar_pressure_tint != null
		and _radar_pressure_tint.visible
	)


func get_radar_pressure() -> float:
	return _radar_pressure


func get_radar_pulse_count() -> int:
	return _radar_pulse_count


func get_radar_pulse_audio() -> AudioStreamPlayer:
	return _radar_pulse_audio


func is_radar_pulse_visible() -> bool:
	return (
		_radar_pulse_remaining > 0.0
		and _radar_pulse_flash != null
		and _radar_pulse_flash.color.a > 0.0
	)


func get_music_intensity() -> float:
	return _music_intensity


func get_target_music_intensity() -> float:
	return _target_music_intensity


func get_music_audio() -> AudioStreamPlayer:
	return _music_audio


func are_speed_streaks_emitting() -> bool:
	return _speed_streak_particles != null and _speed_streak_particles.emitting


func are_entry_particles_emitting() -> bool:
	return _entry_particles != null and _entry_particles.emitting


func are_storm_particles_emitting() -> bool:
	return _storm_particles != null and _storm_particles.emitting


func _apply_wind_visibility(visible: bool) -> void:
	for band: ColorRect in _wind_bands:
		if band != null:
			band.visible = visible
	if not visible:
		_wind_elapsed_seconds = 0.0


func _apply_radar_visibility(visible: bool) -> void:
	if _radar_pressure_tint != null:
		_radar_pressure_tint.visible = visible
		if not visible:
			_radar_pressure_tint.color.a = 0.0
	for sweep: ColorRect in _radar_sweeps:
		if sweep != null:
			sweep.visible = visible
	if not visible:
		_radar_elapsed_seconds = 0.0


func _set_environment_particles(segment_id: StringName) -> void:
	if _storm_particles != null:
		_storm_particles.emitting = segment_id == &"red_sand_storm_layer"


func _update_environment_tint(delta: float) -> void:
	var blend: float = 1.0 - exp(-maxf(delta, 0.0) * 4.0)
	_current_tint = _current_tint.lerp(_base_tint, blend)
	if _environment_tint != null:
		_environment_tint.color = _current_tint


func _refresh_music_target() -> void:
	_target_music_intensity = maxf(
		_segment_music_intensity,
		_radar_pressure * (1.0 if _radar_locked else 0.82)
	)
	_target_music_intensity = clampf(_target_music_intensity, 0.0, 1.0)


func _update_music_mix(delta: float) -> void:
	_music_intensity = move_toward(
		_music_intensity,
		_target_music_intensity,
		maxf(delta, 0.0) * 0.9
	)
	if _music_audio == null:
		return
	_music_audio.volume_db = lerpf(
		MUSIC_QUIET_VOLUME_DB,
		MUSIC_DANGER_VOLUME_DB,
		_music_intensity
	)
	_music_audio.pitch_scale = lerpf(0.94, 1.06, _music_intensity)


func _update_wind_bands(delta: float) -> void:
	if _wind_bands.is_empty() or not _wind_bands[0].visible:
		return
	_wind_elapsed_seconds += delta
	var pressure: float = clampf(_wind_acceleration.length() / 100.0, 0.15, 1.0)
	var drift_speed: float = 80.0 + pressure * 180.0
	for index: int in _wind_bands.size():
		var band: ColorRect = _wind_bands[index]
		if band == null:
			continue
		band.position.x = fposmod(
			_wind_elapsed_seconds * drift_speed + float(index) * 250.0,
			760.0
		) - 80.0
		band.modulate.a = 0.16 + pressure * 0.24


func _update_radar_feedback(delta: float) -> void:
	if _radar_pressure <= 0.0 or _radar_sweeps.is_empty():
		return
	_radar_elapsed_seconds += delta
	var sweep_speed: float = 90.0 + _radar_pressure * 210.0
	for index: int in _radar_sweeps.size():
		var sweep: ColorRect = _radar_sweeps[index]
		if sweep == null:
			continue
		sweep.position.y = fposmod(
			_radar_elapsed_seconds * sweep_speed + float(index) * 190.0,
			400.0
		) - 20.0
		sweep.modulate.a = (
			0.52 + _radar_pressure * 0.48
			if _radar_locked
			else 0.24 + _radar_pressure * 0.46
		)


func _update_radar_pulse(delta: float) -> void:
	if _radar_pulse_flash == null or _radar_pulse_remaining <= 0.0:
		return
	_radar_pulse_remaining = maxf(_radar_pulse_remaining - delta, 0.0)
	var fade: float = _radar_pulse_remaining / RADAR_PULSE_SECONDS
	var flash_color: Color = _radar_pulse_flash.color
	flash_color.a = _radar_pulse_peak_alpha * fade
	_radar_pulse_flash.color = flash_color


func _clear_radar_pulse() -> void:
	_radar_pulse_remaining = 0.0
	_radar_pulse_peak_alpha = 0.0
	if _radar_pulse_flash != null:
		_radar_pulse_flash.color.a = 0.0
	if _radar_pulse_audio != null:
		_radar_pulse_audio.stop()


func _update_lightning_flash(delta: float) -> void:
	if _lightning_flash == null or _lightning_flash_remaining <= 0.0:
		return
	_lightning_flash_remaining = maxf(_lightning_flash_remaining - delta, 0.0)
	var fade: float = _lightning_flash_remaining / LIGHTNING_FLASH_SECONDS
	var flash_color: Color = _lightning_flash.color
	flash_color.a = _lightning_flash_peak_alpha * fade
	_lightning_flash.color = flash_color


func _set_ambience_stream(signature: StringName) -> void:
	if _ambience_audio == null:
		return
	var stream: AudioStreamWAV = _ambience_cache.get(signature) as AudioStreamWAV
	if stream == null:
		stream = _create_ambience_stream(signature)
		_ambience_cache[signature] = stream
	_ambience_audio.stream = stream
	if DisplayServer.get_name() != "headless":
		_ambience_audio.play()


func _resolve_audio_signature(segment_id: StringName) -> StringName:
	match segment_id:
		&"red_sand_system_edge":
			return &"space_quiet"
		&"red_sand_asteroid_lane":
			return &"debris_tension"
		&"red_sand_near_orbit":
			return &"approach_pull"
		&"red_sand_atmosphere_edge":
			return &"upper_air"
		&"red_sand_storm_layer":
			return &"storm_pressure"
		&"red_sand_low_altitude_control":
			return &"surface_dust"
		&"red_sand_landing_preparation":
			return &"lower_wind"
		&"red_sand_landing_approach":
			return &"landing_beacon"
	return &"space_quiet"


func _resolve_music_intensity(segment_id: StringName) -> float:
	match segment_id:
		&"red_sand_system_edge":
			return 0.08
		&"red_sand_asteroid_lane":
			return 0.55
		&"red_sand_near_orbit":
			return 0.28
		&"red_sand_atmosphere_edge":
			return 0.62
		&"red_sand_storm_layer":
			return 1.0
		&"red_sand_low_altitude_control":
			return 0.68
		&"red_sand_landing_preparation":
			return 0.38
		&"red_sand_landing_approach":
			return 0.32
	return 0.08


func _resolve_tint(segment_id: StringName) -> Color:
	match segment_id:
		&"red_sand_asteroid_lane":
			return Color(0.08, 0.1, 0.18, 0.035)
		&"red_sand_near_orbit":
			return Color(0.08, 0.2, 0.26, 0.035)
		&"red_sand_atmosphere_edge":
			return Color(0.58, 0.2, 0.08, 0.055)
		&"red_sand_storm_layer":
			return Color(0.24, 0.12, 0.36, 0.13)
		&"red_sand_low_altitude_control":
			return Color(0.56, 0.22, 0.09, 0.075)
		&"red_sand_landing_preparation", &"red_sand_landing_approach":
			return Color(0.48, 0.18, 0.07, 0.06)
	return Color.TRANSPARENT


func _create_ambience_stream(signature: StringName) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AMBIENCE_SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var frame_count: int = maxi(int(AMBIENCE_SAMPLE_RATE * AMBIENCE_LOOP_SECONDS), 1)
	stream.loop_begin = 0
	stream.loop_end = frame_count
	var tone_settings: Vector2 = _resolve_tone_settings(signature)
	var audio_data: PackedByteArray = PackedByteArray()
	audio_data.resize(frame_count * 2)
	for frame_index: int in frame_count:
		var time_seconds: float = float(frame_index) / float(AMBIENCE_SAMPLE_RATE)
		var base_tone: float = sin(TAU * tone_settings.x * time_seconds) * 0.12
		var texture: float = (
			sin(TAU * tone_settings.x * 2.03 * time_seconds + 0.4)
			+ sin(TAU * tone_settings.x * 3.17 * time_seconds + 1.1) * 0.45
		) * tone_settings.y
		var sample: float = clampf(base_tone + texture, -0.45, 0.45)
		var encoded_sample: int = int(round(sample * 32767.0)) & 0xffff
		audio_data[frame_index * 2] = encoded_sample & 0xff
		audio_data[frame_index * 2 + 1] = (encoded_sample >> 8) & 0xff
	stream.data = audio_data
	return stream


func _resolve_tone_settings(signature: StringName) -> Vector2:
	match signature:
		&"debris_tension":
			return Vector2(61.0, 0.045)
		&"approach_pull":
			return Vector2(72.0, 0.05)
		&"upper_air":
			return Vector2(88.0, 0.075)
		&"storm_pressure":
			return Vector2(43.0, 0.15)
		&"lower_wind":
			return Vector2(67.0, 0.1)
		&"surface_dust":
			return Vector2(54.0, 0.08)
		&"landing_beacon":
			return Vector2(82.0, 0.06)
	return Vector2(48.0, 0.025)


func _create_music_stream() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MUSIC_SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var frame_count: int = maxi(int(MUSIC_SAMPLE_RATE * MUSIC_LOOP_SECONDS), 1)
	stream.loop_begin = 0
	stream.loop_end = frame_count
	var roots: PackedFloat32Array = PackedFloat32Array([
		55.0,
		55.0,
		65.406,
		65.406,
		73.416,
		73.416,
		49.0,
		49.0,
	])
	var intervals: PackedFloat32Array = PackedFloat32Array([2.0, 2.5, 3.0, 2.25])
	var audio_data: PackedByteArray = PackedByteArray()
	audio_data.resize(frame_count * 2)
	for frame_index: int in frame_count:
		var time_seconds: float = float(frame_index) / float(MUSIC_SAMPLE_RATE)
		var step_position: float = fmod(time_seconds, 0.5) / 0.5
		var step_index: int = mini(int(time_seconds / 0.5), roots.size() - 1)
		var root_frequency: float = roots[step_index]
		var pulse_envelope: float = exp(-step_position * 4.8)
		var low_tone: float = sin(TAU * root_frequency * time_seconds) * 0.14
		var fifth_tone: float = (
			sin(TAU * root_frequency * 1.5 * time_seconds + 0.25) * 0.055
		)
		var arpeggio_frequency: float = root_frequency * intervals[step_index % 4]
		var arpeggio: float = (
			sin(TAU * arpeggio_frequency * time_seconds) * pulse_envelope * 0.075
		)
		var shimmer: float = (
			sin(TAU * 0.25 * time_seconds) * sin(TAU * 220.0 * time_seconds) * 0.018
		)
		var sample: float = clampf(
			low_tone + fifth_tone + arpeggio + shimmer,
			-0.48,
			0.48
		)
		var encoded_sample: int = int(round(sample * 32767.0)) & 0xffff
		audio_data[frame_index * 2] = encoded_sample & 0xff
		audio_data[frame_index * 2 + 1] = (encoded_sample >> 8) & 0xff
	stream.data = audio_data
	return stream


func _create_radar_pulse_stream() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RADAR_PULSE_SAMPLE_RATE
	stream.stereo = false
	var frame_count: int = maxi(
		int(RADAR_PULSE_SAMPLE_RATE * RADAR_PULSE_SECONDS),
		1
	)
	var audio_data: PackedByteArray = PackedByteArray()
	audio_data.resize(frame_count * 2)
	for frame_index: int in frame_count:
		var progress: float = float(frame_index) / float(frame_count)
		var time_seconds: float = float(frame_index) / float(RADAR_PULSE_SAMPLE_RATE)
		var envelope: float = exp(-progress * 5.4)
		var frequency: float = lerpf(760.0, 105.0, progress)
		var chirp: float = sin(TAU * frequency * time_seconds) * 0.46
		var static_tone: float = (
			sin(TAU * 941.0 * time_seconds)
			* sin(TAU * 83.0 * time_seconds)
			* 0.18
		)
		var sample: float = clampf(
			(chirp + static_tone) * envelope,
			-0.72,
			0.72
		)
		var encoded_sample: int = int(round(sample * 32767.0)) & 0xffff
		audio_data[frame_index * 2] = encoded_sample & 0xff
		audio_data[frame_index * 2 + 1] = (encoded_sample >> 8) & 0xff
	stream.data = audio_data
	return stream


func _set_mouse_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_set_mouse_passthrough(child)
