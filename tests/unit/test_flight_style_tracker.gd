extends ProjectTestSuite

const TUNING_PATH: String = "res://data/tuning/flight_tuning_m0.tres"


func run() -> Array[String]:
	var failures: Array[String] = []
	var tuning: FlightTuning = load(TUNING_PATH) as FlightTuning
	expect_true(tuning != null, "M0 flight tuning must load for style tests.", failures)
	if tuning == null:
		return failures

	_test_dive_classification(tuning, failures)
	_test_glide_classification(tuning, failures)
	_test_balanced_and_tunable_thresholds(tuning, failures)
	_test_late_pull_up_and_attempt_metrics(tuning, failures)
	_test_normalized_risk(failures)
	return failures


func _test_dive_classification(
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var run_state: OrderRunState = OrderRunState.new()
	run_state.reset(&"order_dive_test")
	var tracker: FlightStyleTracker = FlightStyleTracker.new()
	expect_true(tracker.begin(run_state), "Dive tracker must begin.", failures)
	for _sample_index: int in 120:
		tracker.record_sample(
			1.0 / 60.0,
			Vector2(110.0, 230.0),
			0.82,
			tuning
		)
	expect_true(
		tracker.get_candidate_style(tuning) == FlightStyleTracker.STYLE_DIVE,
		"A fast, high-risk descent must produce a DIVE candidate.",
		failures
	)
	expect_true(
		tracker.finalize(tuning) == FlightStyleTracker.STYLE_DIVE
		and run_state.entry_style == FlightStyleTracker.STYLE_DIVE
		and not tracker.is_tracking(),
		"Finalizing must write DIVE into the bound order-run result.",
		failures
	)
	expect_true(
		is_equal_approx(run_state.entry_duration, 2.0)
		and is_equal_approx(run_state.max_downward_speed, 230.0)
		and run_state.max_total_speed > 250.0
		and is_equal_approx(run_state.max_risk_or_heat, 0.82),
		"Dive tracking must retain duration, speed, and maximum risk metrics.",
		failures
	)


func _test_glide_classification(
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var run_state: OrderRunState = OrderRunState.new()
	run_state.reset(&"order_glide_test")
	var tracker: FlightStyleTracker = FlightStyleTracker.new()
	tracker.begin(run_state)
	for _sample_index: int in 9:
		tracker.record_sample(1.0, Vector2(80.0, 60.0), 0.2, tuning)
	expect_true(
		tracker.record_scenic_trigger(&"scenic_ridge")
		and not tracker.record_scenic_trigger(&"scenic_ridge")
		and tracker.record_scenic_trigger(&"scenic_storm")
		and run_state.scenic_trigger_count == 2,
		"Scenic triggers must be unique and counted once per stable ID.",
		failures
	)
	expect_true(
		tracker.get_candidate_style(tuning) == FlightStyleTracker.STYLE_GLIDE
		and tracker.finalize(tuning) == FlightStyleTracker.STYLE_GLIDE,
		"A long, calm route with scenic triggers must classify as GLIDE.",
		failures
	)


func _test_balanced_and_tunable_thresholds(
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var run_state: OrderRunState = OrderRunState.new()
	run_state.reset(&"order_balanced_test")
	run_state.entry_duration = 7.0
	run_state.max_downward_speed = 130.0
	run_state.max_total_speed = 180.0
	run_state.max_risk_or_heat = 0.5
	run_state.scenic_trigger_count = 1
	expect_true(
		FlightStyleTracker.classify(run_state, tuning)
		== FlightStyleTracker.STYLE_BALANCED,
		"A middle trajectory must remain BALANCED.",
		failures
	)

	var replacement_tuning: FlightTuning = tuning.duplicate(true) as FlightTuning
	replacement_tuning.dive_min_downward_speed = 120.0
	replacement_tuning.dive_min_risk_or_heat = 1.0
	replacement_tuning.dive_short_entry_min_total_speed = 1000.0
	replacement_tuning.dive_max_scenic_trigger_count = 1
	expect_true(
		FlightStyleTracker.classify(run_state, replacement_tuning)
		== FlightStyleTracker.STYLE_DIVE,
		"Replacing tuning thresholds must change classification without formula edits.",
		failures
	)
	replacement_tuning.dive_min_downward_speed = 500.0
	replacement_tuning.dive_max_scenic_trigger_count = 0
	expect_true(
		FlightStyleTracker.classify(run_state, replacement_tuning)
		== FlightStyleTracker.STYLE_BALANCED,
		"Raising configured dive thresholds must restore the balanced result.",
		failures
	)


func _test_late_pull_up_and_attempt_metrics(
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var run_state: OrderRunState = OrderRunState.new()
	run_state.reset(&"order_pull_up_test")
	var tracker: FlightStyleTracker = FlightStyleTracker.new()
	tracker.begin(run_state)
	for _sample_index: int in 3:
		tracker.record_sample(1.0, Vector2(90.0, 200.0), 0.6, tuning)
	tracker.record_sample(0.1, Vector2(90.0, 50.0), 0.2, tuning)
	tracker.record_collision()
	tracker.record_collision()
	expect_true(
		run_state.late_pull_up_detected and run_state.collision_count == 2,
		"Configured late pull-up recovery and collisions must be recorded.",
		failures
	)
	tracker.begin()
	expect_true(
		run_state.entry_style.is_empty()
		and is_zero_approx(run_state.entry_duration)
		and run_state.collision_count == 0
		and not run_state.late_pull_up_detected,
		"Beginning a retry must clear only the previous entry-attempt metrics.",
		failures
	)


func _test_normalized_risk(failures: Array[String]) -> void:
	expect_true(
		is_equal_approx(
			FlightStyleTracker.calculate_normalized_risk(160.0, 320.0),
			0.5
		)
		and is_equal_approx(
			FlightStyleTracker.calculate_normalized_risk(500.0, 320.0),
			1.0
		)
		and is_zero_approx(
			FlightStyleTracker.calculate_normalized_risk(100.0, 0.0)
		),
		"Risk normalization must use the active environment safety speed and clamp to 0..1.",
		failures
	)
