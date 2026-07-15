class_name LocalSettingsData
extends RefCounted

const DEFAULT_MASTER_VOLUME: float = 1.0
const DEFAULT_MUSIC_VOLUME: float = 1.0
const DEFAULT_SFX_VOLUME: float = 1.0
const DEFAULT_SCREEN_SHAKE_STRENGTH: float = 1.0
const DEFAULT_TEXT_SPEED: float = 42.0
const DEFAULT_SLOW_MOTION_ASSIST: bool = false
const DEFAULT_ROUTE_HINTS_ENABLED: bool = true
const DEFAULT_HIGH_CONTRAST_TERRAIN: bool = false
const DEFAULT_FLIGHT_ASSIST_STRENGTH: float = 0.75

const MIN_TEXT_SPEED: float = 12.0
const MAX_TEXT_SPEED: float = 120.0

var master_volume: float = DEFAULT_MASTER_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var screen_shake_strength: float = DEFAULT_SCREEN_SHAKE_STRENGTH
var text_speed: float = DEFAULT_TEXT_SPEED
var slow_motion_assist: bool = DEFAULT_SLOW_MOTION_ASSIST
var route_hints_enabled: bool = DEFAULT_ROUTE_HINTS_ENABLED
var high_contrast_terrain: bool = DEFAULT_HIGH_CONTRAST_TERRAIN
var flight_assist_strength: float = DEFAULT_FLIGHT_ASSIST_STRENGTH


func reset_to_defaults() -> void:
	master_volume = DEFAULT_MASTER_VOLUME
	music_volume = DEFAULT_MUSIC_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME
	screen_shake_strength = DEFAULT_SCREEN_SHAKE_STRENGTH
	text_speed = DEFAULT_TEXT_SPEED
	slow_motion_assist = DEFAULT_SLOW_MOTION_ASSIST
	route_hints_enabled = DEFAULT_ROUTE_HINTS_ENABLED
	high_contrast_terrain = DEFAULT_HIGH_CONTRAST_TERRAIN
	flight_assist_strength = DEFAULT_FLIGHT_ASSIST_STRENGTH


func sanitize() -> void:
	master_volume = clampf(master_volume, 0.0, 1.0)
	music_volume = clampf(music_volume, 0.0, 1.0)
	sfx_volume = clampf(sfx_volume, 0.0, 1.0)
	screen_shake_strength = clampf(screen_shake_strength, 0.0, 1.0)
	text_speed = clampf(text_speed, MIN_TEXT_SPEED, MAX_TEXT_SPEED)
	flight_assist_strength = clampf(flight_assist_strength, 0.0, 1.0)


func read_from_config(config: ConfigFile, section: String) -> void:
	master_volume = float(config.get_value(section, "master_volume", DEFAULT_MASTER_VOLUME))
	music_volume = float(config.get_value(section, "music_volume", DEFAULT_MUSIC_VOLUME))
	sfx_volume = float(config.get_value(section, "sfx_volume", DEFAULT_SFX_VOLUME))
	screen_shake_strength = float(
		config.get_value(section, "screen_shake_strength", DEFAULT_SCREEN_SHAKE_STRENGTH)
	)
	text_speed = float(config.get_value(section, "text_speed", DEFAULT_TEXT_SPEED))
	slow_motion_assist = bool(
		config.get_value(section, "slow_motion_assist", DEFAULT_SLOW_MOTION_ASSIST)
	)
	route_hints_enabled = bool(
		config.get_value(section, "route_hints_enabled", DEFAULT_ROUTE_HINTS_ENABLED)
	)
	high_contrast_terrain = bool(
		config.get_value(section, "high_contrast_terrain", DEFAULT_HIGH_CONTRAST_TERRAIN)
	)
	flight_assist_strength = float(
		config.get_value(
			section,
			"flight_assist_strength",
			DEFAULT_FLIGHT_ASSIST_STRENGTH
		)
	)
	sanitize()


func write_to_config(config: ConfigFile, section: String) -> void:
	config.set_value(section, "master_volume", master_volume)
	config.set_value(section, "music_volume", music_volume)
	config.set_value(section, "sfx_volume", sfx_volume)
	config.set_value(section, "screen_shake_strength", screen_shake_strength)
	config.set_value(section, "text_speed", text_speed)
	config.set_value(section, "slow_motion_assist", slow_motion_assist)
	config.set_value(section, "route_hints_enabled", route_hints_enabled)
	config.set_value(section, "high_contrast_terrain", high_contrast_terrain)
	config.set_value(section, "flight_assist_strength", flight_assist_strength)
