extends ProjectTestSuite

const MAIN_SCENE_PATH: String = "res://scenes/app/app.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	var scene_resource: Resource = load(MAIN_SCENE_PATH)
	var packed_scene: PackedScene = scene_resource as PackedScene

	if packed_scene == null:
		failures.append("Main scene could not be loaded as PackedScene: %s" % MAIN_SCENE_PATH)
		return failures

	var main_scene: Node = packed_scene.instantiate()
	expect_true(main_scene.name == &"App", "Main scene root must be named App.", failures)
	expect_true(
		main_scene.get_node_or_null(NodePath("SceneContainer")) != null,
		"App scene must contain SceneContainer.",
		failures
	)
	expect_true(
		main_scene.get_node_or_null(NodePath("PersistentUI")) != null,
		"App scene must contain PersistentUI.",
		failures
	)
	expect_true(
		main_scene.get_node_or_null(NodePath("TransitionLayer")) != null,
		"App scene must contain TransitionLayer.",
		failures
	)
	expect_true(
		main_scene.get_node_or_null(NodePath("DebugLayer")) != null,
		"App scene must contain DebugLayer.",
		failures
	)
	var debug_layer: CanvasLayer = main_scene.get_node_or_null(
		NodePath("DebugLayer")
	) as CanvasLayer
	if debug_layer != null:
		expect_true(
			not debug_layer.visible,
			"Player-facing startup must keep the debug layer hidden by default.",
			failures
		)
	expect_true(
		not UniverseDeliverApp.should_show_debug_ui(true, PackedStringArray()),
		"A debug build alone must not expose developer controls.",
		failures
	)
	expect_true(
		UniverseDeliverApp.should_show_debug_ui(
			true,
			PackedStringArray([UniverseDeliverApp.DEBUG_UI_ARGUMENT])
		),
		"The explicit debug UI argument must enable developer controls in debug builds.",
		failures
	)
	expect_true(
		not UniverseDeliverApp.should_show_debug_ui(
			false,
			PackedStringArray([UniverseDeliverApp.DEBUG_UI_ARGUMENT])
		),
		"Release builds must ignore the debug UI argument.",
		failures
	)
	expect_true(
		UniverseDeliverApp.should_start_in_flight_lab(
			true,
			PackedStringArray([UniverseDeliverApp.DEBUG_FLIGHT_LAB_ARGUMENT])
		),
		"The explicit Flight Lab argument must enable the direct debug route.",
		failures
	)
	expect_true(
		not UniverseDeliverApp.should_start_in_flight_lab(
			false,
			PackedStringArray([UniverseDeliverApp.DEBUG_FLIGHT_LAB_ARGUMENT])
		),
		"Release builds must ignore the direct Flight Lab argument.",
		failures
	)
	main_scene.free()
	return failures
