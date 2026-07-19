class_name RedSandRouteVisuals
extends Node2D

const FLOOR_BODY_DEPTH: float = 600.0
const STAGE_LABEL_Y: float = 94.0
const ATMOSPHERE_SEGMENT_INDEX: int = 3
const STORM_SEGMENT_INDEX: int = 4
const LOWER_CLOUDS_SEGMENT_INDEX: int = 5
const PLANET_HORIZON_TRANSITION_SECONDS: float = 0.9
const PLANET_CURVATURE_SCALE: float = 5.8
const PLANET_CURVATURE_POSITION: Vector2 = Vector2(350.0, 620.0)

@export var planet_anchor_path: NodePath
@export var atmosphere_horizon_path: NodePath
@export var atmosphere_tint_path: NodePath
@export var surface_haze_path: NodePath
@export var far_stars_path: NodePath
@export var dust_bands_path: NodePath
@export var lower_haze_path: NodePath
@export var far_terrain_path: NodePath
@export var near_facilities_path: NodePath

@onready var _planet_anchor: Node2D = get_node_or_null(planet_anchor_path) as Node2D
@onready var _atmosphere_horizon: Node2D = get_node_or_null(
	atmosphere_horizon_path
) as Node2D
@onready var _atmosphere_tint: ColorRect = get_node_or_null(
	atmosphere_tint_path
) as ColorRect
@onready var _surface_haze: ColorRect = get_node_or_null(surface_haze_path) as ColorRect
@onready var _far_stars: Parallax2D = get_node_or_null(far_stars_path) as Parallax2D
@onready var _dust_bands: Parallax2D = get_node_or_null(dust_bands_path) as Parallax2D
@onready var _lower_haze: Parallax2D = get_node_or_null(lower_haze_path) as Parallax2D
@onready var _far_terrain: Parallax2D = get_node_or_null(
	far_terrain_path
) as Parallax2D
@onready var _near_facilities: Parallax2D = get_node_or_null(
	near_facilities_path
) as Parallax2D

var _route_definition: FlightRouteDefinition
var _route_origin_x: float = 0.0
var _last_segment_index: int = -1
var _planet_transition_elapsed: float = 0.0
var _planet_alpha: float = 1.0
var _horizon_alpha: float = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_stage_labels()


func configure(
	route_definition: FlightRouteDefinition,
	route_origin_x: float
) -> bool:
	if route_definition == null or not route_definition.validate().is_empty():
		return false
	_route_definition = route_definition
	_route_origin_x = route_origin_x
	_build_graybox_route()
	reset_to_distance(0.0)
	return true


func update_visuals(route_distance: float, delta: float = 0.0) -> void:
	if _route_definition == null or _planet_anchor == null:
		return
	var progress: float = _route_definition.get_overall_progress(route_distance)
	var segment_index: int = _route_definition.get_segment_index(route_distance)
	var segment: FlightRouteSegment = _route_definition.get_segment(route_distance)
	if segment == null:
		return
	var segment_progress: float = segment.get_progress(route_distance)
	if segment_index != _last_segment_index:
		_begin_planet_stage(segment_index)
		_last_segment_index = segment_index
	var planet_scale: float = _route_definition.get_planet_scale(route_distance)
	_update_planet_transition(
		maxf(delta, 0.0),
		segment_index,
		segment_progress
	)
	_apply_planet_transform(segment_index, segment_progress, planet_scale)
	_planet_anchor.modulate.a = _planet_alpha
	_planet_anchor.visible = _planet_alpha > 0.001
	if _atmosphere_horizon != null:
		_atmosphere_horizon.modulate.a = _horizon_alpha
		_atmosphere_horizon.visible = _horizon_alpha > 0.001
	if _atmosphere_tint != null:
		var atmosphere_color: Color = _atmosphere_tint.color
		atmosphere_color.a = clampf((progress - 0.3) / 0.7, 0.0, 1.0) * 0.62
		_atmosphere_tint.color = atmosphere_color
	if _surface_haze != null:
		var surface_color: Color = _surface_haze.color
		surface_color.a = clampf((progress - 0.58) / 0.42, 0.0, 1.0) * 0.72
		_surface_haze.color = surface_color
	if _far_stars != null:
		_far_stars.modulate.a = lerpf(1.0, 0.12, progress)
	if _dust_bands != null:
		_dust_bands.modulate.a = lerpf(0.18, 0.78, progress)
	if _lower_haze != null:
		_lower_haze.modulate.a = clampf((progress - 0.45) / 0.55, 0.0, 1.0)
	if _far_terrain != null:
		_far_terrain.modulate.a = clampf((progress - 0.48) / 0.3, 0.0, 1.0)
	if _near_facilities != null:
		_near_facilities.modulate.a = clampf((progress - 0.7) / 0.22, 0.0, 1.0)


