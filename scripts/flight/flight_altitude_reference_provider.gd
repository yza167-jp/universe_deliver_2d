class_name FlightAltitudeReferenceProvider
extends RefCounted

## Produces the single player-visible altitude consumed by the route HUD and radar.
## Route-space Y is canonical; screen/camera coordinates never participate.

enum Mode {
	ORBITAL,
	ATMOSPHERE_ENTRY,
	AGL,
}

enum Source {
	HIGH_ALTITUDE,
	VIRTUAL_PROFILE,
	ATMOSPHERE_TO_AGL_BLEND,
	TERRAIN_PROFILE,
	HOLD_LAST_VALID,
	INVALID,
}

const ORBITAL_FINAL_SEGMENT_INDEX: int = 2
const ATMOSPHERE_FINAL_SEGMENT_INDEX: int = 4
const HIGH_ALTITUDE_THRESHOLD_METERS: float = 1000.0
const HIGH_ALTITUDE_FALLBACK_METERS: float = 1001.0
const STAGE_FIVE_AGL_PREPARE_START_PROGRESS: float = 0.40
## Ground-only layer keeps facilities and triggers out of the altitude ray.
const ALTITUDE_REFERENCE_COLLISION_LAYER: int = 1 << 4

var atmosphere_start_altitude_meters: float = 1800.0
var atmosphere_stage_boundary_altitude_meters: float = 1200.0
var agl_handoff_altitude_meters: float = 1050.0
var agl_smoothing_response_per_second: float = 5.0
var invalid_source_grace_seconds: float = 0.20
var ray_profile_tolerance_meters: float = 4.0
var agl_ray_length_route_units: float = 4000.0
var meters_per_route_unit: float = 1.0
var world_collision_mask: int = ALTITUDE_REFERENCE_COLLISION_LAYER

var mode: Mode = Mode.ORBITAL
var source: Source = Source.HIGH_ALTITUDE
var player_visible_altitude_meters: float = HIGH_ALTITUDE_FALLBACK_METERS
var raw_virtual_altitude_meters: float = 0.0
var raw_terrain_altitude_meters: float = 0.0
var raw_raycast_altitude_meters: float = 0.0
var raw_profile_altitude_meters: float = 0.0
var final_agl_altitude_meters: float = 0.0
var last_valid_agl_meters: float = 0.0
var virtual_altitude_valid: bool = false
var terrain_hit_valid: bool = false
var profile_altitude_valid: bool = false
var altitude_source_valid: bool = false
var current_agl_sample_valid: bool = false
var altitude_is_valid: bool = false
var numeric_altitude_valid: bool = false
var cross_source_consistency_valid: bool = true
var invalid_duration_seconds: float = 0.0
var atmosphere_to_agl_blend: float = 0.0
var canonical_route_distance: float = 0.0
var ship_reference_route_y: float = 0.0
var ground_route_y: float = 0.0
var agl_route_units: float = 0.0
var ray_profile_difference_meters: float = 0.0
var ray_start_world_position: Vector2 = Vector2.ZERO
var ray_hit_world_position: Vector2 = Vector2.ZERO
var ground_node_name: StringName = &""
var ground_node_path: NodePath = NodePath()
var terrain_profile_segment_id: StringName = &""
var sample_failure_reason: StringName = &""

var _has_initialized_output: bool = false
var _has_last_valid_agl: bool = false


class TerrainSample:
	extends RefCounted

	var altitude_meters: float = 0.0
	var hit_valid: bool = false
	var ray_start_world: Vector2 = Vector2.ZERO
	var hit_position_world: Vector2 = Vector2.ZERO
	var collider_name: StringName = &""
	var collider_path: NodePath = NodePath()
	var failure_reason: StringName = &""


class ProfileSample:
	extends RefCounted

	var altitude_meters: float = 0.0
	var agl_units: float = 0.0
	var ship_route_y: float = 0.0
	var ground_y: float = 0.0
	var valid: bool = false
	var segment_id: StringName = &""
	var failure_reason: StringName = &""


