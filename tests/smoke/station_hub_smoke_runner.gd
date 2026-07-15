extends SceneTree

const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"
const EXPECTED_LABELS: Dictionary[NodePath, String] = {
	NodePath("FeatureLabels/OrderTerminalLabel"): "订单终端",
	NodePath("FeatureLabels/WorkbenchLabel"): "模块工作台",
	NodePath("FeatureLabels/CockpitEntryLabel"): "驾驶舱 / 机库",
	NodePath("FeatureLabels/LaoPiRestLabel"): "老皮休息区",
	NodePath("FeatureLabels/MemorabiliaLabel"): "纪念品墙（空）",
}

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var original_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	var game_state: GameStateModel = root.get_node_or_null("GameState") as GameStateModel
	if game_state != null:
		game_state.reset_runtime_state()
		game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)
	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	var station: StationHub = station_scene.instantiate() as StationHub
	root.add_child(station)
	await process_frame

	var architecture_layer: TileMapLayer = station.get_node(
		"ArchitectureLayer"
	) as TileMapLayer
	_check(station.initialize_layout(), "Station layout did not initialize in the scene tree.")
	_check(
		architecture_layer.get_used_cells().size() == StationHub.GRID_SIZE.x * StationHub.GRID_SIZE.y,
		"Station TileMapLayer is incomplete."
	)
	var camera_rect: Rect2 = station.get_camera_world_rect()
	var spawn: Marker2D = station.get_player_spawn()
	for feature_id: StringName in station.get_required_feature_ids():
		var feature_anchor: Marker2D = station.get_feature_anchor(feature_id)
		var approach_anchor: Marker2D = station.get_feature_approach_anchor(feature_id)
		_check(feature_anchor != null, "Station feature anchor is missing: %s" % feature_id)
		_check(approach_anchor != null, "Station approach anchor is missing: %s" % feature_id)
		if feature_anchor == null or approach_anchor == null:
			continue
		_check(
			camera_rect.encloses(station.get_feature_visual_rect(feature_id)),
			"Station feature leaves the initial 640x360 view: %s" % feature_id
		)
		if spawn != null:
			_check(
				spawn.position.distance_to(approach_anchor.position) <= 340.0,
				"Station feature is not quickly reachable from the entrance: %s" % feature_id
			)

	for label_path: NodePath in EXPECTED_LABELS:
		var feature_label: Label = station.get_node_or_null(label_path) as Label
		_check(feature_label != null, "Station label is missing: %s" % label_path)
		if feature_label != null:
			_check(
				feature_label.text == EXPECTED_LABELS[label_path],
				"Station label did not localize: %s" % label_path
			)
			_check(feature_label.size.x > 0.0, "Station label has no readable width: %s" % label_path)

	_check(
		station.get_state_change_anchors().size() >= 3,
		"Station state-change anchors are missing."
	)

	station.queue_free()
	if game_state != null:
		game_state.reset_runtime_state()
	TranslationServer.set_locale(original_locale)
	await process_frame
	if _failures.is_empty():
		print("[station-hub] PASS: TileMap, collisions, reachability, localization, and state slots.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("[station-hub] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
