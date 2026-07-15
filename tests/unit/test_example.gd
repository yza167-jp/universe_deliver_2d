extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	expect_true(true, "The example assertion should always pass.", failures)
	return failures
