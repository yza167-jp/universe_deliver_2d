class_name WhiteNoiseRouteVisuals
extends Node2D

const ROUTE_ORIGIN_X: float = 320.0
const ICE_FLOOR_Y: float = 620.0
const LANDING_PAD_START_DISTANCE: float = 32750.0
const LANDING_CONTACT_DISTANCE: float = 33700.0
const LANDING_PAD_Y: float = 560.0
const BRANCH_OBSTACLE_START_DISTANCE: float = 11200.0
const BRANCH_OBSTACLE_END_DISTANCE: float = 14800.0
const CAVE_START_DISTANCE: float = 9500.0
const CAVE_END_DISTANCE: float = 17000.0
const ARCHIVE_START_DISTANCE: float = 23000.0
const ARCHIVE_END_DISTANCE: float = 28500.0

@export var route_definition: WhiteNoiseRouteDefinition

var _collision_bodies: Array[StaticBody2D] = []


func _ready() -> void:
	_build_collision_geometry()
	queue_redraw()


func _draw() -> void:
	if route_definition == null:
		return
	_draw_segment_backdrops()
	_draw_orbital_approach()
	_draw_icefield()
	_draw_branch_corridors()
	_draw_aurora_blizzard_placeholder()
	_draw_archive_entrance()
	_draw_landing_approach()


func get_landing_pad_start_distance() -> float:
	return LANDING_PAD_START_DISTANCE


func get_landing_contact_distance() -> float:
	return LANDING_CONTACT_DISTANCE


func get_landing_pad_y() -> float:
	return LANDING_PAD_Y


func get_collision_body_count() -> int:
	return _collision_bodies.size()


func _draw_segment_backdrops() -> void:
	for segment: FlightRouteSegment in route_definition.segments:
		if segment == null:
			continue
		var start_x: float = ROUTE_ORIGIN_X + segment.start_distance
		draw_rect(
			Rect2(start_x, -900.0, segment.get_length(), 1900.0),
			segment.graybox_color,
			true
		)


func _draw_orbital_approach() -> void:
	for index: int in 42:
		var x: float = ROUTE_ORIGIN_X + float((index * 337) % 4450)
		var y: float = float(35 + ((index * 83) % 470))
		var radius: float = 1.0 if index % 3 else 2.0
		draw_circle(Vector2(x, y), radius, Color(0.78, 0.9, 1.0, 0.8))
	var planet_center := Vector2(ROUTE_ORIGIN_X + 4250.0, 740.0)
	draw_circle(planet_center, 520.0, Color(0.5, 0.71, 0.86, 0.32))
	draw_arc(
		planet_center,
		520.0,
		PI,
		TAU,
		96,
		Color(0.68, 0.94, 1.0, 0.9),
		5.0
	)


func _draw_icefield() -> void:
	var start_x: float = ROUTE_ORIGIN_X + 4500.0
	var end_x: float = ROUTE_ORIGIN_X + route_definition.get_total_distance()
	draw_rect(
		Rect2(start_x, ICE_FLOOR_Y, end_x - start_x, 280.0),
		Color(0.55, 0.76, 0.84, 1.0),
		true
	)
	draw_line(
		Vector2(start_x, ICE_FLOOR_Y),
		Vector2(end_x, ICE_FLOOR_Y),
		Color(0.86, 0.98, 1.0, 1.0),
		4.0
	)
	draw_dashed_line(
		Vector2(start_x + 180.0, 450.0),
		Vector2(ROUTE_ORIGIN_X + CAVE_START_DISTANCE - 120.0, 450.0),
		Color(0.41, 0.92, 0.88, 0.9),
		3.0,
		24.0
	)
	for index: int in 120:
		var ridge_x: float = start_x + float(index * 245)
		var ridge_height: float = float(18 + ((index * 29) % 52))
		draw_polyline(
			PackedVector2Array([
				Vector2(ridge_x - 44.0, ICE_FLOOR_Y),
				Vector2(ridge_x, ICE_FLOOR_Y - ridge_height),
				Vector2(ridge_x + 52.0, ICE_FLOOR_Y),
			]),
			Color(0.71, 0.9, 0.95, 0.8),
			3.0
		)


