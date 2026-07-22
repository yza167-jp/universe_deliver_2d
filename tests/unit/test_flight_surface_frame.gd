extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	var frame: FlightSurfaceFrame = FlightSurfaceFrame.new()
	expect_true(
		not frame.configure(23000.0, 20000.0, 180.0, 1.25),
		"Surface frame must reject a prepare window that starts after its lock.",
		failures
	)
	expect_true(
		frame.configure(20000.0, 23000.0, 180.0, 1.25),
		"Surface frame must accept the Red Sand acquisition window.",
		failures
	)
	expect_true(
		not frame.update(19999.0, 1000.0, 0.0, 720.0, 660.0, 1140.0)
		and not frame.is_acquired,
		"Surface frame must remain untouched before late Stage 5.",
		failures
	)
	expect_true(
		frame.update(20000.0, 1000.0, 0.0, 720.0, 660.0, 1140.0)
		and frame.is_acquired
		and not frame.is_locked
		and is_equal_approx(frame.offset_y, 1420.0)
		and is_equal_approx(frame.predicted_entry_altitude_meters, 1080.0),
		"Acquisition must align canonical ground with the current virtual altitude.",
		failures
	)
	expect_true(
		frame.update(22900.0, 1900.0, 320.0, 662.0, 660.0, 1053.0)
		and is_equal_approx(frame.offset_y, 1820.0)
		and is_equal_approx(frame.predicted_entry_altitude_meters, 580.0),
		"A fast descent must move future terrain, not the ship, to preserve recovery time.",
		failures
	)
	expect_true(
		frame.update(23000.0, 1900.0, 320.0, 660.0, 660.0, 1050.0)
		and frame.is_locked
		and is_equal_approx(frame.offset_y, 1820.0)
		and not frame.update(24000.0, 2500.0, 320.0, 640.0, 660.0, 1050.0)
		and is_equal_approx(frame.offset_y, 1820.0),
		"Stage 6 must freeze one shared surface offset for the rest of the route.",
		failures
	)

	frame.reset()
	frame.update(20000.0, 1000.0, -120.0, 720.0, 660.0, 1140.0)
	frame.update(23000.0, 780.0, -120.0, 660.0, 660.0, 1050.0)
	expect_true(
		frame.is_locked
		and is_equal_approx(frame.offset_y, 1420.0)
		and is_equal_approx(frame.predicted_entry_altitude_meters, 1300.0),
		"An ascending trajectory must retain its extra entry altitude instead of being normalized.",
		failures
	)
	return failures