func reset_to_distance(route_distance: float) -> void:
	if _route_definition == null:
		return
	var segment_index: int = _route_definition.get_segment_index(route_distance)
	var segment: FlightRouteSegment = _route_definition.get_segment(route_distance)
	_last_segment_index = segment_index
	_planet_transition_elapsed = 0.0
	_planet_alpha = 1.0
	_horizon_alpha = 0.0
	if segment_index == ATMOSPHERE_SEGMENT_INDEX and segment != null:
		if segment.get_progress(route_distance) > 0.02:
			_planet_transition_elapsed = PLANET_HORIZON_TRANSITION_SECONDS
	elif segment_index >= STORM_SEGMENT_INDEX:
		_planet_transition_elapsed = PLANET_HORIZON_TRANSITION_SECONDS
		_planet_alpha = 0.0
		_horizon_alpha = 1.0 if segment_index <= LOWER_CLOUDS_SEGMENT_INDEX else 0.0
	update_visuals(route_distance, 0.0)


func get_planet_scale() -> float:
	if _planet_anchor == null:
		return 0.0
	return _planet_anchor.scale.x


func get_planet_position() -> Vector2:
	return Vector2.ZERO if _planet_anchor == null else _planet_anchor.position


func get_planet_alpha() -> float:
	return _planet_alpha


func get_atmosphere_horizon_alpha() -> float:
	return _horizon_alpha


func get_planet_transition_progress() -> float:
	return clampf(
		_planet_transition_elapsed / PLANET_HORIZON_TRANSITION_SECONDS,
		0.0,
		1.0
	)


func get_terrain_surface_stage_indices() -> PackedInt32Array:
	var stage_indices: PackedInt32Array = PackedInt32Array()
	for child: Node in get_children():
		if child is StaticBody2D and child.has_meta(&"route_segment_index"):
			stage_indices.append(int(child.get_meta(&"route_segment_index")))
	return stage_indices


func is_full_planet_visible() -> bool:
	return _planet_anchor != null and _planet_anchor.visible


func _begin_planet_stage(segment_index: int) -> void:
	if segment_index < ATMOSPHERE_SEGMENT_INDEX:
		_planet_alpha = 1.0
		_horizon_alpha = 0.0
		_planet_transition_elapsed = 0.0
	elif segment_index == ATMOSPHERE_SEGMENT_INDEX:
		_planet_alpha = 1.0
		_horizon_alpha = 0.0
		_planet_transition_elapsed = 0.0
	else:
		_planet_alpha = 0.0
		_horizon_alpha = 1.0 if segment_index <= LOWER_CLOUDS_SEGMENT_INDEX else 0.0
		_planet_transition_elapsed = PLANET_HORIZON_TRANSITION_SECONDS


func _update_planet_transition(
	delta: float,
	segment_index: int,
	segment_progress: float
) -> void:
	if segment_index < ATMOSPHERE_SEGMENT_INDEX:
		_planet_alpha = 1.0
		_horizon_alpha = 0.0
		return
	if segment_index == ATMOSPHERE_SEGMENT_INDEX:
		_planet_transition_elapsed = minf(
			_planet_transition_elapsed + delta,
			PLANET_HORIZON_TRANSITION_SECONDS
		)
		var transition_progress: float = get_planet_transition_progress()
		_horizon_alpha = smoothstep(0.0, 0.72, transition_progress)
		_planet_alpha = 1.0 - smoothstep(0.52, 1.0, transition_progress)
		return
	if segment_index == STORM_SEGMENT_INDEX:
		_planet_alpha = 0.0
		_horizon_alpha = 1.0
		return
	if segment_index == LOWER_CLOUDS_SEGMENT_INDEX:
		_planet_alpha = 0.0
		_horizon_alpha = 1.0 - smoothstep(0.35, 1.0, segment_progress)
		return
	_planet_alpha = 0.0
	_horizon_alpha = 0.0


