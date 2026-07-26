extends ProjectTestSuite

const ROUTE_PATH: String = (
	"res://data/tuning/flight_route_white_noise_m1.tres"
)
const PLANET_PATH: String = "res://data/planets/white_noise.tres"
const ORDER_PATH: String = (
	"res://data/orders/m1_white_noise_archive_core.tres"
)
const SCENE_PATH: String = "res://scenes/flight/white_noise_flight.tscn"
const CATALOG_PATH: String = "res://data/localization/game_text.csv"
const EXPECTED_SEGMENT_IDS: Array[StringName] = [
	&"white_noise_orbital_approach",
	&"white_noise_open_icefield",
	&"white_noise_ice_rift_split",
	&"white_noise_aurora_blizzard",
	&"white_noise_archive_descent",
	&"white_noise_landing_approach",
]


func run() -> Array[String]:
	var failures: Array[String] = []
	var route: WhiteNoiseRouteDefinition = load(
		ROUTE_PATH
	) as WhiteNoiseRouteDefinition
	var planet: PlanetDefinition = load(PLANET_PATH) as PlanetDefinition
	var order: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	expect_true(route != null, "T-120 route resource must load.", failures)
	expect_true(planet != null, "White Noise planet must load.", failures)
	expect_true(order != null, "White Noise formal order must load.", failures)
	if route == null or planet == null or order == null:
		return failures
	_test_route_contract(route, planet, failures)
	_test_branches(route, failures)
	_test_localization(route, failures)
	_test_playable_boundary(planet, order, failures)
	_test_debug_scenario(failures)
	_test_fixed_delta_motion(route, failures)
	return failures


func _test_route_contract(
	route: WhiteNoiseRouteDefinition,
	planet: PlanetDefinition,
	failures: Array[String]
) -> void:
	var validation_errors: PackedStringArray = route.validate()
	expect_true(
		validation_errors.is_empty(),
		"T-120 route must validate: %s" % "; ".join(validation_errors),
		failures
	)
	expect_true(
		route.id == &"route_white_noise_archive_core"
		and route.segments.size() == EXPECTED_SEGMENT_IDS.size()
		and is_equal_approx(route.get_total_distance(), 34000.0),
		"White Noise must use an independent six-segment 34 km route.",
		failures
	)
	expect_true(
		route.nominal_fast_duration_seconds == 88.0
		and route.expected_duration_seconds == 118.0
		and route.nominal_scenic_duration_seconds == 154.0,
		"Fast, balanced, and scenic route targets must stay within 1-3 minutes.",
		failures
	)
	expect_true(
		is_equal_approx(planet.gravity_scale, 1.28),
		"White Noise authoritative gravity scale must remain 1.28g.",
		failures
	)
	var authoritative_gravity: float = (
		WhiteNoiseFlight.BASE_PLANET_GRAVITY * planet.gravity_scale
	)
	for index: int in route.segments.size():
		var segment: FlightRouteSegment = route.segments[index]
		expect_true(
			segment != null and segment.id == EXPECTED_SEGMENT_IDS[index],
			"White Noise segment %d has the wrong stable ID." % index,
			failures
		)
		if segment == null:
			continue
		expect_true(
			segment.environment_profile != null
			and is_equal_approx(
				segment.environment_profile.planet_gravity,
				authoritative_gravity
			),
			"Every White Noise environment must derive the 1.28g authority.",
			failures
		)
		expect_true(
			segment.terrain_surface_enabled == (index >= 1),
			"Terrain must begin at the open icefield and remain continuous.",
			failures
		)
	var route_text: String = FileAccess.get_file_as_string(ROUTE_PATH)
	var scene_text: String = FileAccess.get_file_as_string(SCENE_PATH)
	expect_true(
		not route_text.contains("red_sand")
		and not scene_text.contains("red_sand")
		and not route_text.contains("radar")
		and not scene_text.contains("radar"),
		"White Noise route and scene must not depend on Red Sand or radar content.",
		failures
	)


func _test_branches(
	route: WhiteNoiseRouteDefinition,
	failures: Array[String]
) -> void:
	expect_true(
		route.branches.size() == 3
		and route.get_branch(&"white_noise_fast") != null
		and route.get_branch(&"white_noise_balanced") != null
		and route.get_branch(&"white_noise_scenic") != null,
		"White Noise route must define fast, balanced, and scenic local lanes.",
		failures
	)
	expect_true(
		is_equal_approx(route.get_branch_split_distance(), 10000.0)
		and is_equal_approx(route.get_branch_join_distance(), 17000.0),
		"All three lanes must share one split and one rejoin point.",
		failures
	)
	expect_true(
		route.choose_branch(180.0).id == &"white_noise_fast"
		and route.choose_branch(325.0).id == &"white_noise_balanced"
		and route.choose_branch(500.0).id == &"white_noise_scenic",
		"Lane selection must be deterministic from ship altitude.",
		failures
	)


