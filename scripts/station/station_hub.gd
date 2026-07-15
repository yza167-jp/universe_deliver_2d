class_name StationHub
extends Node2D

const BASE_VIEWPORT_SIZE: Vector2 = Vector2(640.0, 360.0)
const CAMERA_SAFE_MARGIN: Vector2 = Vector2(16.0, 16.0)
const TILE_SIZE: Vector2i = Vector2i(16, 16)
const GRID_SIZE: Vector2i = Vector2i(60, 34)
const STATION_SIZE: Vector2 = Vector2(960.0, 544.0)
const WALL_THICKNESS_IN_TILES: int = 3
const TILE_SOURCE_ID: int = 0

const FLOOR_TILE: Vector2i = Vector2i(0, 0)
const WALL_TILE: Vector2i = Vector2i(1, 0)
const PATH_TILE: Vector2i = Vector2i(2, 0)

const REQUIRED_FEATURE_IDS: Array[StringName] = [
	&"order_terminal",
	&"ship_workbench",
	&"cockpit_entry",
	&"lao_pi_rest_area",
	&"memorabilia_wall",
]

const DEEP_SPACE: Color = Color("08111f")
const SPACE_BLUE: Color = Color("142a45")
const WARM_STATION_DARK: Color = Color("2a2430")
const STATION_AMBER: Color = Color("e7a85b")
const FRIENDLY_CYAN: Color = Color("77c9c4")
const COMPANY_CREAM: Color = Color("e8dfc8")
const WARNING_ORANGE: Color = Color("e96a3a")
const MUTED_TEXT: Color = Color("9aa7b5")

var _architecture_layer: TileMapLayer
var _camera: Camera2D
var _player: StationPlayer
var _layout_initialized: bool = false


func _ready() -> void:
	if not initialize_layout():
		push_error("Station hub graybox could not initialize its TileMapLayer.")
	if not initialize_player():
		push_error("Station hub could not initialize its player at the entrance spawn.")


func _physics_process(_delta: float) -> void:
	_update_camera_for_player()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _layout_initialized:
		_localize_feature_labels()


## Builds the code-owned placeholder atlas so the graybox has no external asset dependency.
func initialize_layout() -> bool:
	if _layout_initialized:
		return true
	_architecture_layer = get_node_or_null("ArchitectureLayer") as TileMapLayer
	_camera = get_node_or_null("Camera2D") as Camera2D
	if _architecture_layer == null or _camera == null:
		return false
	_architecture_layer.tile_set = _create_placeholder_tile_set()
	_architecture_layer.clear()
	for y: int in GRID_SIZE.y:
		for x: int in GRID_SIZE.x:
			var cell: Vector2i = Vector2i(x, y)
			_architecture_layer.set_cell(cell, TILE_SOURCE_ID, _get_tile_for_cell(cell))
	_architecture_layer.update_internals()
	_layout_initialized = true
	_localize_feature_labels()
	queue_redraw()
	return true


func get_station_rect() -> Rect2:
	return Rect2(Vector2.ZERO, STATION_SIZE)


func get_walkable_rect() -> Rect2:
	var wall_size: float = float(WALL_THICKNESS_IN_TILES * TILE_SIZE.x)
	return Rect2(
		Vector2(wall_size, wall_size),
		STATION_SIZE - Vector2(wall_size * 2.0, wall_size * 2.0)
	)


func get_camera_world_rect() -> Rect2:
	if _camera == null:
		_camera = get_node_or_null("Camera2D") as Camera2D
	if _camera == null:
		return Rect2()
	return Rect2(_camera.position - BASE_VIEWPORT_SIZE * 0.5, BASE_VIEWPORT_SIZE)


func get_map_area_in_base_viewports() -> float:
	return (STATION_SIZE.x * STATION_SIZE.y) / (
		BASE_VIEWPORT_SIZE.x * BASE_VIEWPORT_SIZE.y
	)


func get_required_feature_ids() -> Array[StringName]:
	return REQUIRED_FEATURE_IDS.duplicate()