## Live route entry point. All values except the ray endpoints are route-local.
func update_from_canonical_frame(
	segment_index: int,
	segment_progress: float,
	route_distance: float,
	ship_route_y: float,
	profile_ground_y: float,
	profile_valid: bool,
	profile_segment_id: StringName,
	reference_point: Node2D,
	excluded_body: CollisionObject2D,
	route_space: Node2D,
	delta: float
) -> void:
	_apply_route_samples(
		segment_index,
		segment_progress,
		route_distance,
		_sample_world(reference_point, excluded_body, route_space),
		_sample_profile(
			ship_route_y,
			profile_ground_y,
			profile_valid,
			profile_segment_id
		),
		delta,
		false
	)


func reset_to_canonical_frame(
	segment_index: int,
	segment_progress: float,
	route_distance: float,
	ship_route_y: float,
	profile_ground_y: float,
	profile_valid: bool,
	profile_segment_id: StringName,
	reference_point: Node2D,
	excluded_body: CollisionObject2D,
	route_space: Node2D
) -> void:
	_reset_history()
	_apply_route_samples(
		segment_index,
		segment_progress,
		route_distance,
		_sample_world(reference_point, excluded_body, route_space),
		_sample_profile(
			ship_route_y,
			profile_ground_y,
			profile_valid,
			profile_segment_id
		),
		0.0,
		true
	)


## Deterministic canonical-frame entry point for matrix and frame-rate tests.
func update_from_canonical_samples(
	segment_index: int,
	segment_progress: float,
	route_distance: float,
	ship_route_y: float,
	profile_ground_y: float,
	profile_valid: bool,
	raycast_altitude_meters: float,
	raycast_valid: bool,
	delta: float,
	profile_segment_id: StringName = &"test_profile"
) -> void:
	var raycast_sample: TerrainSample = TerrainSample.new()
	raycast_sample.altitude_meters = raycast_altitude_meters
	raycast_sample.hit_valid = raycast_valid
	raycast_sample.failure_reason = &"" if raycast_valid else &"RAY_MISS"
	_apply_route_samples(
		segment_index,
		segment_progress,
		route_distance,
		raycast_sample,
		_sample_profile(
			ship_route_y,
			profile_ground_y,
			profile_valid,
			profile_segment_id
		),
		delta,
		false
	)


func reset_to_canonical_samples(
	segment_index: int,
	segment_progress: float,
	route_distance: float,
	ship_route_y: float,
	profile_ground_y: float,
	profile_valid: bool,
	raycast_altitude_meters: float,
	raycast_valid: bool,
	profile_segment_id: StringName = &"test_profile"
) -> void:
	_reset_history()
	update_from_canonical_samples(
		segment_index,
		segment_progress,
		route_distance,
		ship_route_y,
		profile_ground_y,
		profile_valid,
		raycast_altitude_meters,
		raycast_valid,
		0.0,
		profile_segment_id
	)


func get_altitude_meters() -> float:
	return player_visible_altitude_meters


func get_display_altitude_meters() -> float:
	return get_altitude_meters()


func get_hud_altitude_meters() -> float:
	return get_display_altitude_meters()


func get_radar_altitude_meters() -> float:
	return get_altitude_meters()


func has_numeric_altitude() -> bool:
	return altitude_is_valid


func is_current_source_valid() -> bool:
	return mode != Mode.AGL or current_agl_sample_valid


func has_cross_source_mismatch() -> bool:
	return not cross_source_consistency_valid


func is_using_high_altitude_fallback() -> bool:
	return mode == Mode.ORBITAL


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
		Source.ATMOSPHERE_TO_AGL_BLEND:
			return &"ATMOSPHERE_TO_AGL_BLEND"
		Source.TERRAIN_PROFILE:
			return &"PROFILE"
		Source.HOLD_LAST_VALID:
			return &"HOLD_LAST_VALID"
		Source.INVALID:
			return &"INVALID"
		_:
			return &"HIGH_ALTITUDE"


func get_ground_node_name() -> StringName:
	return ground_node_name


func get_ground_node_path() -> NodePath:
	return ground_node_path


