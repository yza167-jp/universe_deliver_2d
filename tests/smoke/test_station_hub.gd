extends ProjectTestSuite

const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"
const MAX_FEATURE_DISTANCE_FROM_SPAWN: float = 340.0
const CENTRAL_CLEARANCE: Rect2 = Rect2(376.0, 160.0, 208.0, 240.0)
const PLAYER_CLEARANCE: float = 10.0
const CONNECTIVITY_STEP: float = 16.0
const OBJECTIVE_MAX_SAFE_WIDTH: float = (640.0 - 32.0) * 0.4


func run() -> Array[String]:
	var failures: Array[String] = []
	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	var station: StationHub = station_scene.instantiate() as StationHub
	expect_true(station != null, "Station scene must instantiate as StationHub.", failures)
	if station == null:
		return failures

	expect_true(station.initialize_layout(), "Station graybox must initialize.", failures)
	var architecture_layer: TileMapLayer = station.get_node(
		"ArchitectureLayer"
	) as TileMapLayer
	expect_true(architecture_layer.tile_set != null, "Station must own a TileSet.", failures)
	expect_true(
		architecture_layer.get_used_cells().size() == StationHub.GRID_SIZE.x * StationHub.GRID_SIZE.y,
		"TileMapLayer must cover the complete station footprint.",
		failures
	)

	var map_area_in_viewports: float = station.get_map_area_in_base_viewports()
	expect_true(
		map_area_in_viewports >= 2.0 and map_area_in_viewports <= 3.0,
		"Station must occupy roughly 2-3 base viewports, got %.2f." % map_area_in_viewports,
		failures
	)

	var modal_coordinator: StationModalCoordinator = station.get_modal_coordinator()
	expect_true(modal_coordinator != null, "Station must own one modal priority coordinator.", failures)
	var objective: Control = station.get_node_or_null(
		"TutorialUILayer/TutorialObjective"
	) as Control
	var objective_label: Label = station.get_node_or_null(
		"TutorialUILayer/TutorialObjective/Panel/TutorialObjectiveLabel"
	) as Label
	expect_true(objective != null, "Station objective HUD is missing.", failures)
	expect_true(objective_label != null, "Station objective label is missing.", failures)
	if objective != null:
		expect_true(
			objective.size.x <= OBJECTIVE_MAX_SAFE_WIDTH
			and objective.size.y <= 40.0,
			"Objective HUD must stay compact and within 40 percent of safe width.",
			failures
		)
		expect_true(
			objective.position.x + objective.size.x < 320.0,
			"Objective HUD must not cover the central station route.",
			failures
		)
	if objective_label != null:
		expect_true(
			objective_label.max_lines_visible == 2,
			"Objective HUD must use at most two lines.",
			failures
		)

	var spawn: Marker2D = station.get_player_spawn()
	expect_true(spawn != null, "Station entrance spawn must exist.", failures)
	if spawn != null:
		expect_true(
			station.get_walkable_rect().has_point(spawn.position),
			"Station entrance spawn must be inside walkable bounds.",
			failures
		)

	var collision_rects: Array[Rect2] = _get_collision_rects(station)
	var camera_rect: Rect2 = station.get_camera_world_rect()
	for feature_id: StringName in station.get_required_feature_ids():
		var anchor: Marker2D = station.get_feature_anchor(feature_id)
		expect_true(anchor != null, "Missing station feature: %s" % feature_id, failures)
		if anchor == null:
			continue
		expect_true(
			station.get_walkable_rect().has_point(anchor.position),
			"Feature anchor must be reachable inside station bounds: %s" % feature_id,
			failures
		)
		expect_true(
			camera_rect.encloses(station.get_feature_visual_rect(feature_id)),
			"Feature must remain readable in the initial 640x360 view: %s" % feature_id,
			failures
		)
		var approach_anchor: Marker2D = station.get_feature_approach_anchor(feature_id)
		expect_true(
			approach_anchor != null,
			"Missing station approach point: %s" % feature_id,
			failures
		)
		if approach_anchor != null:
			expect_true(
				camera_rect.has_point(approach_anchor.position),
				"Feature approach point leaves the initial view: %s" % feature_id,
				failures
			)
			expect_true(
				not _is_point_blocked(approach_anchor.position, collision_rects),
				"Feature approach point overlaps collision clearance: %s" % feature_id,
				failures
			)
		if spawn != null and approach_anchor != null:
			expect_true(
				spawn.position.distance_to(approach_anchor.position)
				<= MAX_FEATURE_DISTANCE_FROM_SPAWN,
				"Feature is too far from the entrance for a compact hub: %s" % feature_id,
				failures
			)
	if spawn != null:
		expect_true(
			_all_walkable_cells_connected(
				station.get_walkable_rect(),
				spawn.position,
				collision_rects
			),
			"Station collision layout contains an unreachable pocket or dead corner.",
			failures
		)

	var state_anchors: Array[Marker2D] = station.get_state_change_anchors()
	expect_true(
		state_anchors.size() >= 3,
		"Station must reserve multiple visible state-change slots.",
		failures
	)
	for state_anchor: Marker2D in state_anchors:
		expect_true(
			not StringName(state_anchor.get_meta("state_change_id", &"")).is_empty(),
			"Every state-change anchor must have a stable ID.",
			failures
		)

	var collision_root: Node = station.get_node("CollisionBodies")
	expect_true(
		collision_root.get_child_count() >= 8,
		"Station must include outer walls and feature collisions.",
		failures
	)
	for child: Node in collision_root.get_children():
		var body: StaticBody2D = child as StaticBody2D
		if body == null:
			continue
		var collision_shape: CollisionShape2D = body.get_node_or_null(
			"CollisionShape2D"
		) as CollisionShape2D
		if collision_shape == null or not collision_shape.shape is RectangleShape2D:
			continue
		var rectangle_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
		var collision_rect: Rect2 = Rect2(
			body.position + collision_shape.position - rectangle_shape.size * 0.5,
			rectangle_shape.size
		)
		expect_true(
			not collision_rect.intersects(CENTRAL_CLEARANCE),
			"Collision blocks the main circulation area: %s" % body.name,
			failures
		)

	station.free()
	return failures