func get_feature_anchor(feature_id: StringName) -> Marker2D:
	var node_path: NodePath = NodePath()
	match feature_id:
		&"order_terminal":
			node_path = NodePath("FeatureAnchors/OrderTerminal")
		&"ship_workbench":
			node_path = NodePath("FeatureAnchors/ShipWorkbench")
		&"cockpit_entry":
			node_path = NodePath("FeatureAnchors/CockpitEntry")
		&"lao_pi_rest_area":
			node_path = NodePath("FeatureAnchors/LaoPiRestArea")
		&"memorabilia_wall":
			node_path = NodePath("FeatureAnchors/MemorabiliaWall")
		_:
			return null
	return get_node_or_null(node_path) as Marker2D


func get_player_spawn() -> Marker2D:
	return get_node_or_null("FeatureAnchors/PlayerSpawn") as Marker2D


func initialize_player() -> bool:
	if _player == null:
		_player = get_node_or_null("StationPlayer") as StationPlayer
	var spawn: Marker2D = get_player_spawn()
	if _player == null or spawn == null:
		return false
	_player.position = spawn.position
	var facing_value: Variant = spawn.get_meta("facing", Vector2.UP)
	if facing_value is Vector2:
		_player.set_facing_direction(facing_value as Vector2)
	return true


func get_station_player() -> StationPlayer:
	if _player == null:
		_player = get_node_or_null("StationPlayer") as StationPlayer
	return _player


func get_lao_pi() -> LaoPiStation:
	return get_node_or_null("Characters/LaoPi") as LaoPiStation


func get_tutorial_controller() -> StationTutorialController:
	return get_node_or_null("StationTutorialController") as StationTutorialController


func get_interactables() -> Array[Interactable2D]:
	var interactables: Array[Interactable2D] = []
	var interaction_root: Node = get_node_or_null("Interactables")
	if interaction_root == null:
		return interactables
	for child: Node in interaction_root.get_children():
		if child is Interactable2D:
			interactables.append(child as Interactable2D)
	return interactables


func get_feature_approach_anchor(feature_id: StringName) -> Marker2D:
	var node_path: NodePath = NodePath()
	match feature_id:
		&"order_terminal":
			node_path = NodePath("ApproachAnchors/OrderTerminalApproach")
		&"ship_workbench":
			node_path = NodePath("ApproachAnchors/ShipWorkbenchApproach")
		&"cockpit_entry":
			node_path = NodePath("ApproachAnchors/CockpitEntryApproach")
		&"lao_pi_rest_area":
			node_path = NodePath("ApproachAnchors/LaoPiRestApproach")
		&"memorabilia_wall":
			node_path = NodePath("ApproachAnchors/MemorabiliaApproach")
		_:
			return null
	return get_node_or_null(node_path) as Marker2D


func get_state_change_anchors() -> Array[Marker2D]:
	var anchors: Array[Marker2D] = []
	var anchor_root: Node = get_node_or_null("StateChangeAnchors")
	if anchor_root == null:
		return anchors
	for child: Node in anchor_root.get_children():
		if child is Marker2D:
			anchors.append(child as Marker2D)
	return anchors


func get_feature_visual_rect(feature_id: StringName) -> Rect2:
	var anchor: Marker2D = get_feature_anchor(feature_id)
	if anchor == null:
		return Rect2()
	var feature_size: Vector2 = Vector2.ZERO
	match feature_id:
		&"order_terminal":
			feature_size = Vector2(88.0, 64.0)
		&"ship_workbench":
			feature_size = Vector2(120.0, 56.0)
		&"cockpit_entry":
			feature_size = Vector2(128.0, 52.0)
		&"lao_pi_rest_area":
			feature_size = Vector2(112.0, 60.0)
		&"memorabilia_wall":
			feature_size = Vector2(112.0, 56.0)
	return Rect2(anchor.position - feature_size * 0.5, feature_size)


func _draw() -> void:
	if not _layout_initialized:
		return
	_draw_order_terminal(get_feature_visual_rect(&"order_terminal"))
	_draw_workbench(get_feature_visual_rect(&"ship_workbench"))
	_draw_cockpit_entry(get_feature_visual_rect(&"cockpit_entry"))
	_draw_rest_area(get_feature_visual_rect(&"lao_pi_rest_area"))
	_draw_memorabilia_wall(get_feature_visual_rect(&"memorabilia_wall"))
	_draw_entrance_marker()


