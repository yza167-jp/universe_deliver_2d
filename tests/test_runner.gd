extends SceneTree

const TEST_DIRECTORIES: PackedStringArray = [
	"res://tests/unit",
	"res://tests/smoke",
]
const TEST_FILE_PREFIX: String = "test_"
const TEST_FILE_SUFFIX: String = ".gd"

var _runner_failures: Array[String] = []


func _initialize() -> void:
	var test_paths: PackedStringArray = _discover_test_paths()
	if test_paths.is_empty():
		_runner_failures.append("No test suites were discovered.")

	print("[test] Discovered %d test suite(s)." % test_paths.size())
	for test_path: String in test_paths:
		_run_test_suite(test_path)

	if not _runner_failures.is_empty():
		printerr("[test] FAILED with %d error(s):" % _runner_failures.size())
		for failure: String in _runner_failures:
			printerr("  - %s" % failure)
		quit(1)
		return

	print("[test] PASS: %d test suite(s)." % test_paths.size())
	quit(0)


func _discover_test_paths() -> PackedStringArray:
	var test_paths: PackedStringArray = []
	for directory_path: String in TEST_DIRECTORIES:
		_collect_test_paths(directory_path, test_paths)
	test_paths.sort()
	return test_paths


func _collect_test_paths(directory_path: String, test_paths: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		_runner_failures.append("Cannot open test directory: %s" % directory_path)
		return

	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if directory.current_is_dir():
			if not entry_name.begins_with("."):
				_collect_test_paths(directory_path.path_join(entry_name), test_paths)
		elif entry_name.begins_with(TEST_FILE_PREFIX) and entry_name.ends_with(TEST_FILE_SUFFIX):
			test_paths.append(directory_path.path_join(entry_name))
		entry_name = directory.get_next()
	directory.list_dir_end()


func _run_test_suite(test_path: String) -> void:
	var script_resource: Resource = load(test_path)
	if not script_resource is GDScript:
		_runner_failures.append("Test file is not a GDScript: %s" % test_path)
		return

	var suite: ProjectTestSuite = (script_resource as GDScript).new() as ProjectTestSuite
	if suite == null:
		_runner_failures.append("Test suite must extend ProjectTestSuite: %s" % test_path)
		return

	var suite_failures: Array[String] = suite.run()
	if suite_failures.is_empty():
		print("[test] PASS %s" % suite.get_suite_name())
		return

	for failure: String in suite_failures:
		_runner_failures.append("%s: %s" % [suite.get_suite_name(), failure])
