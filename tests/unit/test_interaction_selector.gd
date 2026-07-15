extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_priority_precedes_geometry(failures)
	_test_facing_precedes_distance(failures)
	_test_distance_breaks_equal_facing(failures)
	_test_stable_id_breaks_complete_ties(failures)
	return failures


func _test_priority_precedes_geometry(failures: Array[String]) -> void:
	var candidates: Array[InteractionCandidate] = [
		InteractionCandidate.new(&"near_front", 10, 4.0, 1.0),
		InteractionCandidate.new(&"explicit_priority", 20, 400.0, -1.0),
	]
	var selected: InteractionCandidate = InteractionSelector.select_best(candidates)
	expect_true(
		selected != null and selected.candidate_id == &"explicit_priority",
		"Explicit interaction priority must outrank facing and distance.",
		failures
	)


func _test_facing_precedes_distance(failures: Array[String]) -> void:
	var candidates: Array[InteractionCandidate] = [
		InteractionCandidate.new(&"close_behind", 10, 4.0, -0.8),
		InteractionCandidate.new(&"front", 10, 100.0, 0.9),
	]
	var selected: InteractionCandidate = InteractionSelector.select_best(candidates)
	expect_true(
		selected != null and selected.candidate_id == &"front",
		"Facing alignment must choose the object the player is looking toward.",
		failures
	)


func _test_distance_breaks_equal_facing(failures: Array[String]) -> void:
	var candidates: Array[InteractionCandidate] = [
		InteractionCandidate.new(&"far", 10, 144.0, 0.5),
		InteractionCandidate.new(&"near", 10, 36.0, 0.5),
	]
	var selected: InteractionCandidate = InteractionSelector.select_best(candidates)
	expect_true(
		selected != null and selected.candidate_id == &"near",
		"Distance must choose the nearer object when priority and facing match.",
		failures
	)


func _test_stable_id_breaks_complete_ties(failures: Array[String]) -> void:
	var forward: Array[InteractionCandidate] = [
		InteractionCandidate.new(&"beta", 10, 64.0, 0.5),
		InteractionCandidate.new(&"alpha", 10, 64.0, 0.5),
	]
	var reverse: Array[InteractionCandidate] = [forward[1], forward[0]]
	var selected_forward: InteractionCandidate = InteractionSelector.select_best(forward)
	var selected_reverse: InteractionCandidate = InteractionSelector.select_best(reverse)
	expect_true(
		selected_forward != null
		and selected_reverse != null
		and selected_forward.candidate_id == &"alpha"
		and selected_reverse.candidate_id == &"alpha",
		"Complete ties must resolve by stable ID, independent of overlap discovery order.",
		failures
	)