func _test_localization(
	route: WhiteNoiseRouteDefinition,
	failures: Array[String]
) -> void:
	var catalog: LocalizationCatalog = LocalizationCatalog.load_csv(CATALOG_PATH)
	for segment: FlightRouteSegment in route.segments:
		expect_true(
			catalog.has_translation(segment.display_name_key, &"zh_CN")
			and catalog.has_translation(segment.display_name_key, &"en")
			and catalog.has_translation(segment.instruction_key, &"zh_CN")
			and catalog.has_translation(segment.instruction_key, &"en"),
			"Every White Noise segment must provide Chinese and English text.",
			failures
		)
	for branch: WhiteNoiseRouteBranch in route.branches:
		expect_true(
			catalog.has_translation(branch.display_name_key, &"zh_CN")
			and catalog.has_translation(branch.display_name_key, &"en")
			and catalog.has_translation(branch.instruction_key, &"zh_CN")
			and catalog.has_translation(branch.instruction_key, &"en"),
			"Every White Noise branch must provide Chinese and English text.",
			failures
		)


func _test_playable_boundary(
	planet: PlanetDefinition,
	order: OrderDefinition,
	failures: Array[String]
) -> void:
	expect_true(
		planet.content_readiness
		== PlanetDefinition.ContentReadiness.PLAYABLE
		and planet.flight_scene_path == SCENE_PATH
		and order.content_readiness
		== OrderDefinition.ContentReadiness.PLAYABLE,
		"T-125 must promote only the validated White Noise route to PLAYABLE.",
		failures
	)
	var state := GameStateModel.new()
	state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	state.unlocked_planet_ids = [
		M1ProgressRules.PLANET_RED_SAND,
		M1ProgressRules.PLANET_WHITE_NOISE,
	]
	state.ship_upgrade_ids.append(
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
	)
	state.story_flags[
		M1ProgressRules.STORY_RED_SAND_SHIELDING_RETROFIT_COMPLETED
	] = true
	state.completed_order_ids[
		M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT
	] = true
	expect_true(
		state.accept_order(order),
		"Qualified progress must accept the formal White Noise order after T-125.",
		failures
	)
	state.free()


func _test_debug_scenario(failures: Array[String]) -> void:
	var registry: GameDataRegistry = load(
		"res://data/m1_data_registry.tres"
	) as GameDataRegistry
	var catalog := M1DebugScenarioCatalog.new()
	var definition: M1DebugScenarioDefinition = catalog.get_definition(
		M1DebugScenarioCatalog.SCENARIO_WHITE_NOISE_ROUTE,
		registry
	)
	expect_true(
		definition != null
		and definition.active_order_id
		== M1DebugScenarioCatalog.DEBUG_WHITE_NOISE_ROUTE_ORDER_ID
		and definition.fixture_source_order_id
		== M1DebugScenarioCatalog.ORDER_WHITE_NOISE
		and definition.target_scene_path == SCENE_PATH
		and definition.target_stage == SceneRouterService.Stage.FLIGHT
		and not definition.preview_only,
		"The centralized M1 debug catalog must expose the isolated route entry.",
		failures
	)


func _test_fixed_delta_motion(
	route: WhiteNoiseRouteDefinition,
	failures: Array[String]
) -> void:
	var tuning: FlightTuning = load(
		"res://data/tuning/flight_tuning_m0.tres"
	) as FlightTuning
	var profile: FlightEnvironmentProfile = route.segments[1].environment_profile
	var positions: Array[Vector2] = []
	for fps: float in [30.0, 60.0, 120.0]:
		var delta: float = 1.0 / fps
		var position := Vector2.ZERO
		var velocity := Vector2.ZERO
		for _step: int in roundi(12.0 * fps):
			velocity = FlightMotionModel.step_control_velocity(
				velocity,
				-0.22,
				1.0,
				0.0,
				tuning,
				delta
			)
			var gravity: float = FlightEnvironmentModel.calculate_effective_gravity(
				profile,
				1.0,
				FlightAssistMode.LIMITED
			)
			velocity = FlightEnvironmentModel.step_velocity(
				velocity,
				gravity,
				profile,
				profile.target_air_density,
				tuning.space_drag,
				delta
			)
			velocity = FlightMotionModel.apply_speed_limits(
				velocity,
				-0.22,
				tuning
			)
			position += velocity * delta
		positions.append(position)
	expect_true(
		positions[0].distance_to(positions[1]) < 20.0
		and positions[1].distance_to(positions[2]) < 12.0
		and positions[2].x > 2400.0
		and positions[2].y < 1200.0,
		(
			"1.28g fixed-delta flight must remain controllable and stable "
			+ "at 30/60/120 FPS: %s."
		) % [positions],
		failures
	)
