extends ProjectTestSuite

const ROUTE_PATH: String = "res://data/tuning/flight_route_red_sand_m0.tres"
const CATALOG_PATH: String = "res://data/localization/game_text.csv"
const EXPECTED_SEGMENT_IDS: Array[StringName] = [
	&"red_sand_system_edge",
	&"red_sand_asteroid_lane",
	&"red_sand_near_orbit",
	&"red_sand_atmosphere_edge",
	&"red_sand_storm_layer",
	&"red_sand_low_altitude_control",
	&"red_sand_landing_preparation",
	&"red_sand_landing_approach",
]


func run() -> Array[String]:
	var failures: Array[String] = []
	var route: FlightRouteDefinition = load(ROUTE_PATH) as FlightRouteDefinition
	expect_true(route != null, "Red Sand route definition must load.", failures)
	if route == null:
		return failures

	var validation_errors: PackedStringArray = route.validate()
	expect_true(
		validation_errors.is_empty(),
		"Red Sand route definition must validate: %s" % "; ".join(validation_errors),
		failures
	)
	expect_true(
		route.segments.size() == EXPECTED_SEGMENT_IDS.size(),
		"Red Sand route must contain the eight ordered M0 stages.",
		failures
	)
	expect_true(
		route.nominal_fast_duration_seconds
		>= FlightRouteDefinition.MIN_FAST_DURATION_SECONDS
		and route.nominal_fast_duration_seconds
		<= FlightRouteDefinition.MAX_FAST_DURATION_SECONDS
		and route.expected_duration_seconds
		>= FlightRouteDefinition.MIN_BALANCED_DURATION_SECONDS
		and route.expected_duration_seconds
		<= FlightRouteDefinition.MAX_BALANCED_DURATION_SECONDS
		and route.nominal_scenic_duration_seconds
		>= FlightRouteDefinition.MIN_SCENIC_DURATION_SECONDS
		and route.nominal_scenic_duration_seconds
		<= FlightRouteDefinition.MAX_SCENIC_DURATION_SECONDS,
		"Red Sand fast, balanced, and scenic targets must stay within 1-3 minutes.",
		failures
	)
	expect_true(
		is_equal_approx(route.get_total_distance(), 38000.0)
		and is_equal_approx(route.get_estimated_cruise_speed(), 316.6666667),
		"Compressed route distance must preserve the accepted baseline cruise scale.",
		failures
	)
	expect_true(
		is_equal_approx(route.surface_frame_prepare_start_distance, 20000.0)
		and is_equal_approx(route.surface_frame_lock_distance, 23000.0)
		and is_equal_approx(
			route.surface_frame_minimum_entry_altitude_meters,
			180.0
		)
		and is_equal_approx(
			route.surface_frame_descent_reaction_seconds,
			1.25
		),
		"Surface-frame acquisition must stay in late Stage 5 and lock at Stage 6.",
		failures
	)
	expect_true(
		is_equal_approx(route.segments[5].start_distance, 23000.0)
		and is_equal_approx(route.segments[5].end_distance, 30500.0)
		and is_equal_approx(route.segments[5].get_length(), 7500.0)
		and is_equal_approx(route.segments[6].start_distance, 30500.0)
		and is_equal_approx(route.segments[6].end_distance, 33000.0)
		and is_equal_approx(route.segments[6].get_length(), 2500.0)
		and is_equal_approx(route.segments[7].get_length(), 5000.0),
		"Stages 6-8 must remain control radar, preparation corridor, and final approach.",
		failures
	)

	var catalog: LocalizationCatalog = LocalizationCatalog.load_csv(CATALOG_PATH)
	var previous_end: float = 0.0
	var previous_scale: float = 0.0
	var previous_floor_y: float = INF
	var previous_gravity_blend: float = 0.0
	var previous_air_density: float = 0.0
	for index: int in route.segments.size():
		var segment: FlightRouteSegment = route.segments[index]
		expect_true(
			segment != null and segment.id == EXPECTED_SEGMENT_IDS[index],
			"Route segment %d has the wrong stable ID." % index,
			failures
		)
		expect_true(
			segment.checkpoint_fuel_floor >= 0.0
			and segment.checkpoint_fuel_floor <= 100.0,
			"Every route checkpoint must expose a bounded safe fuel floor.",
			failures
		)
		if segment == null:
			continue
		expect_true(
			is_equal_approx(segment.start_distance, previous_end),
			"Route segments must remain contiguous.",
			failures
		)
		expect_true(
			segment.planet_scale_start >= previous_scale
			and segment.planet_scale_end >= segment.planet_scale_start,
			"Planet scale must grow monotonically across the full route.",
			failures
		)
		expect_true(
			segment.floor_y <= previous_floor_y,
			"Graybox surface must rise gradually as the route approaches the ground.",
			failures
		)
		expect_true(
			segment.terrain_surface_enabled == (index >= 5),
			"Only low-altitude control, preparation, and landing stages may expose terrain.",
			failures
		)
		expect_true(
			segment.environment_profile.target_gravity_blend
			>= previous_gravity_blend
			and segment.environment_profile.target_air_density >= previous_air_density,
			"Environment targets must deepen without reversing the entry progression.",
			failures
		)
		expect_true(
			catalog.has_translation(segment.display_name_key, &"zh_CN")
			and catalog.has_translation(segment.display_name_key, &"en")
			and catalog.has_translation(segment.instruction_key, &"zh_CN")
			and catalog.has_translation(segment.instruction_key, &"en"),
			"Every route stage name and instruction must be localized.",
			failures
		)
		previous_end = segment.end_distance
		previous_scale = segment.planet_scale_end
		previous_floor_y = segment.floor_y
		previous_gravity_blend = segment.environment_profile.target_gravity_blend
		previous_air_density = segment.environment_profile.target_air_density

	expect_true(
		route.get_segment_index(0.0) == 0
		and route.get_segment_index(3999.0) == 0
		and route.get_segment_index(4000.0) == 1
		and route.get_segment_index(23000.0) == 5
		and route.get_segment_index(30500.0) == 6
		and route.get_segment_index(33000.0) == 7
		and route.get_segment_index(38000.0) == 7,
		"Route lookup must switch exactly at segment boundaries and hold the final stage.",
		failures
	)
	expect_true(
		route.segments[2].planet_scale_end
		/ route.segments[0].planet_scale_start >= 2.5
		and route.segments[2].planet_scale_end
		/ route.segments[0].planet_scale_start <= 4.0,
		"Near-orbit Red Sand must be 2.5-4x the initial system-edge disc.",
		failures
	)
	expect_true(
		route.reverse_allowance_distance <= 640.0 * 1.5,
		"Reverse allowance must remain a short correction distance.",
		failures
	)
	expect_true(
		is_equal_approx(route.get_ground_route_y(0.0), 1000.0)
		and route.get_ground_route_y(18000.0) > 540.0
		and is_equal_approx(route.get_ground_route_y(38000.0), 350.0),
		"Internal compressed route datum must descend without creating early collision.",
		failures
	)
	expect_true(
		is_equal_approx(route.get_ground_route_y(23000.0, 5), 660.0)
		and is_equal_approx(route.get_ground_route_y(22900.0, 5), 660.0)
		and absf(
			route.get_ground_route_y(30499.999, 5)
			- route.get_ground_route_y(30500.0, 6)
		) < 0.01
		and absf(
			route.get_ground_route_y(32999.999, 6)
			- route.get_ground_route_y(33000.0, 7)
		) < 0.01
		and route.has_ground_profile(5)
		and route.has_ground_profile(6)
		and route.has_ground_profile(7)
		and route.get_ground_profile_segment_id(5)
		== &"red_sand_low_altitude_control",
		"Canonical terrain lookup must cover Stages 6-8 continuously and survive short reverse corrections.",
		failures
	)
	return failures
