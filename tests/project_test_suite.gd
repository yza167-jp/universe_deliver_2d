class_name ProjectTestSuite
extends RefCounted


func get_suite_name() -> String:
	return String(get_script().resource_path).get_file().get_basename()


func run() -> Array[String]:
	return ["Test suite does not implement run()."]


func expect_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
