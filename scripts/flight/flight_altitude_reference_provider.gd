class_name FlightAltitudeReferenceProvider
extends RefCounted

## Provides the single altitude value consumed by both flight HUD and radar logic.
## World units are currently configured as meters, but the conversion remains tunable.

enum Mode {
	ORBITAL,
	ATMOSPHERE_ENTRY,
	AGL,
}

enum Source {
	HIGH_ALTITUDE,
	VIRTUAL_PROFILE,
	TERRAIN_RAYCAST,
	TERRAIN_PROFILE_FALLBACK,
	LAST_VALID_AGL,
}

const ORBITAL_FINAL_SEGMENT_INDEX: int = 2
const ATMOSPHERE_FINAL_SEGMENT_INDEX: int = 4
const HIGH_ALTITUDE_THRESHOLD_METERS: float = 1000.0
const HIGH_ALTITUDE_FALLBACK_METERS: float = 1001.0
const MINIMUM_VALID_AGL_METERS: float = 1.0
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
var source: Source = Source.HIGH_ALTITUDE
var player_visible_altitude_meters: float = HIGH_ALTITUDE_FALLBACK_METERS
var raw_virtual_altitude_meters: float = 0.0
var raw_terrain_altitude_meters: float = 0.0
var raw_raycast_altitude_meters: float = 0.0
var raw_profile_altitude_meters: float = 0.0
var final_agl_altitude_meters: float = 0.0
var virtual_altitude_valid: bool = false
var terrain_hit_valid: bool = false
var profile_altitude_valid: bool = false
var altitude_source_valid: bool = false
var numeric_altitude_valid: bool = false
var ground_node_name: StringName = &""
var ground_node_path: NodePath = NodePath()
var sample_failure_reason: StringName = &""

var _has_initialized_output: bool = false
var _has_last_valid_agl: bool = false
var _last_valid_agl_meters: float = 0.0


class TerrainSample:
	extends RefCounted

	var altitude_meters: float = 0.0
	var hit_valid: bool = false
	var collider_name: StringName = &""
	var collider_path: NodePath = NodePath()
	var failure_reason: StringName = &""


class ProfileSample:
	extends RefCounted

	var altitude_meters: float = 0.0
	var valid: bool = false
	var failure_reason: StringName = &""


## Updates altitude by casting straight down from the source against the World mask.
func update_from_world(
	segment_index: int,
	segment_progress: float,
	source: CollisionObject2D,
	delta: float,
	profile_ground_y_world: float = INF
) -> void:
	if resolve_mode(segment_index) != Mode.AGL:
		update_from_altitude_samples(
			segment_index,
			segment_progress,
			0.0,
			false,
			0.0,
			false,
			delta
		)
		return
	var raycast_sample: TerrainSample = _sample_world(source)
	var profile_sample: ProfileSample = _sample_profile(
		source,
		profile_ground_y_world
	)
	_apply_route_samples(
		segment_index,
		segment_progress,
		raycast_sample,
		profile_sample,
		delta,
		false
	)


## Pure sample entry point used by deterministic tests and non-physics integrations.
func update_from_terrain_sample(
	segment_index: int,
	segment_progress: float,
	terrain_altitude_meters: float,
	hit_valid: bool,
	delta: float
) -> void:
	update_from_altitude_samples(
		segment_index,
		segment_progress,
		terrain_altitude_meters,
		hit_valid,
		0.0,
		false,
		delta
	)


## Pure dual-source entry point used to verify ray/profile fallback behavior.
func update_from_altitude_samples(
	segment_index: int,
	segment_progress: float,
	raycast_altitude_meters: float,
	raycast_hit_valid: bool,
	profile_altitude_meters: float,
	profile_valid: bool,
	delta: float
) -> void:
	var raycast_sample: TerrainSample = TerrainSample.new()
	raycast_sample.altitude_meters = raycast_altitude_meters
	raycast_sample.hit_valid = raycast_hit_valid
	raycast_sample.failure_reason = &"" if raycast_hit_valid else &"RAY_MISS"
	var profile_sample: ProfileSample = ProfileSample.new()
	profile_sample.altitude_meters = profile_altitude_meters
	profile_sample.valid = profile_valid
	profile_sample.failure_reason = &"" if profile_valid else &"PROFILE_UNAVAILABLE"
	_apply_route_samples(
		segment_index,
		segment_progress,
		raycast_sample,
		profile_sample,
		delta,
		false
	)


