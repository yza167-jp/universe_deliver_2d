extends ProjectTestSuite

const TUNING_PATH: String = "res://data/tuning/flight_tuning_m0.tres"


func run() -> Array[String]:
	var failures: Array[String] = []
	var tuning: FlightTuning = load(TUNING_PATH) as FlightTuning
	expect_true(tuning != null, "M0 FlightTuning must load.", failures)
	if tuning == null:
		return failures
	_test_normal_speed_drives_classification(tuning, failures)
	_test_all_impact_bands(tuning, failures)
	_test_cargo_tolerance_reduces_damage(tuning, failures)
	_test_thresholds_are_data_driven(tuning, failures)
	return failures


func _test_normal_speed_drives_classification(
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var incoming_velocity: Vector2 = Vector2(300.0, 60.0)
	var floor_result: FlightCollisionResult = FlightCollisionResolver.resolve(
		incoming_velocity,
		Vector2.UP,
		0.65,
		tuning
	)
	var wall_result: FlightCollisionResult = FlightCollisionResolver.resolve(
		incoming_velocity,
		Vector2.LEFT,
		0.65,
		tuning
	)
	expect_true(
		floor_result.severity == FlightCollisionResult.Severity.GRAZE
		and is_equal_approx(floor_result.impact_speed, 60.0),
		"A fast tangential slide must stay a graze when normal speed is low.",
		failures
	)
	expect_true(
		wall_result.severity == FlightCollisionResult.Severity.FATAL
		and is_equal_approx(wall_result.impact_speed, 300.0),
		"The same velocity must be fatal when directed into the surface normal.",
		failures
	)


func _test_all_impact_bands(
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var ignored: FlightCollisionResult = FlightCollisionResolver.resolve(
		Vector2(0.0, tuning.minimum_impact_speed - 1.0),
		Vector2.UP,
		0.65,
		tuning
	)
	var graze: FlightCollisionResult = FlightCollisionResolver.resolve(
		Vector2(0.0, tuning.safe_graze_speed),
		Vector2.UP,
		0.65,
		tuning
	)
	var hard: FlightCollisionResult = FlightCollisionResolver.resolve(
		Vector2(0.0, (tuning.safe_graze_speed + tuning.fatal_impact_speed) * 0.5),
		Vector2.UP,
		0.65,
		tuning
	)
	var fatal: FlightCollisionResult = FlightCollisionResolver.resolve(
		Vector2(0.0, tuning.fatal_impact_speed),
		Vector2.UP,
		0.65,
		tuning
	)
	expect_true(
		ignored.severity == FlightCollisionResult.Severity.NONE,
		"Sub-threshold contact must not repeatedly damage a resting ship.",
		failures
	)
	expect_true(
		graze.severity == FlightCollisionResult.Severity.GRAZE
		and graze.total_damage == tuning.graze_shield_damage
		and is_zero_approx(graze.cargo_damage),
		"A graze must only produce the configured small shield change.",
		failures
	)
	expect_true(
		hard.severity == FlightCollisionResult.Severity.HARD
		and hard.total_damage > tuning.hard_impact_min_damage
		and hard.cargo_damage > 0.0
		and not hard.should_fail,
		"A hard impact must damage resources without immediately failing the run.",
		failures
	)
	expect_true(
		fatal.severity == FlightCollisionResult.Severity.FATAL
		and fatal.should_fail,
		"A collision at the fatal threshold must fail the current flight segment.",
		failures
	)


func _test_cargo_tolerance_reduces_damage(
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var speed: float = (tuning.safe_graze_speed + tuning.fatal_impact_speed) * 0.5
	var fragile: FlightCollisionResult = FlightCollisionResolver.resolve(
		Vector2(0.0, speed),
		Vector2.UP,
		0.0,
		tuning
	)
	var protected: FlightCollisionResult = FlightCollisionResolver.resolve(
		Vector2(0.0, speed),
		Vector2.UP,
		1.0,
		tuning
	)
	expect_true(
		fragile.cargo_damage > protected.cargo_damage
		and is_zero_approx(protected.cargo_damage),
		"Cargo collision tolerance must reduce impact-specific cargo damage.",
		failures
	)


func _test_thresholds_are_data_driven(
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var custom: FlightTuning = tuning.duplicate() as FlightTuning
	custom.safe_graze_speed = 140.0
	custom.fatal_impact_speed = 360.0
	var result: FlightCollisionResult = FlightCollisionResolver.resolve(
		Vector2(0.0, 120.0),
		Vector2.UP,
		0.65,
		custom
	)
	expect_true(
		result.severity == FlightCollisionResult.Severity.GRAZE,
		"Changing FlightTuning thresholds must change classification without formula edits.",
		failures
	)