func _apply_planet_transform(
	segment_index: int,
	segment_progress: float,
	route_planet_scale: float
) -> void:
	if segment_index < ATMOSPHERE_SEGMENT_INDEX:
		_planet_anchor.scale = Vector2.ONE * route_planet_scale
		_planet_anchor.position = _get_planet_position(segment_index, segment_progress)
		return
	if segment_index == ATMOSPHERE_SEGMENT_INDEX:
		var transition_progress: float = smoothstep(
			0.0,
			1.0,
			get_planet_transition_progress()
		)
		_planet_anchor.scale = Vector2.ONE * lerpf(
			route_planet_scale,
			PLANET_CURVATURE_SCALE,
			transition_progress
		)
		_planet_anchor.position = _get_planet_position(
			segment_index,
			segment_progress
		).lerp(PLANET_CURVATURE_POSITION, transition_progress)
		return
	_planet_anchor.scale = Vector2.ONE * PLANET_CURVATURE_SCALE
	_planet_anchor.position = PLANET_CURVATURE_POSITION


func _get_planet_position(segment_index: int, segment_progress: float) -> Vector2:
	var safe_progress: float = clampf(segment_progress, 0.0, 1.0)
	match segment_index:
		0:
			return Vector2(580.0, 102.0).lerp(Vector2(552.0, 112.0), safe_progress)
		1:
			return Vector2(552.0, 112.0).lerp(Vector2(520.0, 124.0), safe_progress)
		2:
			return Vector2(520.0, 124.0).lerp(Vector2(455.0, 160.0), safe_progress)
		3:
			return Vector2(455.0, 160.0).lerp(Vector2(370.0, 390.0), safe_progress)
	return Vector2(370.0, 390.0)


func _build_graybox_route() -> void:
	for child: Node in get_children():
		child.queue_free()
	for index: int in _route_definition.segments.size():
		var segment: FlightRouteSegment = _route_definition.segments[index]
		_build_segment_graybox(segment, index)
		_build_segment_landmarks(segment, index)
	_build_finish_beacon()


func _build_segment_graybox(segment: FlightRouteSegment, index: int) -> void:
	var start_x: float = _route_origin_x + segment.start_distance
	var end_x: float = _route_origin_x + segment.end_distance
	var start_floor_y: float = (
		segment.floor_y
		if index == 0
		else _route_definition.segments[index - 1].floor_y
	)
	var end_floor_y: float = segment.floor_y

	var stage_band: Polygon2D = Polygon2D.new()
	stage_band.name = "StageBand%02d" % (index + 1)
	stage_band.z_index = -7
	stage_band.polygon = PackedVector2Array([
		Vector2(start_x, -600.0),
		Vector2(end_x, -600.0),
		Vector2(end_x, end_floor_y),
		Vector2(start_x, start_floor_y),
	])
	var band_color: Color = segment.graybox_color
	band_color.a = 0.18
	stage_band.color = band_color
	add_child(stage_band)

	if segment.terrain_surface_enabled:
		_build_terrain_surface(
			segment,
			index,
			start_x,
			end_x,
			start_floor_y,
			end_floor_y
		)

	var divider: Line2D = Line2D.new()
	divider.name = "StageDivider%02d" % (index + 1)
	divider.position = Vector2(start_x, 0.0)
	divider.points = PackedVector2Array([
		Vector2(0.0, -300.0),
		Vector2(0.0, start_floor_y),
	])
	divider.width = 2.0
	divider.default_color = Color(0.905882, 0.658824, 0.356863, 0.45)
	add_child(divider)

	var stage_label: Label = Label.new()
	stage_label.name = "StageLabel%02d" % (index + 1)
	stage_label.position = Vector2(start_x + 18.0, STAGE_LABEL_Y)
	stage_label.text = tr(segment.display_name_key)
	stage_label.add_theme_font_size_override("font_size", 18)
	stage_label.add_theme_color_override(
		"font_color",
		Color(0.905882, 0.658824, 0.356863, 0.72)
	)
	stage_label.set_meta(&"route_segment_index", index)
	add_child(stage_label)