func _draw_branch_corridors() -> void:
	var cave_start_x: float = ROUTE_ORIGIN_X + CAVE_START_DISTANCE
	var cave_end_x: float = ROUTE_ORIGIN_X + CAVE_END_DISTANCE
	draw_rect(
		Rect2(cave_start_x, -80.0, cave_end_x - cave_start_x, 220.0),
		Color(0.28, 0.48, 0.63, 1.0),
		true
	)
	draw_line(
		Vector2(cave_start_x, 140.0),
		Vector2(cave_end_x, 140.0),
		Color(0.73, 0.96, 1.0, 1.0),
		4.0
	)
	var obstacle_start_x: float = (
		ROUTE_ORIGIN_X + BRANCH_OBSTACLE_START_DISTANCE
	)
	var obstacle_width: float = (
		BRANCH_OBSTACLE_END_DISTANCE - BRANCH_OBSTACLE_START_DISTANCE
	)
	for obstacle_y: float in [230.0, 420.0]:
		draw_rect(
			Rect2(obstacle_start_x, obstacle_y - 20.0, obstacle_width, 40.0),
			Color(0.48, 0.75, 0.86, 1.0),
			true
		)
		draw_line(
			Vector2(obstacle_start_x, obstacle_y - 20.0),
			Vector2(obstacle_start_x + obstacle_width, obstacle_y - 20.0),
			Color(0.84, 0.98, 1.0, 1.0),
			3.0
		)
	var split_x: float = (
		ROUTE_ORIGIN_X + route_definition.get_branch_split_distance()
	)
	var join_x: float = (
		ROUTE_ORIGIN_X + route_definition.get_branch_join_distance()
	)
	for branch: WhiteNoiseRouteBranch in route_definition.branches:
		if branch == null:
			continue
		draw_dashed_line(
			Vector2(split_x, branch.retry_y),
			Vector2(join_x, branch.retry_y),
			branch.guide_color,
			3.0,
			22.0
		)
	draw_line(
		Vector2(join_x, 125.0),
		Vector2(join_x, 610.0),
		Color(0.95, 0.85, 0.36, 0.9),
		4.0
	)


func _draw_aurora_blizzard_placeholder() -> void:
	var start_x: float = ROUTE_ORIGIN_X + 17000.0
	var end_x: float = ROUTE_ORIGIN_X + 23000.0
	for band_index: int in 5:
		var band_y: float = 90.0 + float(band_index * 64)
		var color := Color(
			0.2 + float(band_index) * 0.05,
			0.88,
			0.82 - float(band_index) * 0.06,
			0.34
		)
		draw_polyline(
			PackedVector2Array([
				Vector2(start_x, band_y + 22.0),
				Vector2(start_x + 1500.0, band_y - 28.0),
				Vector2(start_x + 3100.0, band_y + 18.0),
				Vector2(end_x, band_y - 20.0),
			]),
			color,
			18.0
		)
	for line_index: int in 70:
		var x: float = start_x + float((line_index * 173) % 6000)
		var y: float = float(60 + ((line_index * 97) % 480))
		draw_line(
			Vector2(x, y),
			Vector2(x - 46.0, y + 18.0),
			Color(0.86, 0.98, 1.0, 0.48),
			2.0
		)


func _draw_archive_entrance() -> void:
	var start_x: float = ROUTE_ORIGIN_X + ARCHIVE_START_DISTANCE
	var end_x: float = ROUTE_ORIGIN_X + ARCHIVE_END_DISTANCE
	draw_rect(
		Rect2(start_x, -100.0, end_x - start_x, 230.0),
		Color(0.12, 0.29, 0.42, 1.0),
		true
	)
	draw_line(
		Vector2(start_x, 130.0),
		Vector2(end_x, 130.0),
		Color(0.52, 0.92, 0.94, 1.0),
		5.0
	)
	var gate_x: float = ROUTE_ORIGIN_X + 26700.0
	draw_dashed_line(
		Vector2(start_x, 300.0),
		Vector2(end_x, 300.0),
		Color(0.41, 0.92, 0.88, 0.9),
		3.0,
		24.0
	)
	draw_rect(
		Rect2(gate_x - 90.0, 170.0, 180.0, 390.0),
		Color(0.08, 0.17, 0.24, 1.0),
		true
	)
	draw_rect(
		Rect2(gate_x - 74.0, 190.0, 148.0, 352.0),
		Color(0.12, 0.43, 0.5, 0.72),
		false,
		6.0
	)
	for strip_index: int in 5:
		draw_rect(
			Rect2(
				gate_x - 60.0 + float(strip_index * 30),
				205.0,
				8.0,
				320.0
			),
			Color(0.41, 0.92, 0.9, 0.45),
			true
		)


