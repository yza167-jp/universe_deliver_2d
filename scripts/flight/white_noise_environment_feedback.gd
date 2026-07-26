class_name WhiteNoiseEnvironmentFeedback
extends CanvasLayer

## Scene-local production-placeholder ambience and bounded snow presentation.

const SAMPLE_RATE: int = 11025
const AMBIENCE_SECONDS: float = 1.5
const MOTIF_SECONDS: float = 3.2
const SILENT_VOLUME_DB: float = -80.0
const SAFE_VOLUME_DB: float = -24.0
const STORM_VOLUME_DB: float = -18.0
const ARCHIVE_VOLUME_DB: float = -21.0
const DEFAULT_SNOW_AMOUNT: int = 58
const REDUCED_SNOW_AMOUNT: int = 24
const PRESENTATION_SIGNATURE: StringName = (
	&"white_noise_safe_storm_archive_motif"
)

@onready var _snow_particles: CPUParticles2D = %SnowParticles
@onready var _safe_audio: AudioStreamPlayer = %SafeAmbienceAudio
@onready var _storm_audio: AudioStreamPlayer = %StormAmbienceAudio
@onready var _archive_audio: AudioStreamPlayer = %ArchiveAmbienceAudio
@onready var _motif_audio: AudioStreamPlayer = %MemoryMotifAudio

var _settings_service: SettingsServiceModel
var _active_segment_id: StringName = &""
var _target_safe_volume_db: float = SILENT_VOLUME_DB
var _target_storm_volume_db: float = SILENT_VOLUME_DB
var _target_archive_volume_db: float = SILENT_VOLUME_DB
var _high_contrast_enabled: bool = (
	LocalSettingsData.DEFAULT_HIGH_CONTRAST_TERRAIN
)
var _motif_play_count: int = 0


func _ready() -> void:
	_set_mouse_passthrough(self)
	_safe_audio.stream = _create_ambience_stream(&"safe")
	_storm_audio.stream = _create_ambience_stream(&"storm")
	_archive_audio.stream = _create_ambience_stream(&"archive")
	_motif_audio.stream = _create_memory_motif_stream()
	for player: AudioStreamPlayer in [
		_safe_audio,
		_storm_audio,
		_archive_audio,
	]:
		player.volume_db = SILENT_VOLUME_DB
		if DisplayServer.get_name() != "headless":
			player.play()
	refresh_accessibility()


func _exit_tree() -> void:
	_disconnect_settings_service()
	for player: AudioStreamPlayer in [
		_safe_audio,
		_storm_audio,
		_archive_audio,
		_motif_audio,
	]:
		if player != null:
			player.stop()
	if _snow_particles != null:
		_snow_particles.emitting = false


func _process(delta: float) -> void:
	var blend_step: float = maxf(delta, 0.0) * 24.0
	_safe_audio.volume_db = move_toward(
		_safe_audio.volume_db,
		_target_safe_volume_db,
		blend_step
	)
	_storm_audio.volume_db = move_toward(
		_storm_audio.volume_db,
		_target_storm_volume_db,
		blend_step
	)
	_archive_audio.volume_db = move_toward(
		_archive_audio.volume_db,
		_target_archive_volume_db,
		blend_step
	)


func bind(settings_service: SettingsServiceModel) -> void:
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
		_settings_service.assist_option_changed.connect(
			_on_assist_option_changed
		)
	refresh_accessibility()


func set_segment(segment: FlightRouteSegment) -> void:
	if segment == null:
		return
	var previous_segment_id: StringName = _active_segment_id
	_active_segment_id = segment.id
	_target_safe_volume_db = SILENT_VOLUME_DB
	_target_storm_volume_db = SILENT_VOLUME_DB
	_target_archive_volume_db = SILENT_VOLUME_DB
	match _active_segment_id:
		&"white_noise_orbital_approach":
			_target_safe_volume_db = -29.0
		&"white_noise_open_icefield", &"white_noise_ice_rift_split":
			_target_safe_volume_db = SAFE_VOLUME_DB
		&"white_noise_aurora_blizzard":
			_target_safe_volume_db = -31.0
			_target_storm_volume_db = STORM_VOLUME_DB
		&"white_noise_archive_descent":
			_target_safe_volume_db = -34.0
			_target_archive_volume_db = ARCHIVE_VOLUME_DB
		&"white_noise_landing_approach":
			_target_safe_volume_db = -28.0
			_target_archive_volume_db = -27.0
	_apply_snow_state()
	if (
		previous_segment_id != _active_segment_id
		and _active_segment_id in [
			&"white_noise_open_icefield",
			&"white_noise_archive_descent",
		]
	):
		_play_memory_motif()


func refresh_accessibility() -> void:
	_high_contrast_enabled = (
		LocalSettingsData.DEFAULT_HIGH_CONTRAST_TERRAIN
	)
	if _settings_service != null:
		_high_contrast_enabled = (
			_settings_service.settings.high_contrast_terrain
		)
	_apply_snow_state()


func get_presentation_signature() -> StringName:
	return PRESENTATION_SIGNATURE


func get_active_segment_id() -> StringName:
	return _active_segment_id


func get_snow_particle_amount() -> int:
	return 0 if _snow_particles == null else _snow_particles.amount


func get_snow_particle_alpha() -> float:
	return 0.0 if _snow_particles == null else _snow_particles.modulate.a


func is_snow_emitting() -> bool:
	return _snow_particles != null and _snow_particles.emitting


func get_layer_target_volumes() -> Vector3:
	return Vector3(
		_target_safe_volume_db,
		_target_storm_volume_db,
		_target_archive_volume_db
	)


