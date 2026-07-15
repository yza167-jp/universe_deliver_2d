extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	_check_normal_order(failures)
	_check_terminal_before_lao_pi(failures)
	_check_all_interactions_before_movement(failures)
	_check_completed_state(failures)
	return failures


func _check_normal_order(failures: Array[String]) -> void:
	var progress: StationTutorialProgress = StationTutorialProgress.new()
	expect_true(
		progress.get_requirement() == StationTutorialProgress.Requirement.MOVE,
		"Tutorial must start with movement.",
		failures
	)
	progress.record_movement(32.0, 32.0)
	expect_true(
		progress.get_requirement() == StationTutorialProgress.Requirement.LAO_PI_INTERACTION,
		"Movement must advance to Lao Pi interaction.",
		failures
	)
	progress.record_interaction(StationTutorialProgress.LAO_PI_INTERACTION_ID)
	expect_true(
		progress.get_requirement()
		== StationTutorialProgress.Requirement.ORDER_TERMINAL_INTERACTION,
		"Lao Pi interaction must advance to the order terminal.",
		failures
	)
	progress.record_interaction(StationTutorialProgress.ORDER_TERMINAL_INTERACTION_ID)
	expect_true(progress.is_complete(), "Normal tutorial order must complete.", failures)


func _check_terminal_before_lao_pi(failures: Array[String]) -> void:
	var progress: StationTutorialProgress = StationTutorialProgress.new()
	progress.record_interaction(StationTutorialProgress.ORDER_TERMINAL_INTERACTION_ID)
	progress.record_movement(40.0, 32.0)
	expect_true(
		progress.get_requirement() == StationTutorialProgress.Requirement.LAO_PI_INTERACTION,
		"An early terminal click must be stored without skipping Lao Pi.",
		failures
	)
	progress.record_interaction(StationTutorialProgress.LAO_PI_INTERACTION_ID)
	expect_true(
		progress.is_complete(),
		"Stored terminal interaction must complete after Lao Pi is reached.",
		failures
	)


func _check_all_interactions_before_movement(failures: Array[String]) -> void:
	var progress: StationTutorialProgress = StationTutorialProgress.new()
	progress.record_interaction(StationTutorialProgress.LAO_PI_INTERACTION_ID)
	progress.record_interaction(StationTutorialProgress.ORDER_TERMINAL_INTERACTION_ID)
	expect_true(
		progress.get_requirement() == StationTutorialProgress.Requirement.MOVE,
		"Early interactions must not bypass the movement lesson.",
		failures
	)
	progress.record_movement(48.0, 32.0)
	expect_true(
		progress.is_complete(),
		"Pre-recorded interactions must collapse safely after movement.",
		failures
	)


func _check_completed_state(failures: Array[String]) -> void:
	var progress: StationTutorialProgress = StationTutorialProgress.new(true)
	expect_true(progress.is_complete(), "Saved completion must restore as complete.", failures)
	expect_true(
		progress.has_completed_movement()
		and progress.has_interacted_with_lao_pi()
		and progress.has_inspected_order_terminal(),
		"Restored completion must include every tutorial fact.",
		failures
	)