func _create_placeholder_tile_set() -> TileSet:
	var atlas_image: Image = Image.create(
		TILE_SIZE.x * 3,
		TILE_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	for tile_index: int in 3:
		for y: int in TILE_SIZE.y:
			for x: int in TILE_SIZE.x:
				atlas_image.set_pixel(
					tile_index * TILE_SIZE.x + x,
					y,
					_get_placeholder_pixel(tile_index, x, y)
				)

	var atlas_texture: ImageTexture = ImageTexture.create_from_image(atlas_image)
	var atlas_source: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas_source.texture = atlas_texture
	atlas_source.texture_region_size = TILE_SIZE
	for tile_index: int in 3:
		atlas_source.create_tile(Vector2i(tile_index, 0))

	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = TILE_SIZE
	tile_set.add_source(atlas_source, TILE_SOURCE_ID)
	return tile_set


func _get_placeholder_pixel(tile_index: int, x: int, y: int) -> Color:
	match tile_index:
		0:
			if x == 0 or y == 0:
				return WARM_STATION_DARK.lightened(0.08)
			if ((x >> 2) + (y >> 2)) % 2 == 0:
				return WARM_STATION_DARK
			return WARM_STATION_DARK.darkened(0.06)
		1:
			if x <= 1 or y <= 1 or x >= TILE_SIZE.x - 2 or y >= TILE_SIZE.y - 2:
				return FRIENDLY_CYAN.darkened(0.45)
			if x == 7 or x == 8:
				return SPACE_BLUE.lightened(0.12)
			return SPACE_BLUE
		2:
			if x == 0 or y == 0:
				return STATION_AMBER.darkened(0.55)
			if x == 7 or x == 8:
				return STATION_AMBER.darkened(0.25)
			return WARM_STATION_DARK.lightened(0.04)
	return DEEP_SPACE


func _get_tile_for_cell(cell: Vector2i) -> Vector2i:
	if (
		cell.x < WALL_THICKNESS_IN_TILES
		or cell.y < WALL_THICKNESS_IN_TILES
		or cell.x >= GRID_SIZE.x - WALL_THICKNESS_IN_TILES
		or cell.y >= GRID_SIZE.y - WALL_THICKNESS_IN_TILES
	):
		return WALL_TILE
	var on_vertical_route: bool = cell.x in [29, 30] and cell.y >= 6 and cell.y <= 28
	var on_horizontal_route: bool = cell.y in [16, 17] and cell.x >= 12 and cell.x <= 47
	if on_vertical_route or on_horizontal_route:
		return PATH_TILE
	return FLOOR_TILE


func _draw_order_terminal(rect: Rect2) -> void:
	draw_rect(rect, SPACE_BLUE.lightened(0.08), true)
	draw_rect(rect, FRIENDLY_CYAN, false, 3.0)
	var screen_rect: Rect2 = rect.grow(-10.0)
	screen_rect.size.y -= 12.0
	draw_rect(screen_rect, DEEP_SPACE, true)
	draw_rect(screen_rect, COMPANY_CREAM.darkened(0.18), false, 2.0)
	for index: int in 3:
		draw_circle(
			Vector2(rect.position.x + 18.0 + float(index * 16), rect.end.y - 8.0),
			3.0,
			STATION_AMBER
		)


func _draw_workbench(rect: Rect2) -> void:
	draw_rect(rect, WARM_STATION_DARK.lightened(0.14), true)
	draw_rect(rect, STATION_AMBER, false, 3.0)
	draw_rect(Rect2(rect.position + Vector2(8.0, 10.0), Vector2(104.0, 14.0)), SPACE_BLUE, true)
	for index: int in 4:
		draw_rect(
			Rect2(rect.position + Vector2(14.0 + float(index * 24), 32.0), Vector2(12.0, 12.0)),
			FRIENDLY_CYAN.darkened(float(index) * 0.08),
			true
		)


func _draw_cockpit_entry(rect: Rect2) -> void:
	draw_rect(rect, SPACE_BLUE.darkened(0.12), true)
	draw_rect(rect, STATION_AMBER, false, 4.0)
	draw_line(
		Vector2(rect.get_center().x, rect.position.y + 5.0),
		Vector2(rect.get_center().x, rect.end.y - 5.0),
		FRIENDLY_CYAN,
		2.0
	)
	draw_rect(Rect2(rect.position + Vector2(12.0, 10.0), Vector2(8.0, 32.0)), WARNING_ORANGE, true)
	draw_rect(Rect2(rect.end - Vector2(20.0, 42.0), Vector2(8.0, 32.0)), WARNING_ORANGE, true)


func _draw_rest_area(rect: Rect2) -> void:
	draw_rect(rect, WARM_STATION_DARK.lightened(0.18), true)
	draw_rect(rect, STATION_AMBER.darkened(0.12), false, 3.0)
	draw_rect(Rect2(rect.position + Vector2(8.0, 10.0), Vector2(66.0, 38.0)), SPACE_BLUE, true)
	draw_circle(rect.position + Vector2(90.0, 30.0), 14.0, FRIENDLY_CYAN.darkened(0.22))
	draw_circle(rect.position + Vector2(90.0, 30.0), 6.0, COMPANY_CREAM.darkened(0.2))


func _draw_memorabilia_wall(rect: Rect2) -> void:
	draw_rect(rect, WARM_STATION_DARK.lightened(0.1), true)
	draw_rect(rect, MUTED_TEXT, false, 3.0)
	for row: int in 2:
		for column: int in 4:
			var frame_rect: Rect2 = Rect2(
				rect.position + Vector2(9.0 + float(column * 25), 8.0 + float(row * 23)),
				Vector2(18.0, 16.0)
			)
			var frame_color: Color = COMPANY_CREAM.darkened(0.48)
			if row == 0 and column == 0:
				frame_color = FRIENDLY_CYAN
			draw_rect(frame_rect, DEEP_SPACE, true)
			draw_rect(frame_rect, frame_color, false, 2.0)


func _draw_entrance_marker() -> void:
	var spawn: Marker2D = get_player_spawn()
	if spawn == null:
		return
	for offset: float in [-20.0, 0.0, 20.0]:
		var center: Vector2 = spawn.position + Vector2(offset, 4.0)
		draw_polyline(
			PackedVector2Array([
				center + Vector2(-7.0, 6.0),
				center,
				center + Vector2(7.0, 6.0),
			]),
			STATION_AMBER,
			3.0
		)


func _localize_feature_labels() -> void:
	_set_label_text("FeatureLabels/StationTitleLabel", "UI_STATION_HUB_TITLE")
	_set_label_text("FeatureLabels/OrderTerminalLabel", "UI_STATION_ORDER_TERMINAL")
	_set_label_text("FeatureLabels/WorkbenchLabel", "UI_STATION_WORKBENCH")
	_set_label_text("FeatureLabels/CockpitEntryLabel", "UI_STATION_COCKPIT_ENTRY")
	_set_label_text("FeatureLabels/LaoPiRestLabel", "UI_STATION_LAO_PI_REST")
	_set_label_text("FeatureLabels/MemorabiliaLabel", "UI_STATION_MEMORABILIA_WALL")
	_set_label_text("FeatureLabels/EntranceLabel", "UI_STATION_ENTRANCE")


func _set_label_text(label_path: NodePath, localization_key: String) -> void:
	var feature_label: Label = get_node_or_null(label_path) as Label
	if feature_label != null:
		feature_label.text = tr(localization_key)


func _update_camera_for_player() -> void:
	if _camera == null:
		_camera = get_node_or_null("Camera2D") as Camera2D
	if _player == null:
		_player = get_station_player()
	if _camera == null or _player == null:
		return
	var half_viewport: Vector2 = BASE_VIEWPORT_SIZE * 0.5
	var next_position: Vector2 = _camera.position
	var safe_min: Vector2 = next_position - half_viewport + CAMERA_SAFE_MARGIN
	var safe_max: Vector2 = next_position + half_viewport - CAMERA_SAFE_MARGIN
	if _player.position.x < safe_min.x:
		next_position.x -= safe_min.x - _player.position.x
	elif _player.position.x > safe_max.x:
		next_position.x += _player.position.x - safe_max.x
	if _player.position.y < safe_min.y:
		next_position.y -= safe_min.y - _player.position.y
	elif _player.position.y > safe_max.y:
		next_position.y += _player.position.y - safe_max.y
	next_position.x = clampf(
		next_position.x,
		half_viewport.x,
		STATION_SIZE.x - half_viewport.x
	)
	next_position.y = clampf(
		next_position.y,
		half_viewport.y,
		STATION_SIZE.y - half_viewport.y
	)
	_camera.position = next_position