func _build_terrain_surface(
	segment: FlightRouteSegment,
	index: int,
	start_x: float,
	end_x: float,
	start_floor_y: float,
	end_floor_y: float
) -> void:
	var surface_polygon: PackedVector2Array = PackedVector2Array([
		Vector2(start_x, start_floor_y),
		Vector2(end_x, end_floor_y),
		Vector2(end_x, end_floor_y + FLOOR_BODY_DEPTH),
		Vector2(start_x, start_floor_y + FLOOR_BODY_DEPTH),
	])
	var floor_visual: Polygon2D = Polygon2D.new()
	floor_visual.name = "FloorVisual%02d" % (index + 1)
	floor_visual.z_index = -1
	floor_visual.polygon = surface_polygon
	floor_visual.color = segment.graybox_color
	add_child(floor_visual)

	var floor_edge: Line2D = Line2D.new()
	floor_edge.name = "FloorEdge%02d" % (index + 1)
	floor_edge.z_index = 2
	floor_edge.points = PackedVector2Array([
		Vector2(start_x, start_floor_y),
		Vector2(end_x, end_floor_y),
	])
	floor_edge.width = 3.0
	floor_edge.default_color = _resolve_floor_edge_color(index)
	add_child(floor_edge)

	var floor_body: StaticBody2D = StaticBody2D.new()
	floor_body.name = "FloorBody%02d" % (index + 1)
	floor_body.collision_layer = FlightWeaponRules.WORLD_COLLISION_LAYER
	floor_body.collision_mask = 0
	floor_body.set_meta(&"route_segment_index", index)
	var floor_collision: CollisionPolygon2D = CollisionPolygon2D.new()
	floor_collision.polygon = surface_polygon
	floor_body.add_child(floor_collision)
	add_child(floor_body)


func _build_finish_beacon() -> void:
	var finish_x: float = _route_origin_x + _route_definition.get_total_distance()
	var beacon: Line2D = Line2D.new()
	beacon.name = "LandingApproachBeacon"
	beacon.position = Vector2(finish_x, 0.0)
	beacon.points = PackedVector2Array([
		Vector2(0.0, 140.0),
		Vector2(0.0, 350.0),
	])
	beacon.width = 6.0
	beacon.default_color = Color(0.462745, 0.945098, 1.0, 0.9)
	add_child(beacon)


func _build_segment_landmarks(segment: FlightRouteSegment, index: int) -> void:
	match index:
		1:
			_build_asteroid_silhouettes(segment, index)
		2:
			_build_guide_lines(segment, index, 3, Color(0.462745, 0.945098, 1.0, 0.28))
		3:
			_build_guide_lines(segment, index, 5, Color(0.905882, 0.658824, 0.356863, 0.3))
		4, 5:
			_build_cloud_silhouettes(segment, index)
		6:
			_build_facility_silhouettes(segment, index)
		7:
			_build_landing_guides(segment, index)


func _build_asteroid_silhouettes(segment: FlightRouteSegment, index: int) -> void:
	var container: Node2D = Node2D.new()
	container.name = "AsteroidSilhouettes%02d" % (index + 1)
	container.z_index = -3
	var spacing: float = segment.get_length() / 9.0
	for marker_index: int in 8:
		var asteroid: Polygon2D = Polygon2D.new()
		asteroid.position = Vector2(
			_route_origin_x + segment.start_distance + spacing * float(marker_index + 1),
			126.0 + float((marker_index * 53) % 150)
		)
		var radius: float = 10.0 + float((marker_index * 7) % 12)
		asteroid.polygon = PackedVector2Array([
			Vector2(-radius, -radius * 0.35),
			Vector2(-radius * 0.4, -radius),
			Vector2(radius * 0.55, -radius * 0.8),
			Vector2(radius, radius * 0.1),
			Vector2(radius * 0.35, radius),
			Vector2(-radius * 0.75, radius * 0.65),
		])
		asteroid.color = Color(0.360784, 0.27451, 0.258824, 0.64)
		container.add_child(asteroid)
	add_child(container)


func _build_guide_lines(
	segment: FlightRouteSegment,
	index: int,
	line_count: int,
	color: Color
) -> void:
	var container: Node2D = Node2D.new()
	container.name = "ApproachGuides%02d" % (index + 1)
	container.z_index = -4
	var spacing: float = segment.get_length() / float(line_count + 1)
	for line_index: int in line_count:
		var guide: Line2D = Line2D.new()
		guide.position.x = (
			_route_origin_x
			+ segment.start_distance
			+ spacing * float(line_index + 1)
		)
		guide.points = PackedVector2Array([
			Vector2(-240.0, 132.0 + float(line_index * 26)),
			Vector2(240.0, 112.0 + float(line_index * 26)),
		])
		guide.width = 2.0
		guide.default_color = color
		container.add_child(guide)
	add_child(container)


