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
const PRODUCTION_PLACEHOLDER_LAYER_COUNT: int = 7
const DEFAULT_BLIZZARD_STREAK_COUNT: int = 92
const REDUCED_BLIZZARD_STREAK_COUNT: int = 38
const PALETTE_SIGNATURE: StringName = &"white_noise_ice_aurora_archive"
const DEEP_OCEAN_BLUE: Color = Color("#07162d")
const UPPER_ATMOSPHERE_BLUE: Color = Color("#102e4a")
const DISTANT_ICE_BLUE: Color = Color("#28536d")
const MID_ICE_BLUE: Color = Color("#4d8298")
const ICE_WHITE: Color = Color("#d9f5f4")
const AURORA_GREEN: Color = Color("#54e3b1")
const AURORA_PINK: Color = Color("#e58bd8")
const ARCHIVE_LIGHT: Color = Color("#9ff5df")
const COLLISION_WARNING: Color = Color("#ffe66f")

@export var route_definition: WhiteNoiseRouteDefinition

var _collision_bodies: Array[StaticBody2D] = []
var _route_hints_enabled: bool = LocalSettingsData.DEFAULT_ROUTE_HINTS_ENABLED
var _high_contrast_enabled: bool = (
	LocalSettingsData.DEFAULT_HIGH_CONTRAST_TERRAIN
)
var _storm_interference_strength: float = 0.0
var _storm_phase_progress: float = 0.0
var _storm_state_name: StringName = &"CLEAR"


func _ready() -> void:
	_build_collision_geometry()
	queue_redraw()


func _draw() -> void:
	if route_definition == null:
		return
	_draw_segment_backdrops()
	_draw_orbital_approach()
	_draw_distant_ice_layers()
	_draw_icefield()
	_draw_branch_corridors()
	_draw_aurora_blizzard()
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


func set_accessibility(
	route_hints_enabled: bool,
	high_contrast_enabled: bool
) -> void:
	if (
		_route_hints_enabled == route_hints_enabled
		and _high_contrast_enabled == high_contrast_enabled
	):
		return
	_route_hints_enabled = route_hints_enabled
	_high_contrast_enabled = high_contrast_enabled
	queue_redraw()


func set_storm_feedback(
	interference_strength: float,
	phase_progress: float,
	state_name: StringName
) -> void:
	var sanitized_strength: float = clampf(interference_strength, 0.0, 1.0)
	var sanitized_progress: float = clampf(phase_progress, 0.0, 1.0)
	if (
		absf(_storm_interference_strength - sanitized_strength) < 0.02
		and absf(_storm_phase_progress - sanitized_progress) < 0.02
		and _storm_state_name == state_name
	):
		return
	_storm_interference_strength = sanitized_strength
	_storm_phase_progress = sanitized_progress
	_storm_state_name = state_name
	queue_redraw()


func are_route_hints_visible() -> bool:
	return _route_hints_enabled


func is_high_contrast_enabled() -> bool:
	return _high_contrast_enabled


func get_blizzard_interference_strength() -> float:
	return _storm_interference_strength


func get_archive_signal_clarity() -> float:
	return clampf(1.0 - _storm_interference_strength * 0.62, 0.4, 1.0)


func get_presentation_signature() -> StringName:
	return PALETTE_SIGNATURE


func get_background_layer_count() -> int:
	return PRODUCTION_PLACEHOLDER_LAYER_COUNT


func get_blizzard_streak_count() -> int:
	return (
		REDUCED_BLIZZARD_STREAK_COUNT
		if _high_contrast_enabled
		else DEFAULT_BLIZZARD_STREAK_COUNT
	)


func get_visual_noise_scale() -> float:
	return 0.48 if _high_contrast_enabled else 1.0


func _draw_segment_backdrops() -> void:
	for segment: FlightRouteSegment in route_definition.segments:
		if segment == null:
			continue
		var start_x: float = ROUTE_ORIGIN_X + segment.start_distance
		var segment_length: float = segment.get_length()
		draw_rect(
			Rect2(start_x, -900.0, segment_length, 1900.0),
			_resolve_segment_sky(segment.id),
			true
		)
		draw_rect(
			Rect2(start_x, 40.0, segment_length, 230.0),
			Color(0.08, 0.23, 0.34, 0.34),
			true
		)
		draw_rect(
			Rect2(start_x, 270.0, segment_length, 300.0),
			Color(0.12, 0.31, 0.4, 0.28),
			true
		)
		for band_index: int in 4:
			var band_y: float = 70.0 + float(band_index * 82)
			draw_rect(
				Rect2(start_x, band_y, segment_length, 18.0),
				Color(
					0.18 + float(band_index) * 0.025,
					0.46 + float(band_index) * 0.02,
					0.58 + float(band_index) * 0.025,
					0.045 + float(band_index) * 0.012
				),
				true
			)