func get_failure_reason() -> StringName:
	return sample_failure_reason


func has_last_valid_agl() -> bool:
	return _has_last_valid_agl


static func resolve_mode(segment_index: int) -> Mode:
	if segment_index <= ORBITAL_FINAL_SEGMENT_INDEX:
		return Mode.ORBITAL
	if segment_index <= ATMOSPHERE_FINAL_SEGMENT_INDEX:
		return Mode.ATMOSPHERE_ENTRY
	return Mode.AGL


static func is_motion_invariant_violated(
	start_ship_route_y: float,
	current_ship_route_y: float,
	start_ground_route_y: float,
	current_ground_route_y: float,
	start_final_agl_meters: float,
	current_final_agl_meters: float,
	meters_per_unit: float,
	minimum_expected_change_meters: float,
	maximum_final_change_meters: float
) -> bool:
	var expected_agl_change: float = absf(
		(
			current_ground_route_y
			- start_ground_route_y
			- (current_ship_route_y - start_ship_route_y)
		)
		* maxf(meters_per_unit, 0.001)
	)
	var final_agl_change: float = absf(
		current_final_agl_meters - start_final_agl_meters
	)
	return (
		expected_agl_change >= maxf(minimum_expected_change_meters, 0.0)
		and final_agl_change <= maxf(maximum_final_change_meters, 0.0)
	)


func _apply_route_samples(
	segment_index: int,
	segment_progress: float,
	route_distance: float,
	raycast_sample: TerrainSample,
	profile_sample: ProfileSample,
	delta: float,
	reset_immediately: bool
) -> void:
	var previous_mode: Mode = mode
	mode = resolve_mode(segment_index)
	canonical_route_distance = route_distance
	raw_virtual_altitude_meters = _resolve_virtual_altitude(
		segment_index,
		segment_progress
	)
	virtual_altitude_valid = mode != Mode.ORBITAL
	raw_raycast_altitude_meters = (
		raycast_sample.altitude_meters
		if raycast_sample != null and raycast_sample.hit_valid
		else 0.0
	)
	raw_profile_altitude_meters = (
		profile_sample.altitude_meters
		if profile_sample != null and profile_sample.valid
		else 0.0
	)
	terrain_hit_valid = raycast_sample != null and raycast_sample.hit_valid
	profile_altitude_valid = profile_sample != null and profile_sample.valid
	ship_reference_route_y = (
		profile_sample.ship_route_y if profile_sample != null else 0.0
	)
	ground_route_y = profile_sample.ground_y if profile_sample != null else 0.0
	agl_route_units = profile_sample.agl_units if profile_sample != null else 0.0
	terrain_profile_segment_id = (
		profile_sample.segment_id if profile_sample != null else &""
	)
	ray_start_world_position = (
		raycast_sample.ray_start_world if raycast_sample != null else Vector2.ZERO
	)
	ray_hit_world_position = (
		raycast_sample.hit_position_world
		if raycast_sample != null and raycast_sample.hit_valid
		else Vector2.ZERO
	)
	ground_node_name = (
		raycast_sample.collider_name if terrain_hit_valid else &""
	)
	ground_node_path = (
		raycast_sample.collider_path if terrain_hit_valid else NodePath()
	)
	ray_profile_difference_meters = (
		absf(raw_raycast_altitude_meters - raw_profile_altitude_meters)
		if terrain_hit_valid and profile_altitude_valid
		else 0.0
	)
	cross_source_consistency_valid = not (
		terrain_hit_valid
		and profile_altitude_valid
		and ray_profile_difference_meters > ray_profile_tolerance_meters
	)
	current_agl_sample_valid = (
		profile_altitude_valid and cross_source_consistency_valid
	)
	altitude_source_valid = current_agl_sample_valid
	sample_failure_reason = _resolve_sample_failure(
		raycast_sample,
		profile_sample
	)

	match mode:
		Mode.ORBITAL:
			_apply_orbital_output()
		Mode.ATMOSPHERE_ENTRY:
			_apply_atmosphere_output(segment_index, segment_progress)
		Mode.AGL:
			if current_agl_sample_valid:
				_apply_valid_agl_output(
				raw_profile_altitude_meters,
				delta,
				reset_immediately,
				previous_mode
			)
			else:
				_apply_invalid_agl_output(delta)
	_has_initialized_output = true


