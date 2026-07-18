extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	var course: FlightLabCourse = FlightLabCourse.new()
	var tuning: FlightTuning = FlightTuning.new()

	expect_true(
		course.get_exercise_count() == 5
		and course.get_completed_count() == 0
		and course.get_current_exercise() == FlightLabCourse.Exercise.ASSIST_HOVER,
		"The Gate B course must start with five incomplete exercises.",
		failures
	)

	for preset: float in [0.0, 0.75, 1.0]:
		expect_true(
			course.record_assist_preset(preset),
			"Each supported assist preset must be recordable.",
			failures
		)
	course.record_flight_sample(
		1.0,
		0.0,
		0.0,
		1.0,
		Vector2.ZERO,
		0.0,
		0.0,
		tuning
	)
	expect_true(
		not course.is_exercise_complete(FlightLabCourse.Exercise.ASSIST_HOVER),
		"Deep-space stillness must not count as atmospheric hover.",
		failures
	)
	course.record_flight_sample(
		FlightLabCourse.HOVER_HOLD_SECONDS,
		1.0,
		1.0,
		1.0,
		Vector2(12.0, 2.0),
		0.0,
		0.0,
		tuning
	)
	expect_true(
		course.is_exercise_complete(FlightLabCourse.Exercise.ASSIST_HOVER),
		"All three presets plus a stable atmospheric hover must complete exercise one.",
		failures
	)

	course.record_flight_sample(
		1.0 / 60.0,
		1.0,
		1.0,
		0.75,
		Vector2(170.0, tuning.dive_min_downward_speed),
		0.0,
		1.0,
		tuning
	)
	expect_true(
		course.is_exercise_complete(FlightLabCourse.Exercise.DIVE)
		and not course.is_exercise_complete(
			FlightLabCourse.Exercise.BRAKE_PULL_UP
		),
		"Crossing the configured downward-speed threshold must record only the dive.",
		failures
	)
	course.record_flight_sample(
		1.0 / 60.0,
		1.0,
		1.0,
		0.75,
		Vector2(120.0, 120.0),
		1.0,
		-1.0,
		tuning
	)
	course.record_flight_sample(
		1.0 / 60.0,
		1.0,
		1.0,
		0.75,
		Vector2(80.0, tuning.late_pull_up_recovery_downward_speed),
		1.0,
		-1.0,
		tuning
	)
	expect_true(
		course.is_exercise_complete(FlightLabCourse.Exercise.BRAKE_PULL_UP),
		"Braking and pitching up after a dive must record recovery below the tuned threshold.",
		failures
	)

	course.record_impact(FlightCollisionResult.Severity.GRAZE)
	course.record_impact(FlightCollisionResult.Severity.FATAL)
	expect_true(
		not course.is_exercise_complete(
			FlightLabCourse.Exercise.COLLISION_RETRY
		),
		"Impact bands alone must not stand in for an actual failed run.",
		failures
	)
	course.record_flight_failure()
	expect_true(
		course.is_exercise_complete(FlightLabCourse.Exercise.COLLISION_RETRY),
		"A nonfatal impact and a fatal failed run must complete the retry exercise.",
		failures
	)

	course.record_laser_target(FlightLabCourse.SMALL_ASTEROID_ID, true)
	expect_true(
		not course.is_exercise_complete(FlightLabCourse.Exercise.LASER),
		"Destroying only one asteroid type must keep the laser exercise incomplete.",
		failures
	)
	course.record_laser_target(FlightLabCourse.LARGE_ASTEROID_ID, true)
	expect_true(
		course.is_complete()
		and course.get_completed_count() == course.get_exercise_count()
		and course.get_current_exercise() == FlightLabCourse.Exercise.COUNT,
		"Both laser targets must finish the five-exercise course without grading feel.",
		failures
	)

	course.reset()
	expect_true(
		course.get_completed_count() == 0
		and not course.record_assist_preset(0.42),
		"Reset must clear progress and unsupported assist values must be ignored.",
		failures
	)
	return failures
