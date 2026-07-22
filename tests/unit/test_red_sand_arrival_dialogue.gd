extends ProjectTestSuite

const MAIN_DIALOGUE_PATH: String = "res://data/dialogue/red_sand_arrival_main.tres"
const OPTIONAL_DIALOGUE_PATH: String = "res://data/dialogue/red_sand_arrival_optional.tres"
const LASER_MODULE_PATH: String = "res://data/modules/asteroid_laser.tres"
const CATALOG_PATH: String = "res://data/localization/game_text.csv"
const REQUIRED_LOCALES: PackedStringArray = ["zh_CN", "en"]


func run() -> Array[String]:
	var failures: Array[String] = []
	var main_sequence: DialogueSequence = load(MAIN_DIALOGUE_PATH) as DialogueSequence
	var optional_sequence: DialogueSequence = load(OPTIONAL_DIALOGUE_PATH) as DialogueSequence
	var catalog: LocalizationCatalog = LocalizationCatalog.load_csv(CATALOG_PATH)
	expect_true(main_sequence != null, "Arrival main dialogue must load.", failures)
	expect_true(optional_sequence != null, "Arrival optional dialogue must load.", failures)
	if main_sequence == null or optional_sequence == null:
		return failures

	var main_errors: PackedStringArray = DialogueValidator.validate(
		main_sequence,
		catalog,
		REQUIRED_LOCALES
	)
	var optional_errors: PackedStringArray = DialogueValidator.validate(
		optional_sequence,
		catalog,
		REQUIRED_LOCALES
	)
	expect_true(
		main_errors.is_empty(),
		"Arrival main dialogue must validate: %s" % "; ".join(main_errors),
		failures
	)
	expect_true(
		optional_errors.is_empty(),
		"Arrival optional dialogue must validate: %s" % "; ".join(optional_errors),
		failures
	)

	_test_result_branches(main_sequence, failures)
	_test_cargo_condition(failures)
	_test_optional_completion(optional_sequence, failures)
	return failures


func _test_result_branches(
	sequence: DialogueSequence,
	failures: Array[String]
) -> void:
	var dive_state: GameStateModel = _create_game_state(
		FlightStyleTracker.STYLE_DIVE,
		96.0,
		true
	)
	var dive_lines: Array[StringName] = _complete_sequence(sequence, dive_state, failures)
	expect_true(
		_has_exact_result_branch(
			dive_lines,
			&"arrival_style_dive",
			&"arrival_cargo_high",
			&"arrival_laser_equipped"
		),
		"DIVE/high-cargo/laser results must select exactly their authored branches: %s"
		% str(dive_lines),
		failures
	)
	expect_true(
		dive_state.has_story_flag(RedSandArrival.STORY_MAIN_DIALOGUE_COMPLETED),
		"Completing the main arrival dialogue must set its story flag.",
		failures
	)
	dive_state.free()

	var glide_state: GameStateModel = _create_game_state(
		FlightStyleTracker.STYLE_GLIDE,
		54.0,
		false
	)
	var glide_lines: Array[StringName] = _complete_sequence(sequence, glide_state, failures)
	expect_true(
		_has_exact_result_branch(
			glide_lines,
			&"arrival_style_glide",
			&"arrival_cargo_low",
			&"arrival_laser_unequipped"
		),
		"GLIDE/low-cargo/no-laser results must select exactly their authored branches: %s"
		% str(glide_lines),
		failures
	)
	glide_state.free()

	var balanced_state: GameStateModel = _create_game_state(
		FlightStyleTracker.STYLE_BALANCED,
		80.0,
		false
	)
	var balanced_lines: Array[StringName] = _complete_sequence(
		sequence,
		balanced_state,
		failures
	)
	expect_true(
		_has_exact_result_branch(
			balanced_lines,
			&"arrival_style_balanced",
			&"arrival_cargo_high",
			&"arrival_laser_unequipped"
		),
		"The 80-percent boundary must use BALANCED/high-cargo/no-laser branches: %s"
		% str(balanced_lines),
		failures
	)
	balanced_state.free()