func _draw_landing_approach() -> void:
	var beacon_x: float = ROUTE_ORIGIN_X + 31000.0
	draw_line(
		Vector2(beacon_x, 180.0),
		Vector2(beacon_x, ICE_FLOOR_Y),
		Color(0.95, 0.83, 0.33, 0.92),
		5.0
	)
	for radius: float in [24.0, 48.0, 72.0]:
		draw_arc(
			Vector2(beacon_x, 180.0),
			radius,
			PI,
			TAU,
			24,
			Color(0.95, 0.83, 0.33, 0.48),
			3.0
		)
	draw_dashed_line(
		Vector2(ROUTE_ORIGIN_X + 28500.0, 300.0),
		Vector2(
			ROUTE_ORIGIN_X + LANDING_CONTACT_DISTANCE,
			LANDING_PAD_Y - 22.0
		),
		Color(0.95, 0.83, 0.33, 0.92),
		3.0,
		24.0
	)
	var pad_start_x: float = ROUTE_ORIGIN_X + LANDING_PAD_START_DISTANCE
	var pad_end_x: float = ROUTE_ORIGIN_X + 34000.0
	draw_rect(
		Rect2(
			pad_start_x,
			LANDING_PAD_Y,
			pad_end_x - pad_start_x,
			60.0
		),
		Color(0.1, 0.22, 0.29, 1.0),
		true
	)
	draw_line(
		Vector2(pad_start_x, LANDING_PAD_Y),
		Vector2(pad_end_x, LANDING_PAD_Y),
		Color(0.97, 0.86, 0.38, 1.0),
		6.0
	)
	for marker_index: int in 9:
		var marker_x: float = pad_start_x + 80.0 + float(marker_index * 130)
		draw_rect(
			Rect2(marker_x, LANDING_PAD_Y + 12.0, 54.0, 8.0),
			Color(0.78, 0.96, 1.0, 0.9),
			true
		)


func _build_collision_geometry() -> void:
	_clear_collision_geometry()
	_add_collision_rect(
		&"IcefieldFloorBody",
		Rect2(
			ROUTE_ORIGIN_X + 4500.0,
			ICE_FLOOR_Y,
			28250.0,
			260.0
		)
	)
	_add_collision_rect(
		&"IceRiftCeilingBody",
		Rect2(
			ROUTE_ORIGIN_X + CAVE_START_DISTANCE,
			-80.0,
			CAVE_END_DISTANCE - CAVE_START_DISTANCE,
			220.0
		)
	)
	var branch_width: float = (
		BRANCH_OBSTACLE_END_DISTANCE - BRANCH_OBSTACLE_START_DISTANCE
	)
	_add_collision_rect(
		&"FastBalancedDividerBody",
		Rect2(
			ROUTE_ORIGIN_X + BRANCH_OBSTACLE_START_DISTANCE,
			210.0,
			branch_width,
			40.0
		)
	)
	_add_collision_rect(
		&"BalancedScenicDividerBody",
		Rect2(
			ROUTE_ORIGIN_X + BRANCH_OBSTACLE_START_DISTANCE,
			400.0,
			branch_width,
			40.0
		)
	)
	_add_collision_rect(
		&"ArchiveCeilingBody",
		Rect2(
			ROUTE_ORIGIN_X + ARCHIVE_START_DISTANCE,
			-100.0,
			ARCHIVE_END_DISTANCE - ARCHIVE_START_DISTANCE,
			230.0
		)
	)
	_add_collision_rect(
		&"LandingPadBody",
		Rect2(
			ROUTE_ORIGIN_X + LANDING_PAD_START_DISTANCE,
			LANDING_PAD_Y,
			1250.0,
			120.0
		)
	)


func _add_collision_rect(body_name: StringName, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0
	var collision_shape := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision_shape.shape = shape
	collision_shape.position = rect.position + rect.size * 0.5
	body.add_child(collision_shape)
	add_child(body)
	_collision_bodies.append(body)


func _clear_collision_geometry() -> void:
	for body: StaticBody2D in _collision_bodies:
		if is_instance_valid(body):
			body.queue_free()
	_collision_bodies.clear()
