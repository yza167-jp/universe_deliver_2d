extends ProjectTestSuite

const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	var scene_resource: Resource = load(MAIN_SCENE_PATH)
	var packed_scene: PackedScene = scene_resource as PackedScene

	if packed_scene == null:
		failures.append("Main scene could not be loaded as PackedScene: %s" % MAIN_SCENE_PATH)
		return failures

	var main_scene: Node = packed_scene.instantiate()
	expect_true(main_scene.name == &"Main", "Main scene root must be named Main.", failures)
	expect_true(
		main_scene.get_node_or_null(NodePath("Frame/Content/Title")) != null,
		"Main scene must contain its title label.",
		failures
	)
	expect_true(
		main_scene.get_node_or_null(NodePath("Frame/Content/Status")) != null,
		"Main scene must contain its status label.",
		failures
	)
	main_scene.free()
	return failures
