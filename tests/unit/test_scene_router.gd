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
	return failures