func _build_cloud_silhouettes(segment: FlightRouteSegment, index: int) -> void:
	var container: Node2D = Node2D.new()
	container.name = "CloudSilhouettes%02d" % (index + 1)
	container.z_index = -3
	var spacing: float = segment.get_length() / 7.0
	for cloud_index: int in 6:
		var cloud: Polygon2D = Polygon2D.new()
		var center_x: float = (
			_route_origin_x
			+ segment.start_distance
			+ spacing * float(cloud_index + 1)
		)
		var center_y: float = 128.0 + float((cloud_index * 41) % 118)
		cloud.polygon = PackedVector2Array([
			Vector2(center_x - 180.0, center_y),
			Vector2(center_x - 80.0, center_y - 18.0),
			Vector2(center_x + 30.0, center_y - 8.0),
			Vector2(center_x + 180.0, center_y + 5.0),
			Vector2(center_x + 130.0, center_y + 28.0),
			Vector2(center_x - 150.0, center_y + 24.0),
		])
		cloud.color = (
			Color(0.360784, 0.211765, 0.247059, 0.46)
			if index == 4
			else Color(0.737255, 0.407843, 0.25098, 0.34)
		)
		container.add_child(cloud)
	add_child(container)


func _build_facility_silhouettes(segment: FlightRouteSegment, index: int) -> void:
	var container: Node2D = Node2D.new()
	container.name = "FacilitySilhouettes%02d" % (index + 1)
	container.z_index = -2
	var spacing: float = segment.get_length() / 7.0
	for facility_index: int in 6:
		var height: float = 42.0 + float((facility_index * 29) % 76)
		var width: float = 36.0 + float((facility_index * 17) % 44)
		var center_x: float = (
			_route_origin_x
			+ segment.start_distance
			+ spacing * float(facility_index + 1)
		)
		var floor_y: float = lerpf(
			_route_definition.segments[index - 1].floor_y,
			segment.floor_y,
			segment.get_progress(center_x - _route_origin_x)
		)
		var facility: Polygon2D = Polygon2D.new()
		facility.polygon = PackedVector2Array([
			Vector2(center_x - width * 0.5, floor_y),
			Vector2(center_x - width * 0.5, floor_y - height),
			Vector2(center_x + width * 0.5, floor_y - height),
			Vector2(center_x + width * 0.5, floor_y),
		])
		facility.color = Color(0.105882, 0.129412, 0.14902, 0.72)
		container.add_child(facility)
	add_child(container)


func _build_landing_guides(segment: FlightRouteSegment, index: int) -> void:
	var container: Node2D = Node2D.new()
	container.name = "LandingGuides%02d" % (index + 1)
	container.z_index = 1
	var spacing: float = segment.get_length() / 9.0
	for marker_index: int in 8:
		var marker_x: float = (
			_route_origin_x
			+ segment.start_distance
			+ spacing * float(marker_index + 1)
		)
		var floor_y: float = lerpf(
			_route_definition.segments[index - 1].floor_y,
			segment.floor_y,
			segment.get_progress(marker_x - _route_origin_x)
		)
		var marker: Line2D = Line2D.new()
		marker.points = PackedVector2Array([
			Vector2(marker_x - 18.0, floor_y - 10.0),
			Vector2(marker_x, floor_y - 2.0),
			Vector2(marker_x + 18.0, floor_y - 10.0),
		])
		marker.width = 3.0
		marker.default_color = Color(0.462745, 0.945098, 1.0, 0.76)
		container.add_child(marker)
	add_child(container)


func _resolve_floor_edge_color(index: int) -> Color:
	if index <= 2:
		return Color(0.462745, 0.945098, 1.0, 0.34)
	if index == 4:
		return Color(0.760784, 0.678431, 1.0, 0.58)
	if index >= 6:
		return Color(0.905882, 0.658824, 0.356863, 0.8)
	return Color(1.0, 0.494118, 0.219608, 0.64)


func _refresh_stage_labels() -> void:
	if _route_definition == null:
		return
	for child: Node in get_children():
		if not child is Label or not child.has_meta(&"route_segment_index"):
			continue
		var index: int = int(child.get_meta(&"route_segment_index"))
		if index < 0 or index >= _route_definition.segments.size():
			continue
		(child as Label).text = tr(_route_definition.segments[index].display_name_key)