func _resolve_segment_sky(segment_id: StringName) -> Color:
	match segment_id:
		&"white_noise_orbital_approach":
			return DEEP_OCEAN_BLUE
		&"white_noise_open_icefield":
			return Color("#102f4b")
		&"white_noise_ice_rift_split":
			return Color("#0c263f")
		&"white_noise_aurora_blizzard":
			return Color("#102945")
		&"white_noise_archive_descent":
			return Color("#061d2b")
		&"white_noise_landing_approach":
			return Color("#0a2635")
	return DEEP_OCEAN_BLUE


func _draw_orbital_approach() -> void:
	for index: int in 58:
		var x: float = ROUTE_ORIGIN_X + float((index * 337) % 4450)
		var y: float = float(35 + ((index * 83) % 470))
		var radius: float = 1.0 if index % 3 else 2.0
		draw_circle(
			Vector2(x, y),
			radius,
			Color(0.78, 0.93, 1.0, 0.48 + float(index % 4) * 0.1)
		)
	var planet_center := Vector2(ROUTE_ORIGIN_X + 4250.0, 760.0)
	draw_circle(planet_center, 650.0, Color(0.1, 0.29, 0.45, 0.38))
	draw_circle(planet_center, 620.0, Color(0.34, 0.58, 0.7, 0.44))
	for cap_index: int in 5:
		var cap_radius: float = 600.0 - float(cap_index * 62)
		draw_arc(
			planet_center + Vector2(float(cap_index * 18), 0.0),
			cap_radius,
			PI + 0.12,
			TAU - 0.08,
			96,
			Color(0.65, 0.9, 0.94, 0.12 + float(cap_index) * 0.025),
			18.0
		)
	draw_arc(
		planet_center,
		650.0,
		PI,
		TAU,
		128,
		Color(0.69, 0.97, 1.0, 0.72),
		8.0
	)
	draw_arc(
		planet_center,
		668.0,
		PI + 0.08,
		TAU - 0.12,
		128,
		Color(AURORA_GREEN, 0.26),
		11.0
	)
	draw_arc(
		planet_center + Vector2(6.0, -4.0),
		682.0,
		PI + 0.36,
		TAU - 0.48,
		96,
		Color(AURORA_PINK, 0.19),
		7.0
	)


func _draw_distant_ice_layers() -> void:
	var start_x: float = ROUTE_ORIGIN_X + 3800.0
	var end_x: float = ROUTE_ORIGIN_X + route_definition.get_total_distance()
	var far_points: PackedVector2Array = PackedVector2Array()
	var mid_points: PackedVector2Array = PackedVector2Array()
	var point_count: int = ceili((end_x - start_x) / 620.0) + 2
	far_points.append(Vector2(start_x, 620.0))
	mid_points.append(Vector2(start_x, 650.0))
	for index: int in point_count:
		var x: float = start_x + float(index) * 620.0
		var far_y: float = 414.0 - float((index * 47) % 92)
		var mid_y: float = 502.0 - float((index * 71) % 104)
		far_points.append(Vector2(x, far_y))
		mid_points.append(Vector2(x, mid_y))
	far_points.append(Vector2(end_x, 700.0))
	mid_points.append(Vector2(end_x, 700.0))
	draw_colored_polygon(far_points, Color(DISTANT_ICE_BLUE, 0.48))
	draw_colored_polygon(mid_points, Color(MID_ICE_BLUE, 0.36))
	for layer_index: int in 3:
		var ridge_y: float = 466.0 + float(layer_index * 34)
		draw_line(
			Vector2(start_x, ridge_y),
			Vector2(end_x, ridge_y + float(layer_index * 9)),
			Color(0.48, 0.8, 0.88, 0.08 + float(layer_index) * 0.025),
			10.0 + float(layer_index * 6)
		)


