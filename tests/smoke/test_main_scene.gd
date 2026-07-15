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
	main_scene.free()
	return failures