## Restores an exact output without retaining pre-checkpoint smoothing history.
func reset_to_route_state(
	segment_index: int,
	segment_progress: float,
	terrain_altitude_meters: float = 0.0,
	hit_valid: bool = false,
	profile_altitude_meters: float = 0.0,
	profile_valid: bool = false
) -> void:
	_has_initialized_output = false
	if resolve_mode(segment_index) != Mode.AGL:
		_has_last_valid_agl = false
		_last_valid_agl_meters = 0.0
	var raycast_sample: TerrainSample = TerrainSample.new()
	raycast_sample.altitude_meters = terrain_altitude_meters
	raycast_sample.hit_valid = hit_valid
	raycast_sample.failure_reason = &"" if hit_valid else &"RAY_MISS"
	var profile_sample: ProfileSample = ProfileSample.new()
	profile_sample.altitude_meters = profile_altitude_meters
	profile_sample.valid = profile_valid
	profile_sample.failure_reason = &"" if profile_valid else &"PROFILE_UNAVAILABLE"
	_apply_route_samples(
		segment_index,
		segment_progress,
		raycast_sample,
		profile_sample,
		0.0,
		true
	)


## World-backed reset companion for checkpoint restoration in the live route.
func reset_to_route_state_from_world(
	segment_index: int,
	segment_progress: float,
	source: CollisionObject2D,
	profile_ground_y_world: float = INF
) -> void:
	if resolve_mode(segment_index) != Mode.AGL:
		reset_to_route_state(segment_index, segment_progress)
		return
	_has_initialized_output = false
	_apply_route_samples(
		segment_index,
		segment_progress,
		_sample_world(source),
		_sample_profile(source, profile_ground_y_world),
		0.0,
		true
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


func get_source_name() -> StringName:
	match source:
		Source.VIRTUAL_PROFILE:
			return &"VIRTUAL_PROFILE"
		Source.TERRAIN_RAYCAST:
			return &"TERRAIN_RAYCAST"
		Source.TERRAIN_PROFILE_FALLBACK:
			return &"TERRAIN_PROFILE_FALLBACK"
		Source.LAST_VALID_AGL:
			return &"LAST_VALID_AGL"
		_:
			return &"HIGH_ALTITUDE"


func get_ground_node_name() -> StringName:
	return ground_node_name


func get_ground_node_path() -> NodePath:
	return ground_node_path


func get_failure_reason() -> StringName:
	return sample_failure_reason


static func resolve_mode(segment_index: int) -> Mode:
	if segment_index <= ORBITAL_FINAL_SEGMENT_INDEX:
		return Mode.ORBITAL
	if segment_index <= ATMOSPHERE_FINAL_SEGMENT_INDEX:
		return Mode.ATMOSPHERE_ENTRY
	return Mode.AGL


func _apply_route_samples(
	segment_index: int,
	segment_progress: float,
	raycast_sample: TerrainSample,
	profile_sample: ProfileSample,
	delta: float,
	reset_immediately: bool
) -> void:
	mode = resolve_mode(segment_index)
	raw_virtual_altitude_meters = _resolve_virtual_altitude(
		segment_index,
		segment_progress
	)
	virtual_altitude_valid = mode != Mode.ORBITAL
	raw_raycast_altitude_meters = (
		maxf(raycast_sample.altitude_meters, MINIMUM_VALID_AGL_METERS)
		if raycast_sample != null and raycast_sample.hit_valid
		else 0.0
	)
	raw_profile_altitude_meters = (
		maxf(profile_sample.altitude_meters, MINIMUM_VALID_AGL_METERS)
		if profile_sample != null and profile_sample.valid
		else 0.0
	)
	terrain_hit_valid = (
		mode == Mode.AGL
		and raycast_sample != null
		and raycast_sample.hit_valid
	)
	profile_altitude_valid = (
		mode == Mode.AGL
		and profile_sample != null
		and profile_sample.valid
	)
	ground_node_name = (
		raycast_sample.collider_name if terrain_hit_valid else &""
	)
	ground_node_path = (
		raycast_sample.collider_path if terrain_hit_valid else NodePath()
	)
	altitude_source_valid = false
	sample_failure_reason = &""

	match mode:
		Mode.ORBITAL:
			_set_high_altitude_fallback()
		Mode.ATMOSPHERE_ENTRY:
			source = Source.VIRTUAL_PROFILE
			player_visible_altitude_meters = raw_virtual_altitude_meters
			final_agl_altitude_meters = 0.0
			raw_terrain_altitude_meters = 0.0
			altitude_source_valid = true
			numeric_altitude_valid = true
		Mode.AGL:
			var target_altitude: float = _resolve_agl_target(
				raycast_sample,
				profile_sample
			)
			if not altitude_source_valid:
				_set_high_altitude_fallback()
			else:
				raw_terrain_altitude_meters = target_altitude
				if reset_immediately or not _has_initialized_output:
					player_visible_altitude_meters = target_altitude
				else:
					var blend: float = 1.0 - exp(
						-maxf(agl_smoothing_response_per_second, 0.0)
						* maxf(delta, 0.0)
					)
					player_visible_altitude_meters = lerpf(
						player_visible_altitude_meters,
						target_altitude,
						blend
					)
				player_visible_altitude_meters = maxf(
					player_visible_altitude_meters,
					MINIMUM_VALID_AGL_METERS
				)
				final_agl_altitude_meters = player_visible_altitude_meters
				_last_valid_agl_meters = player_visible_altitude_meters
				_has_last_valid_agl = true
				numeric_altitude_valid = true
	_has_initialized_output = true


func _resolve_agl_target(
	raycast_sample: TerrainSample,
	profile_sample: ProfileSample
) -> float:
	if terrain_hit_valid:
		source = Source.TERRAIN_RAYCAST
		altitude_source_valid = true
		return raw_raycast_altitude_meters
	if profile_altitude_valid:
		source = Source.TERRAIN_PROFILE_FALLBACK
		altitude_source_valid = true
		sample_failure_reason = (
			profile_sample.failure_reason
			if profile_sample != null and not profile_sample.failure_reason.is_empty()
			else (
				raycast_sample.failure_reason
				if raycast_sample != null
				and not raycast_sample.failure_reason.is_empty()
				else &"RAY_MISS"
			)
		)
		return raw_profile_altitude_meters
	if _has_last_valid_agl:
		source = Source.LAST_VALID_AGL
		altitude_source_valid = true
		sample_failure_reason = &"RAY_AND_PROFILE_UNAVAILABLE"
		return maxf(_last_valid_agl_meters, MINIMUM_VALID_AGL_METERS)
	source = Source.HIGH_ALTITUDE
	altitude_source_valid = false
	sample_failure_reason = &"NO_VALID_AGL_SOURCE"
	return HIGH_ALTITUDE_FALLBACK_METERS


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
	source = Source.HIGH_ALTITUDE
	player_visible_altitude_meters = HIGH_ALTITUDE_FALLBACK_METERS
	final_agl_altitude_meters = 0.0
	raw_terrain_altitude_meters = 0.0
	altitude_source_valid = mode == Mode.ORBITAL
	numeric_altitude_valid = false


func _sample_world(source: CollisionObject2D) -> TerrainSample:
	var sample: TerrainSample = TerrainSample.new()
	if source == null or not source.is_inside_tree():
		sample.failure_reason = &"SOURCE_NOT_IN_TREE"
		return sample
	var world: World2D = source.get_world_2d()
	if world == null:
		sample.failure_reason = &"WORLD_UNAVAILABLE"
		return sample
	var safe_world_units_per_meter: float = maxf(world_units_per_meter, 0.001)
	var ray_length_world: float = (
		maxf(agl_ray_length_meters, 0.0) * safe_world_units_per_meter
	)
	if ray_length_world <= 0.0:
		sample.failure_reason = &"RAY_LENGTH_INVALID"
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
		sample.failure_reason = &"RAY_MISS"
		return sample
	var hit_position_value: Variant = hit.get("position", null)
	if not hit_position_value is Vector2:
		sample.failure_reason = &"RAY_POSITION_INVALID"
		return sample
	var hit_position: Vector2 = hit_position_value as Vector2
	var altitude_meters: float = (
		ray_start.distance_to(hit_position) / safe_world_units_per_meter
	)
	if altitude_meters < MINIMUM_VALID_AGL_METERS:
		sample.failure_reason = &"RAY_DISTANCE_TOO_SMALL"
		return sample
	sample.altitude_meters = altitude_meters
	sample.hit_valid = true
	var collider_value: Variant = hit.get("collider", null)
	if collider_value is Node:
		var collider_node: Node = collider_value as Node
		sample.collider_name = collider_node.name
		sample.collider_path = collider_node.get_path()
	return sample


func _sample_profile(
	source: CollisionObject2D,
	profile_ground_y_world: float
) -> ProfileSample:
	var sample: ProfileSample = ProfileSample.new()
	if source == null or not source.is_inside_tree():
		sample.failure_reason = &"SOURCE_NOT_IN_TREE"
		return sample
	if not is_finite(profile_ground_y_world) or profile_ground_y_world >= INF * 0.5:
		sample.failure_reason = &"PROFILE_UNAVAILABLE"
		return sample
	var safe_world_units_per_meter: float = maxf(world_units_per_meter, 0.001)
	var ray_start_y: float = (
		source.global_position + ray_origin_offset_world
	).y
	var signed_altitude: float = (
		(profile_ground_y_world - ray_start_y) / safe_world_units_per_meter
	)
	sample.altitude_meters = maxf(signed_altitude, MINIMUM_VALID_AGL_METERS)
	sample.valid = true
	if signed_altitude < MINIMUM_VALID_AGL_METERS:
		sample.failure_reason = &"SOURCE_AT_OR_BELOW_PROFILE"
	return sample
