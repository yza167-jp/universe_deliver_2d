class_name FlightAltitudeReferenceProvider
extends RefCounted

## Provides the single altitude value consumed by both flight HUD and radar logic.
## World units are currently configured as meters, but the conversion remains tunable.

enum Mode {
	ORBITAL,
	ATMOSPHERE_ENTRY,
	AGL,
}

const ORBITAL_FINAL_SEGMENT_INDEX: int = 2
const ATMOSPHERE_FINAL_SEGMENT_INDEX: int = 4
const HIGH_ALTITUDE_THRESHOLD_METERS: float = 1000.0
const HIGH_ALTITUDE_FALLBACK_METERS: float = 1001.0
## Ground-only layer keeps facility roofs from changing the radar's altitude semantics.
const ALTITUDE_REFERENCE_COLLISION_LAYER: int = 1 << 4

var atmosphere_start_altitude_meters: float = 1800.0
var atmosphere_stage_boundary_altitude_meters: float = 1200.0
var agl_handoff_altitude_meters: float = 1050.0
var agl_smoothing_response_per_second: float = 5.0
var agl_ray_length_meters: float = 4000.0
var world_units_per_meter: float = 1.0
var world_collision_mask: int = ALTITUDE_REFERENCE_COLLISION_LAYER
var ray_origin_offset_world: Vector2 = Vector2.ZERO

var mode: Mode = Mode.ORBITAL
var player_visible_altitude_meters: float = HIGH_ALTITUDE_FALLBACK_METERS
var raw_virtual_altitude_meters: float = 0.0
var raw_terrain_altitude_meters: float = 0.0
var virtual_altitude_valid: bool = false
var terrain_hit_valid: bool = false
var numeric_altitude_valid: bool = false

var _has_initialized_output: bool = false


class TerrainSample:
	extends RefCounted

	var altitude_meters: float = 0.0
	var hit_valid: bool = false


## Updates altitude by casting straight down from the source against the World mask.
func update_from_world(
	segment_index: int,
	segment_progress: float,
	source: CollisionObject2D,
	delta: float
) -> void:
	if resolve_mode(segment_index) != Mode.AGL:
		update_from_terrain_sample(
			segment_index,
			segment_progress,
			0.0,
			false,
			delta
		)
		return
	var sample: TerrainSample = _sample_world(source)
	update_from_terrain_sample(
		segment_index,
		segment_progress,
		sample.altitude_meters,
		sample.hit_valid,
		delta
	)


## Pure sample entry point used by deterministic tests and non-physics integrations.
func update_from_terrain_sample(
	segment_index: int,
	segment_progress: float,
	terrain_altitude_meters: float,
	hit_valid: bool,
	delta: float
) -> void:
	_apply_route_sample(
		segment_index,
		segment_progress,
		terrain_altitude_meters,
		hit_valid,
		delta,
		false
	)


## Restores an exact output without retaining pre-checkpoint smoothing history.
func reset_to_route_state(
	segment_index: int,
	segment_progress: float,
	terrain_altitude_meters: float = 0.0,
	hit_valid: bool = false
) -> void:
	_has_initialized_output = false
	_apply_route_sample(
		segment_index,
		segment_progress,
		terrain_altitude_meters,
		hit_valid,
		0.0,
		true
	)


## World-backed reset companion for checkpoint restoration in the live route.
func reset_to_route_state_from_world(
	segment_index: int,
	segment_progress: float,
	source: CollisionObject2D
) -> void:
	if resolve_mode(segment_index) != Mode.AGL:
		reset_to_route_state(segment_index, segment_progress)
		return
	var sample: TerrainSample = _sample_world(source)
	reset_to_route_state(
		segment_index,
		segment_progress,
		sample.altitude_meters,
		sample.hit_valid
	)


## Canonical final value. HUD and radar must both consume this value.
func get_altitude_meters() -> float:
	return player_visible_altitude_meters


func get_display_altitude_meters() -> float:
	return get_altitude_meters()


func get_hud_altitude_meters() -> float:
	return get_display_altitude_meters()


func get_radar_altitude_meters() -> float:
	return get_altitude_meters()


func has_numeric_altitude() -> bool:
	return numeric_altitude_valid


func is_using_high_altitude_fallback() -> bool:
	return not has_numeric_altitude()


