extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []

	expect_true(
		SceneRouterService.is_transition_allowed(
			SceneRouterService.Stage.MAIN_MENU,
			SceneRouterService.Stage.STATION
		),
		"MAIN_MENU must transition to STATION.",
		failures
	)
	expect_true(
		SceneRouterService.is_transition_allowed(
			SceneRouterService.Stage.STATION,
			SceneRouterService.Stage.COCKPIT
		),
		"STATION must transition to COCKPIT.",
		failures
	)
	expect_true(
		SceneRouterService.is_transition_allowed(
			SceneRouterService.Stage.COCKPIT,
			SceneRouterService.Stage.FLIGHT
		),
		"COCKPIT must transition to FLIGHT.",
		failures
	)
	expect_true(
		SceneRouterService.is_transition_allowed(
			SceneRouterService.Stage.FLIGHT,
			SceneRouterService.Stage.ARRIVAL
		),
		"FLIGHT must transition to ARRIVAL.",
		failures
	)
	expect_true(
		SceneRouterService.is_transition_allowed(
			SceneRouterService.Stage.ARRIVAL,
			SceneRouterService.Stage.RESULTS
		),
		"ARRIVAL must transition to RESULTS.",
		failures
	)
	expect_true(
		SceneRouterService.is_transition_allowed(
			SceneRouterService.Stage.RESULTS,
			SceneRouterService.Stage.STATION
		),
		"RESULTS must return to STATION.",
		failures
	)
	expect_true(
		not SceneRouterService.is_transition_allowed(
			SceneRouterService.Stage.MAIN_MENU,
			SceneRouterService.Stage.FLIGHT
		),
		"MAIN_MENU must reject a direct FLIGHT transition.",
		failures
	)

	var router: SceneRouterService = SceneRouterService.new()
	var scene_container: Node = Node.new()
	expect_true(
		router.register_scene_container(scene_container),
		"Router must accept a valid scene container.",
		failures
	)
	router.current_stage = SceneRouterService.Stage.COCKPIT
	expect_true(
		router.request_stage_scene(
			SceneRouterService.Stage.FLIGHT,
			"res://scenes/flight/white_noise_flight.tscn"
		),
		"Dedicated White Noise flight scene must be accepted for COCKPIT -> FLIGHT.",
		failures
	)
	expect_true(
		router.current_stage == SceneRouterService.Stage.FLIGHT,
		"Dedicated scene transition must update the router stage.",
		failures
	)

	router.current_stage = SceneRouterService.Stage.COCKPIT
	expect_true(
		not router.request_stage_scene(
			SceneRouterService.Stage.FLIGHT,
			"res://scenes/flight/missing_destination_scene.tscn"
		),
		"Production scene override must reject a missing PackedScene.",
		failures
	)
	expect_true(
		router.current_stage == SceneRouterService.Stage.COCKPIT,
		"Rejected scene override must preserve the current stage.",
		failures
	)
	expect_true(
		not router.request_stage_scene(
			SceneRouterService.Stage.RESULTS,
			"res://scenes/app/results.tscn"
		),
		"Production scene override must still enforce the stage transition graph.",
		failures
	)

	router.unregister_scene_container(scene_container)
	scene_container.free()
	router.free()
	return failures
