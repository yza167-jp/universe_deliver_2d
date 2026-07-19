class_name RedSandRouteVisuals
extends Node2D

const FLOOR_BODY_DEPTH: float = 600.0
const STAGE_LABEL_Y: float = 94.0

@export var planet_anchor_path: NodePath
@export var atmosphere_tint_path: NodePath
@export var surface_haze_path: NodePath
@export var far_stars_path: NodePath
@export var dust_bands_path: NodePath
@export var lower_haze_path: NodePath
@export var far_terrain_path: NodePath
@export var near_facilities_path: NodePath

@onready var _planet_anchor: Node2D = get_node_or_null(planet_anchor_path) as Node2D
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
	return true


func update_visuals(route_distance: float) -> void:
	if _route_definition == null or _planet_anchor == null:
		return
	var progress: float = _route_definition.get_overall_progress(route_distance)
	var planet_scale: float = _route_definition.get_planet_scale(route_distance)
	_planet_anchor.scale = Vector2.ONE * planet_scale
	_planet_anchor.position = Vector2(
		lerpf(548.0, 590.0, progress),
		lerpf(106.0, 278.0, progress)
	)
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


func get_planet_scale() -> float:
	if _planet_anchor == null:
		return 0.0
	return _planet_anchor.scale.x


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

	var floor_visual: Polygon2D = Polygon2D.new()
	floor_visual.name = "FloorVisual%02d" % (index + 1)
	floor_visual.z_index = -1
	floor_visual.polygon = PackedVector2Array([
		Vector2(start_x, start_floor_y),
		Vector2(end_x, end_floor_y),
		Vector2(end_x, end_floor_y + FLOOR_BODY_DEPTH),
		Vector2(start_x, start_floor_y + FLOOR_BODY_DEPTH),
	])
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
	var floor_collision: CollisionPolygon2D = CollisionPolygon2D.new()
	floor_collision.polygon = PackedVector2Array([
		Vector2(start_x, start_floor_y),
		Vector2(end_x, end_floor_y),
		Vector2(end_x, end_floor_y + FLOOR_BODY_DEPTH),
		Vector2(start_x, start_floor_y + FLOOR_BODY_DEPTH),
	])
	floor_body.add_child(floor_collision)
	add_child(floor_body)

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