func _draw_icefield() -> void:
	var start_x: float = ROUTE_ORIGIN_X + 4500.0
	var end_x: float = ROUTE_ORIGIN_X + route_definition.get_total_distance()
	draw_rect(
		Rect2(start_x, ICE_FLOOR_Y, end_x - start_x, 280.0),
		Color(0.23, 0.52, 0.65, 1.0),
		true
	)
	draw_rect(
		Rect2(start_x, ICE_FLOOR_Y + 34.0, end_x - start_x, 246.0),
		Color(0.07, 0.25, 0.37, 1.0),
		true
	)
	draw_line(
		Vector2(start_x, ICE_FLOOR_Y),
		Vector2(end_x, ICE_FLOOR_Y),
		(
			COLLISION_WARNING
			if _high_contrast_enabled
			else ICE_WHITE
		),
		6.0 if _high_contrast_enabled else 4.0
	)
	if _route_hints_enabled:
		draw_dashed_line(
			Vector2(start_x + 180.0, 450.0),
			Vector2(ROUTE_ORIGIN_X + CAVE_START_DISTANCE - 120.0, 450.0),
			(
				COLLISION_WARNING
				if _high_contrast_enabled
				else Color(0.41, 0.92, 0.88, 0.9)
			),
			4.0 if _high_contrast_enabled else 3.0,
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
			(
				ICE_WHITE
				if _high_contrast_enabled
				else Color(0.71, 0.9, 0.95, 0.8)
			),
			4.0 if _high_contrast_enabled else 3.0
		)
		if index % 4 == 0:
			draw_line(
				Vector2(ridge_x + 8.0, ICE_FLOOR_Y + 12.0),
				Vector2(ridge_x + 38.0, ICE_FLOOR_Y + 62.0),
				Color(0.34, 0.77, 0.86, 0.42),
				2.0
			)


func _draw_branch_corridors() -> void:
	var cave_start_x: float = ROUTE_ORIGIN_X + CAVE_START_DISTANCE
	var cave_end_x: float = ROUTE_ORIGIN_X + CAVE_END_DISTANCE
	draw_rect(
		Rect2(cave_start_x, -80.0, cave_end_x - cave_start_x, 220.0),
		Color(0.16, 0.38, 0.53, 1.0),
		true
	)
	draw_rect(
		Rect2(cave_start_x, 82.0, cave_end_x - cave_start_x, 58.0),
		Color(0.42, 0.72, 0.8, 0.56),
		true
	)
	draw_line(
		Vector2(cave_start_x, 140.0),
		Vector2(cave_end_x, 140.0),
		(
			COLLISION_WARNING
			if _high_contrast_enabled
			else ICE_WHITE
		),
		6.0 if _high_contrast_enabled else 4.0
	)
	for icicle_index: int in 42:
		var icicle_x: float = cave_start_x + 72.0 + float(icicle_index * 164)
		var icicle_height: float = float(22 + ((icicle_index * 37) % 66))
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(icicle_x - 15.0, 140.0),
				Vector2(icicle_x + 15.0, 140.0),
				Vector2(icicle_x + 2.0, 140.0 + icicle_height),
			]),
			Color(0.56, 0.86, 0.92, 0.58)
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
			Color(0.25, 0.56, 0.68, 0.95),
			true
		)
		draw_rect(
			Rect2(
				obstacle_start_x,
				obstacle_y - 12.0,
				obstacle_width,
				24.0
			),
			Color(0.62, 0.91, 0.94, 0.2),
			true
		)
		draw_line(
			Vector2(obstacle_start_x, obstacle_y - 20.0),
			Vector2(obstacle_start_x + obstacle_width, obstacle_y - 20.0),
			(
				COLLISION_WARNING
				if _high_contrast_enabled
				else Color(0.84, 0.98, 1.0, 1.0)
			),
			5.0 if _high_contrast_enabled else 3.0
		)
	var split_x: float = (
		ROUTE_ORIGIN_X + route_definition.get_branch_split_distance()
	)
	var join_x: float = (
		ROUTE_ORIGIN_X + route_definition.get_branch_join_distance()
	)
	if _route_hints_enabled:
		for branch: WhiteNoiseRouteBranch in route_definition.branches:
			if branch == null:
				continue
			draw_dashed_line(
				Vector2(split_x, branch.retry_y),
				Vector2(join_x, branch.retry_y),
				(
					Color(1.0, 0.87, 0.28, 1.0)
					if _high_contrast_enabled
					else branch.guide_color
				),
				4.0 if _high_contrast_enabled else 3.0,
				22.0
			)
	draw_line(
		Vector2(join_x, 125.0),
		Vector2(join_x, 610.0),
		Color(ARCHIVE_LIGHT, 0.82),
		4.0
	)
	for beacon_index: int in 4:
		var beacon_y: float = 182.0 + float(beacon_index * 108)
		draw_circle(
			Vector2(join_x, beacon_y),
			6.0,
			Color(AURORA_PINK, 0.92)
		)