func _test_cargo_condition(failures: Array[String]) -> void:
	var condition: DialogueCondition = DialogueCondition.new()
	condition.condition_type = DialogueCondition.ConditionType.CARGO_INTEGRITY_AT_LEAST
	condition.cargo_integrity_threshold = 80.0
	var game_state: GameStateModel = _create_game_state(
		FlightStyleTracker.STYLE_BALANCED,
		79.0,
		false
	)
	expect_true(
		not condition.is_met(game_state),
		"Cargo condition must reject values below the configured threshold.",
		failures
	)
	game_state.order_run_state.cargo_integrity = 80.0
	expect_true(
		condition.is_met(game_state),
		"Cargo condition must include the configured threshold boundary.",
		failures
	)
	condition.expected_value = false
	expect_true(
		not condition.is_met(game_state),
		"Inverted cargo condition must remain mutually exclusive at the boundary.",
		failures
	)
	game_state.order_run_state.cargo_integrity = 79.0
	expect_true(
		condition.is_met(game_state),
		"Inverted cargo condition must select values below the threshold.",
		failures
	)
	game_state.free()

	var no_order_state: GameStateModel = GameStateModel.new()
	expect_true(
		not condition.is_met(no_order_state),
		"Cargo conditions must not treat a missing active order as a low-cargo result.",
		failures
	)
	no_order_state.free()


func _test_optional_completion(
	sequence: DialogueSequence,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = _create_game_state(
		FlightStyleTracker.STYLE_BALANCED,
		90.0,
		false
	)
	var lines: Array[StringName] = _complete_sequence(sequence, game_state, failures)
	expect_true(
		lines == [&"optional_daily_work", &"optional_company_stance"],
		"Optional dialogue must contain one daily detail and one independent company stance.",
		failures
	)
	expect_true(
		game_state.has_story_flag(RedSandArrival.STORY_OPTIONAL_DIALOGUE_COMPLETED),
		"Optional dialogue completion must be persisted in runtime story state.",
		failures
	)
	game_state.free()


func _create_game_state(
	entry_style: StringName,
	cargo_integrity: float,
	laser_equipped: bool
) -> GameStateModel:
	var game_state: GameStateModel = GameStateModel.new()
	game_state.current_order_id = &"order_red_sand_m0"
	var run_state: OrderRunState = game_state.get_active_order_run_state()
	run_state.entry_style = entry_style
	run_state.cargo_integrity = cargo_integrity
	if laser_equipped:
		var laser_module: ShipModuleDefinition = load(
			LASER_MODULE_PATH
		) as ShipModuleDefinition
		game_state.equip_ship_module(laser_module)
	return game_state


func _complete_sequence(
	sequence: DialogueSequence,
	game_state: GameStateModel,
	failures: Array[String]
) -> Array[StringName]:
	var visited_lines: Array[StringName] = []
	var runtime: DialogueRuntime = DialogueRuntime.new()
	if not runtime.start(sequence, game_state):
		failures.append("Dialogue failed to start: %s" % runtime.last_error)
		return visited_lines
	var remaining_lines: int = 32
	while runtime.is_running() and remaining_lines > 0:
		visited_lines.append(runtime.current_line.id)
		if not runtime.advance():
			failures.append("Dialogue failed to advance: %s" % runtime.last_error)
			break
		remaining_lines -= 1
	if remaining_lines <= 0:
		failures.append("Dialogue exceeded its expected linear line budget.")
	return visited_lines


func _has_exact_result_branch(
	visited_lines: Array[StringName],
	expected_style: StringName,
	expected_cargo: StringName,
	expected_laser: StringName
) -> bool:
	var style_count: int = 0
	var cargo_count: int = 0
	var laser_count: int = 0
	for line_id: StringName in visited_lines:
		if line_id in [
			&"arrival_style_dive",
			&"arrival_style_glide",
			&"arrival_style_balanced",
		]:
			style_count += 1
		if line_id in [&"arrival_cargo_high", &"arrival_cargo_low"]:
			cargo_count += 1
		if line_id in [&"arrival_laser_equipped", &"arrival_laser_unequipped"]:
			laser_count += 1
	return (
		visited_lines.has(expected_style)
		and visited_lines.has(expected_cargo)
		and visited_lines.has(expected_laser)
		and style_count == 1
		and cargo_count == 1
		and laser_count == 1
	)