func _get_collision_rects(station: StationHub) -> Array[Rect2]:
	var collision_rects: Array[Rect2] = []
	var collision_root: Node = station.get_node("CollisionBodies")
	for child: Node in collision_root.get_children():
		var body: StaticBody2D = child as StaticBody2D
		if body == null:
			continue
		var collision_shape: CollisionShape2D = body.get_node_or_null(
			"CollisionShape2D"
		) as CollisionShape2D
		if collision_shape == null or not collision_shape.shape is RectangleShape2D:
			continue
		var rectangle_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
		collision_rects.append(Rect2(
			body.position + collision_shape.position - rectangle_shape.size * 0.5,
			rectangle_shape.size
		))
	return collision_rects


func _is_point_blocked(point: Vector2, collision_rects: Array[Rect2]) -> bool:
	for collision_rect: Rect2 in collision_rects:
		if collision_rect.grow(PLAYER_CLEARANCE).has_point(point):
			return true
	return false


func _all_walkable_cells_connected(
	walkable_rect: Rect2,
	start_position: Vector2,
	collision_rects: Array[Rect2]
) -> bool:
	var columns: int = floori(walkable_rect.size.x / CONNECTIVITY_STEP)
	var rows: int = floori(walkable_rect.size.y / CONNECTIVITY_STEP)
	var open_cells: Dictionary[Vector2i, bool] = {}
	for y: int in rows:
		for x: int in columns:
			var cell: Vector2i = Vector2i(x, y)
			var sample_position: Vector2 = walkable_rect.position + Vector2(
				(float(x) + 0.5) * CONNECTIVITY_STEP,
				(float(y) + 0.5) * CONNECTIVITY_STEP
			)
			if not _is_point_blocked(sample_position, collision_rects):
				open_cells[cell] = true

	var start_cell: Vector2i = Vector2i(
		floori((start_position.x - walkable_rect.position.x) / CONNECTIVITY_STEP),
		floori((start_position.y - walkable_rect.position.y) / CONNECTIVITY_STEP)
	)
	if not open_cells.has(start_cell):
		return false

	var pending: Array[Vector2i] = [start_cell]
	var visited: Dictionary[Vector2i, bool] = {}
	visited[start_cell] = true
	var next_index: int = 0
	var neighbor_offsets: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]
	while next_index < pending.size():
		var current: Vector2i = pending[next_index]
		next_index += 1
		for neighbor_offset: Vector2i in neighbor_offsets:
			var neighbor: Vector2i = current + neighbor_offset
			if open_cells.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				pending.append(neighbor)
	return visited.size() == open_cells.size()