func get_mode_name() -> StringName:
	match mode:
		Mode.ATMOSPHERE_ENTRY:
			return &"ATMOSPHERE_ENTRY"
		Mode.AGL:
			return &"AGL"
		_:
			return &"ORBITAL"


static func resolve_mode(segment_index: int) -> Mode:
	if segment_index <= ORBITAL_FINAL_SEGMENT_INDEX:
		return Mode.ORBITAL
	if segment_index <= ATMOSPHERE_FINAL_SEGMENT_INDEX:
		return Mode.ATMOSPHERE_ENTRY
	return Mode.AGL


func _apply_route_sample(
	segment_index: int,
	segment_progress: float,
	terrain_altitude_meters: float,
	hit_valid: bool,
	delta: float,
	reset_immediately: bool
) -> void:
	mode = resolve_mode(segment_index)
	raw_virtual_altitude_meters = _resolve_virtual_altitude(
		segment_index,
		segment_progress
	)
	virtual_altitude_valid = mode != Mode.ORBITAL
	raw_terrain_altitude_meters = (
		maxf(terrain_altitude_meters, 0.0) if hit_valid else 0.0
	)
	terrain_hit_valid = mode == Mode.AGL and hit_valid

	match mode:
		Mode.ORBITAL:
			_set_high_altitude_fallback()
		Mode.ATMOSPHERE_ENTRY:
			player_visible_altitude_meters = raw_virtual_altitude_meters
			numeric_altitude_valid = true
		Mode.AGL:
			if not terrain_hit_valid:
				_set_high_altitude_fallback()
			elif reset_immediately or not _has_initialized_output:
				player_visible_altitude_meters = raw_terrain_altitude_meters
				numeric_altitude_valid = true
			else:
				var blend: float = 1.0 - exp(
					-maxf(agl_smoothing_response_per_second, 0.0)
					* maxf(delta, 0.0)
				)
				player_visible_altitude_meters = lerpf(
					player_visible_altitude_meters,
					raw_terrain_altitude_meters,
					blend
				)
				numeric_altitude_valid = true
	_has_initialized_output = true


func _resolve_virtual_altitude(segment_index: int, segment_progress: float) -> float:
	var progress: float = clampf(segment_progress, 0.0, 1.0)
	if segment_index <= ORBITAL_FINAL_SEGMENT_INDEX:
		return 0.0
	if segment_index == ORBITAL_FINAL_SEGMENT_INDEX + 1:
		return lerpf(
			atmosphere_start_altitude_meters,
			atmosphere_stage_boundary_altitude_meters,
			progress
		)
	if segment_index == ATMOSPHERE_FINAL_SEGMENT_INDEX:
		return lerpf(
			atmosphere_stage_boundary_altitude_meters,
			agl_handoff_altitude_meters,
			progress
		)
	return agl_handoff_altitude_meters


func _set_high_altitude_fallback() -> void:
	player_visible_altitude_meters = HIGH_ALTITUDE_FALLBACK_METERS
	numeric_altitude_valid = false


func _sample_world(source: CollisionObject2D) -> TerrainSample:
	var sample: TerrainSample = TerrainSample.new()
	if source == null or not source.is_inside_tree():
		return sample
	var world: World2D = source.get_world_2d()
	if world == null:
		return sample
	var safe_world_units_per_meter: float = maxf(world_units_per_meter, 0.001)
	var ray_length_world: float = (
		maxf(agl_ray_length_meters, 0.0) * safe_world_units_per_meter
	)
	if ray_length_world <= 0.0:
		return sample

	var ray_start: Vector2 = source.global_position + ray_origin_offset_world
	var ray_end: Vector2 = ray_start + Vector2.DOWN * ray_length_world
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		ray_start,
		ray_end,
		world_collision_mask
	)
	var exclusions: Array[RID] = []
	exclusions.append(source.get_rid())
	query.exclude = exclusions
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return sample
	var hit_position_value: Variant = hit.get("position", null)
	if not hit_position_value is Vector2:
		return sample
	var hit_position: Vector2 = hit_position_value as Vector2
	sample.altitude_meters = ray_start.distance_to(hit_position) / safe_world_units_per_meter
	sample.hit_valid = true
	return sample