func _draw_aurora_blizzard() -> void:
	var start_x: float = ROUTE_ORIGIN_X + 17000.0
	var end_x: float = ROUTE_ORIGIN_X + 23000.0
	var storm_alpha_scale: float = lerpf(
		0.68,
		1.0,
		_storm_interference_strength
	)
	for band_index: int in 7:
		var band_y: float = 48.0 + float(band_index * 56)
		var band_color: Color = (
			Color(AURORA_GREEN, 0.39 * storm_alpha_scale)
			if band_index % 2 == 0
			else Color(AURORA_PINK, 0.31 * storm_alpha_scale)
		)
		var band_points: PackedVector2Array = PackedVector2Array()
		for point_index: int in 9:
			var progress: float = float(point_index) / 8.0
			var x: float = lerpf(start_x, end_x, progress)
			var wave: float = sin(
				progress * TAU * 1.4 + float(band_index) * 0.72
			) * (22.0 + float(band_index % 3) * 7.0)
			band_points.append(Vector2(x, band_y + wave))
		draw_polyline(
			band_points,
			band_color,
			18.0 + float(band_index % 3) * 5.0,
			true
		)
	for arc_index: int in 12:
		var arc_x: float = start_x + 280.0 + float(arc_index * 470)
		var arc_y: float = 94.0 + float((arc_index * 83) % 360)
		draw_polyline(
			PackedVector2Array([
				Vector2(arc_x - 48.0, arc_y + 12.0),
				Vector2(arc_x - 10.0, arc_y - 24.0),
				Vector2(arc_x + 24.0, arc_y + 6.0),
				Vector2(arc_x + 68.0, arc_y - 32.0),
			]),
			Color(0.72, 0.97, 1.0, 0.32 * storm_alpha_scale),
			3.0
		)
	for line_index: int in get_blizzard_streak_count():
		var x: float = start_x + float((line_index * 173) % 6000)
		var y: float = float(44 + ((line_index * 97) % 520))
		var length: float = 32.0 + float((line_index * 19) % 44)
		draw_line(
			Vector2(x, y),
			Vector2(x - length, y + length * 0.36),
			Color(
				0.86,
				0.98,
				1.0,
				(0.28 + float(line_index % 4) * 0.06)
				* get_visual_noise_scale()
			),
			1.0 if line_index % 3 else 2.0
		)
	if _route_hints_enabled:
		var guide_color := (
			Color(1.0, 0.84, 0.2, 1.0)
			if _high_contrast_enabled
			else Color(0.41, 0.96, 0.88, 0.94)
		)
		draw_dashed_line(
			Vector2(start_x, 300.0),
			Vector2(end_x, 300.0),
			guide_color,
			5.0 if _high_contrast_enabled else 3.0,
			26.0
		)
		for marker_index: int in 6:
			var marker_x: float = start_x + 620.0 + float(marker_index * 930)
			draw_polyline(
				PackedVector2Array([
					Vector2(marker_x - 18.0, 286.0),
					Vector2(marker_x, 300.0),
					Vector2(marker_x - 18.0, 314.0),
				]),
				guide_color,
				4.0 if _high_contrast_enabled else 3.0
			)