func _apply_orbital_output() -> void:
	source = Source.HIGH_ALTITUDE
	player_visible_altitude_meters = HIGH_ALTITUDE_FALLBACK_METERS
	final_agl_altitude_meters = 0.0
	raw_terrain_altitude_meters = 0.0
	altitude_source_valid = true
	current_agl_sample_valid = false
	altitude_is_valid = false
	numeric_altitude_valid = false
	invalid_duration_seconds = 0.0
	atmosphere_to_agl_blend = 0.0


func _apply_atmosphere_output(
	segment_index: int,
	segment_progress: float
) -> void:
	altitude_is_valid = true
	numeric_altitude_valid = true
	altitude_source_valid = true
	invalid_duration_seconds = 0.0
	atmosphere_to_agl_blend = 0.0
	player_visible_altitude_meters = raw_virtual_altitude_meters
	final_agl_altitude_meters = 0.0
	raw_terrain_altitude_meters = 0.0
	source = Source.VIRTUAL_PROFILE
	if segment_index != ATMOSPHERE_FINAL_SEGMENT_INDEX:
		return
	atmosphere_to_agl_blend = _smoothstep01(
		(segment_progress - STAGE_FIVE_AGL_PREPARE_START_PROGRESS)
		/ (1.0 - STAGE_FIVE_AGL_PREPARE_START_PROGRESS)
	)
	if not current_agl_sample_valid or atmosphere_to_agl_blend <= 0.0:
		return
	source = Source.ATMOSPHERE_TO_AGL_BLEND
	raw_terrain_altitude_meters = raw_profile_altitude_meters
	player_visible_altitude_meters = lerpf(
		raw_virtual_altitude_meters,
		raw_profile_altitude_meters,
		atmosphere_to_agl_blend
	)
	final_agl_altitude_meters = player_visible_altitude_meters
	last_valid_agl_meters = raw_profile_altitude_meters
	_has_last_valid_agl = true


func _apply_valid_agl_output(
	target_altitude_meters: float,
	delta: float,
	reset_immediately: bool,
	previous_mode: Mode
) -> void:
	source = Source.TERRAIN_PROFILE
	raw_terrain_altitude_meters = target_altitude_meters
	invalid_duration_seconds = 0.0
	altitude_source_valid = true
	altitude_is_valid = true
	numeric_altitude_valid = true
	if (
		reset_immediately
		or not _has_initialized_output
		or previous_mode == Mode.ORBITAL
	):
		player_visible_altitude_meters = target_altitude_meters
	else:
		var blend: float = 1.0 - exp(
			-maxf(agl_smoothing_response_per_second, 0.0) * maxf(delta, 0.0)
		)
		player_visible_altitude_meters = lerpf(
			player_visible_altitude_meters,
			target_altitude_meters,
			blend
		)
	final_agl_altitude_meters = player_visible_altitude_meters
	last_valid_agl_meters = player_visible_altitude_meters
	_has_last_valid_agl = true


func _apply_invalid_agl_output(delta: float) -> void:
	altitude_source_valid = false
	invalid_duration_seconds += maxf(delta, 0.0)
	if (
		_has_last_valid_agl
		and invalid_duration_seconds <= maxf(invalid_source_grace_seconds, 0.0)
	):
		source = Source.HOLD_LAST_VALID
		player_visible_altitude_meters = last_valid_agl_meters
		final_agl_altitude_meters = last_valid_agl_meters
		raw_terrain_altitude_meters = 0.0
		altitude_is_valid = true
		numeric_altitude_valid = true
		return
	source = Source.INVALID
	player_visible_altitude_meters = (
		last_valid_agl_meters if _has_last_valid_agl else 0.0
	)
	final_agl_altitude_meters = player_visible_altitude_meters
	raw_terrain_altitude_meters = 0.0
	altitude_is_valid = false
	numeric_altitude_valid = false


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