func get_safe_audio() -> AudioStreamPlayer:
	return _safe_audio


func get_storm_audio() -> AudioStreamPlayer:
	return _storm_audio


func get_archive_audio() -> AudioStreamPlayer:
	return _archive_audio


func get_motif_audio() -> AudioStreamPlayer:
	return _motif_audio


func get_motif_play_count() -> int:
	return _motif_play_count


func is_reduced_visual_noise_enabled() -> bool:
	return _high_contrast_enabled


func _apply_snow_state() -> void:
	if _snow_particles == null:
		return
	_snow_particles.amount = (
		REDUCED_SNOW_AMOUNT
		if _high_contrast_enabled
		else DEFAULT_SNOW_AMOUNT
	)
	_snow_particles.modulate.a = 0.38 if _high_contrast_enabled else 0.72
	_snow_particles.emitting = _active_segment_id in [
		&"white_noise_open_icefield",
		&"white_noise_ice_rift_split",
		&"white_noise_aurora_blizzard",
		&"white_noise_landing_approach",
	]
	if _active_segment_id == &"white_noise_aurora_blizzard":
		_snow_particles.speed_scale = 1.38
	elif _active_segment_id == &"white_noise_landing_approach":
		_snow_particles.speed_scale = 0.72
	else:
		_snow_particles.speed_scale = 0.92


func _play_memory_motif() -> void:
	_motif_play_count += 1
	if DisplayServer.get_name() != "headless":
		_motif_audio.play()


func _on_assist_option_changed(
	option_id: StringName,
	_enabled: bool
) -> void:
	if option_id == SettingsServiceModel.HIGH_CONTRAST_TERRAIN:
		refresh_accessibility()


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


func _create_ambience_stream(signature: StringName) -> AudioStreamWAV:
	var stream: AudioStreamWAV = _create_base_stream(AMBIENCE_SECONDS, true)
	var frame_count: int = stream.loop_end
	var audio_data: PackedByteArray = PackedByteArray()
	audio_data.resize(frame_count * 2)
	for frame_index: int in frame_count:
		var time_seconds: float = float(frame_index) / float(SAMPLE_RATE)
		var sample: float = _sample_ambience(signature, time_seconds)
		_write_sample(audio_data, frame_index, sample)
	stream.data = audio_data
	return stream


func _sample_ambience(signature: StringName, time_seconds: float) -> float:
	match signature:
		&"storm":
			var pressure: float = sin(TAU * 38.0 * time_seconds) * 0.11
			var static_texture: float = (
				sin(TAU * 173.0 * time_seconds)
				* sin(TAU * 11.0 * time_seconds + 0.4)
				+ sin(TAU * 257.0 * time_seconds + 0.9) * 0.56
			) * 0.12
			return clampf(pressure + static_texture, -0.46, 0.46)
		&"archive":
			var structure: float = sin(TAU * 52.0 * time_seconds) * 0.1
			var relay_pulse: float = (
				sin(TAU * 156.0 * time_seconds)
				* pow(maxf(sin(TAU * 1.333 * time_seconds), 0.0), 10.0)
				* 0.13
			)
			return clampf(structure + relay_pulse, -0.38, 0.38)
	var wind: float = (
		sin(TAU * 61.0 * time_seconds)
		+ sin(TAU * 97.0 * time_seconds + 0.7) * 0.48
	) * 0.055
	var ice_resonance: float = (
		sin(TAU * 244.0 * time_seconds)
		* pow(maxf(sin(TAU * 0.667 * time_seconds), 0.0), 18.0)
		* 0.11
	)
	return clampf(wind + ice_resonance, -0.32, 0.32)


func _create_memory_motif_stream() -> AudioStreamWAV:
	var stream: AudioStreamWAV = _create_base_stream(MOTIF_SECONDS, false)
	var frame_count: int = maxi(int(SAMPLE_RATE * MOTIF_SECONDS), 1)
	var frequencies: PackedFloat32Array = PackedFloat32Array([
		146.83,
		174.61,
		220.0,
		174.61,
		146.83,
		130.81,
		146.83,
		110.0,
	])
	var audio_data: PackedByteArray = PackedByteArray()
	audio_data.resize(frame_count * 2)
	for frame_index: int in frame_count:
		var time_seconds: float = float(frame_index) / float(SAMPLE_RATE)
		var step_index: int = mini(
			int(time_seconds / 0.4),
			frequencies.size() - 1
		)
		var step_progress: float = fmod(time_seconds, 0.4) / 0.4
		var envelope: float = exp(-step_progress * 3.7)
		var frequency: float = frequencies[step_index]
		var sample: float = (
			sin(TAU * frequency * time_seconds) * 0.16
			+ sin(TAU * frequency * 2.0 * time_seconds + 0.3) * 0.045
		) * envelope
		_write_sample(audio_data, frame_index, sample)
	stream.data = audio_data
	return stream


func _create_base_stream(
	duration_seconds: float,
	looping: bool
) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	var frame_count: int = maxi(int(SAMPLE_RATE * duration_seconds), 1)
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frame_count
	return stream


func _write_sample(
	audio_data: PackedByteArray,
	frame_index: int,
	sample: float
) -> void:
	var encoded_sample: int = (
		int(round(clampf(sample, -0.76, 0.76) * 32767.0)) & 0xffff
	)
	audio_data[frame_index * 2] = encoded_sample & 0xff
	audio_data[frame_index * 2 + 1] = (encoded_sample >> 8) & 0xff


func _set_mouse_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_set_mouse_passthrough(child)