func _draw_archive_entrance() -> void:
	var start_x: float = ROUTE_ORIGIN_X + ARCHIVE_START_DISTANCE
	var end_x: float = ROUTE_ORIGIN_X + ARCHIVE_END_DISTANCE
	var signal_clarity: float = get_archive_signal_clarity()
	draw_rect(
		Rect2(start_x, -100.0, end_x - start_x, 230.0),
		Color(0.05, 0.19, 0.29, 1.0),
		true
	)
	for layer_index: int in 5:
		var layer_y: float = -56.0 + float(layer_index * 42)
		draw_rect(
			Rect2(start_x, layer_y, end_x - start_x, 20.0),
			Color(
				0.22,
				0.62 + float(layer_index) * 0.035,
				0.69 + float(layer_index) * 0.03,
				0.1 + float(layer_index) * 0.025
			),
			true
		)
	draw_line(
		Vector2(start_x, 130.0),
		Vector2(end_x, 130.0),
		Color(ARCHIVE_LIGHT, 0.94),
		5.0
	)
	for pillar_index: int in 17:
		var pillar_x: float = start_x + 130.0 + float(pillar_index * 330)
		var pillar_height: float = float(230 + ((pillar_index * 61) % 170))
		draw_rect(
			Rect2(
				pillar_x,
				ICE_FLOOR_Y - pillar_height,
				24.0,
				pillar_height
			),
			Color(0.12, 0.47, 0.54, 0.5),
			true
		)
		draw_rect(
			Rect2(
				pillar_x + 7.0,
				ICE_FLOOR_Y - pillar_height + 18.0,
				10.0,
				pillar_height - 36.0
			),
			Color(ARCHIVE_LIGHT, 0.26 * signal_clarity),
			true
		)
	for memory_row_index: int in 4:
		var row_y: float = 214.0 + float(memory_row_index * 82)
		draw_dashed_line(
			Vector2(start_x + 40.0, row_y),
			Vector2(end_x - 40.0, row_y),
			Color(
				ARCHIVE_LIGHT,
				(0.15 + float(memory_row_index) * 0.035)
				* signal_clarity
			),
			3.0,
			38.0
		)
	for vault_index: int in 14:
		var vault_x: float = start_x + 190.0 + float(vault_index * 390)
		var vault_height: float = float(150 + ((vault_index * 53) % 160))
		draw_rect(
			Rect2(vault_x, 180.0, 190.0, vault_height),
			Color(0.07, 0.25, 0.33, 0.86),
			true
		)
		draw_rect(
			Rect2(vault_x + 10.0, 192.0, 170.0, vault_height - 24.0),
			Color(0.36, 0.86, 0.82, 0.31 * signal_clarity),
			false,
			4.0
		)
		for memory_strip_index: int in 4:
			draw_rect(
				Rect2(
					vault_x + 28.0,
					216.0 + float(memory_strip_index * 44),
					132.0,
					7.0
				),
				Color(
					ARCHIVE_LIGHT,
					(0.24 + float(memory_strip_index) * 0.07)
					* signal_clarity
				),
				true
			)
	var gate_x: float = ROUTE_ORIGIN_X + 26700.0
	if _route_hints_enabled:
		draw_dashed_line(
			Vector2(start_x, 300.0),
			Vector2(end_x, 300.0),
			Color(ARCHIVE_LIGHT, 0.9 * signal_clarity),
			4.0 if _high_contrast_enabled else 3.0,
			24.0
		)
	draw_rect(
		Rect2(gate_x - 90.0, 170.0, 180.0, 390.0),
		Color(0.025, 0.12, 0.18, 1.0),
		true
	)
	draw_rect(
		Rect2(gate_x - 74.0, 190.0, 148.0, 352.0),
		Color(0.14, 0.56, 0.59, 0.72 * signal_clarity),
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
			Color(ARCHIVE_LIGHT, 0.45 * signal_clarity),
			true
		)


func _draw_landing_approach() -> void:
	var beacon_x: float = ROUTE_ORIGIN_X + 31000.0
	for tower_index: int in 7:
		var tower_x: float = (
			ROUTE_ORIGIN_X + 28950.0 + float(tower_index * 710)
		)
		var tower_height: float = float(90 + ((tower_index * 41) % 120))
		draw_rect(
			Rect2(
				tower_x,
				ICE_FLOOR_Y - tower_height,
				42.0,
				tower_height
			),
			Color(0.055, 0.22, 0.29, 0.92),
			true
		)
		draw_rect(
			Rect2(tower_x + 10.0, ICE_FLOOR_Y - tower_height + 18.0, 22.0, 8.0),
			Color(ARCHIVE_LIGHT, 0.7),
			true
		)
	draw_line(
		Vector2(beacon_x, 180.0),
		Vector2(beacon_x, ICE_FLOOR_Y),
		Color(COLLISION_WARNING, 0.92),
		5.0
	)
	for radius: float in [24.0, 48.0, 72.0]:
		draw_arc(
			Vector2(beacon_x, 180.0),
			radius,
			PI,
			TAU,
			24,
			Color(COLLISION_WARNING, 0.48),
			3.0
		)
	if _route_hints_enabled:
		draw_dashed_line(
			Vector2(ROUTE_ORIGIN_X + 28500.0, 300.0),
			Vector2(
				ROUTE_ORIGIN_X + LANDING_CONTACT_DISTANCE,
				LANDING_PAD_Y - 22.0
			),
			Color(COLLISION_WARNING, 0.92),
			4.0 if _high_contrast_enabled else 3.0,
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
		Color(0.035, 0.17, 0.23, 1.0),
		true
	)
	draw_line(
		Vector2(pad_start_x, LANDING_PAD_Y),
		Vector2(pad_end_x, LANDING_PAD_Y),
		COLLISION_WARNING,
		6.0
	)
	for marker_index: int in 9:
		var marker_x: float = pad_start_x + 80.0 + float(marker_index * 130)
		draw_rect(
			Rect2(marker_x, LANDING_PAD_Y + 12.0, 54.0, 8.0),
			Color(ARCHIVE_LIGHT, 0.9),
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
