extends ProjectTestSuite

const ORDERED_STAGES: PackedInt32Array = [
	SceneRouterService.Stage.STATION,
	SceneRouterService.Stage.COCKPIT,
	SceneRouterService.Stage.FLIGHT,
	SceneRouterService.Stage.ARRIVAL,
	SceneRouterService.Stage.RESULTS,
]
const ORDERED_ROOT_NAMES: PackedStringArray = [
	"Station",
	"Cockpit",
	"Flight",
	"Arrival",
	"Results",
]


func run() -> Array[String]:
	var failures: Array[String] = []
	var router: SceneRouterService = SceneRouterService.new()
	var scene_container: Control = Control.new()

	var registered: bool = router.register_scene_container(scene_container)
	expect_true(registered, "Scene container must register.", failures)
	if not registered:
		_cleanup(router, scene_container)
		return failures

	var started: bool = router.start()
	expect_true(started, "Scene flow must start at MAIN_MENU.", failures)
	if not started:
		_cleanup(router, scene_container)
		return failures

	_expect_stage(
		router,
		scene_container,
		SceneRouterService.Stage.MAIN_MENU,
		"MainMenu",
		failures
	)

	var main_menu_scene: Node = scene_container.get_child(0)
	var invalid_transition_succeeded: bool = router.request_stage(SceneRouterService.Stage.FLIGHT)
	expect_true(not invalid_transition_succeeded, "Invalid transition must be rejected.", failures)
	expect_true(not router.last_error.is_empty(), "Rejected transition must expose a reason.", failures)
	expect_true(
		scene_container.get_child_count() == 1 and scene_container.get_child(0) == main_menu_scene,
		"Rejected transition must keep the active scene unchanged.",
		failures
	)

	for index: int in ORDERED_STAGES.size():
		var requested_stage: int = ORDERED_STAGES[index]
		var transition_succeeded: bool = router.request_stage(requested_stage)
		expect_true(
			transition_succeeded,
			"Expected transition to %s to succeed." % SceneRouterService.get_stage_name(requested_stage),
			failures
		)
		if not transition_succeeded:
			break
		_expect_stage(
			router,
			scene_container,
			requested_stage,
			ORDERED_ROOT_NAMES[index],
			failures
		)

	if OS.is_debug_build():
		var debug_switch_succeeded: bool = router.debug_switch_to_stage(
			SceneRouterService.Stage.MAIN_MENU
		)
		expect_true(debug_switch_succeeded, "Debug switch must bypass normal stage order.", failures)
		if debug_switch_succeeded:
			_expect_stage(
				router,
				scene_container,
				SceneRouterService.Stage.MAIN_MENU,
				"MainMenu",
				failures
			)

	_cleanup(router, scene_container)
	return failures


func _expect_stage(
	router: SceneRouterService,
	scene_container: Control,
	expected_stage: int,
	expected_root_name: String,
	failures: Array[String]
) -> void:
	expect_true(router.current_stage == expected_stage, "Router stage did not update.", failures)
	expect_true(scene_container.get_child_count() == 1, "SceneContainer must have one child.", failures)
	if scene_container.get_child_count() == 1:
		var active_scene: Node = scene_container.get_child(0)
		expect_true(
			String(active_scene.name) == expected_root_name,
			"Unexpected active scene root: %s" % active_scene.name,
			failures
		)


func _cleanup(router: SceneRouterService, scene_container: Control) -> void:
	router.unregister_scene_container(scene_container)
	scene_container.free()
	router.free()