func _resolve_sample_failure(
	raycast_sample: TerrainSample,
	profile_sample: ProfileSample
) -> StringName:
	if not cross_source_consistency_valid:
		return &"RAY_PROFILE_MISMATCH"
	if profile_sample != null and not profile_sample.failure_reason.is_empty():
		return profile_sample.failure_reason
	if (
		raycast_sample != null
		and not raycast_sample.failure_reason.is_empty()
		and not profile_altitude_valid
	):
		return raycast_sample.failure_reason
	if (
		profile_altitude_valid
		and raycast_sample != null
		and not raycast_sample.failure_reason.is_empty()
	):
		return raycast_sample.failure_reason
	return &""


func _sample_world(
	reference_point: Node2D,
	excluded_body: CollisionObject2D,
	route_space: Node2D
) -> TerrainSample:
	var sample: TerrainSample = TerrainSample.new()
	if reference_point == null or not reference_point.is_inside_tree():
		sample.failure_reason = &"REFERENCE_POINT_NOT_IN_TREE"
		return sample
	var world: World2D = reference_point.get_world_2d()
	if world == null:
		sample.failure_reason = &"WORLD_UNAVAILABLE"
		return sample
	var safe_meters_per_unit: float = maxf(meters_per_route_unit, 0.001)
	var ray_length_world: float = (
		maxf(agl_ray_length_route_units, 0.0)
		* reference_point.global_transform.get_scale().y
	)
	if ray_length_world <= 0.0:
		sample.failure_reason = &"RAY_LENGTH_INVALID"
		return sample

	var ray_start: Vector2 = reference_point.global_position
	var ray_end: Vector2 = ray_start + Vector2.DOWN * ray_length_world
	sample.ray_start_world = ray_start
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		ray_start,
		ray_end,
		world_collision_mask
	)
	if excluded_body != null:
		query.exclude = [excluded_body.get_rid()]
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
	var start_route_y: float = (
		route_space.to_local(ray_start).y if route_space != null else ray_start.y
	)
	var hit_route_y: float = (
		route_space.to_local(hit_position).y
		if route_space != null
		else hit_position.y
	)
	var altitude_units: float = hit_route_y - start_route_y
	if altitude_units < 0.0:
		sample.failure_reason = &"RAY_HIT_ABOVE_REFERENCE"
		return sample
	sample.altitude_meters = altitude_units * safe_meters_per_unit
	sample.hit_position_world = hit_position
	sample.hit_valid = true
	var collider_value: Variant = hit.get("collider", null)
	if collider_value is Node:
		var collider_node: Node = collider_value as Node
		sample.collider_name = collider_node.name
		sample.collider_path = collider_node.get_path()
	return sample


func _sample_profile(
	ship_route_y_value: float,
	profile_ground_y_value: float,
	profile_valid: bool,
	profile_segment_id_value: StringName
) -> ProfileSample:
	var sample: ProfileSample = ProfileSample.new()
	sample.ship_route_y = ship_route_y_value
	sample.ground_y = profile_ground_y_value
	sample.segment_id = profile_segment_id_value
	if (
		not profile_valid
		or not is_finite(ship_route_y_value)
		or not is_finite(profile_ground_y_value)
	):
		sample.failure_reason = &"PROFILE_UNAVAILABLE"
		return sample
	var signed_agl_units: float = profile_ground_y_value - ship_route_y_value
	sample.agl_units = signed_agl_units
	if signed_agl_units < 0.0:
		sample.failure_reason = &"REFERENCE_BELOW_TERRAIN_PROFILE"
		return sample
	sample.altitude_meters = signed_agl_units * maxf(meters_per_route_unit, 0.001)
	sample.valid = true
	return sample


func _reset_history() -> void:
	_has_initialized_output = false
	_has_last_valid_agl = false
	last_valid_agl_meters = 0.0
	invalid_duration_seconds = 0.0


func _smoothstep01(value: float) -> float:
	var clamped_value: float = clampf(value, 0.0, 1.0)
	return clamped_value * clamped_value * (3.0 - 2.0 * clamped_value)
