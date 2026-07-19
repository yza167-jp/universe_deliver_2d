extends ProjectTestSuite

const ROUTE_PATH: String = "res://data/tuning/flight_route_red_sand_m0.tres"
const CATALOG_PATH: String = "res://data/localization/game_text.csv"
const EXPECTED_SEGMENT_IDS: Array[StringName] = [
	&"red_sand_system_edge",
	&"red_sand_asteroid_lane",
	&"red_sand_near_orbit",
	&"red_sand_atmosphere_edge",
	&"red_sand_storm_layer",
	&"red_sand_lower_clouds",
	&"red_sand_surface_route",
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
		route.expected_duration_seconds
		>= FlightRouteDefinition.MIN_PLAYABLE_DURATION_SECONDS
		and route.expected_duration_seconds
		<= FlightRouteDefinition.MAX_PLAYABLE_DURATION_SECONDS,
		"Red Sand graybox target duration must stay within 6-10 minutes.",
		failures
	)
	expect_true(
		is_equal_approx(route.get_total_distance(), 150000.0)
		and is_equal_approx(route.get_estimated_cruise_speed(), 312.5),
		"Route length and target duration must produce the tunable eight-minute baseline.",
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
		and route.get_segment_index(14999.0) == 0
		and route.get_segment_index(15000.0) == 1
		and route.get_segment_index(150000.0) == 7,
		"Route lookup must switch exactly at segment boundaries and hold the final stage.",
		failures
	)
	expect_true(
		route.reverse_allowance_distance <= 640.0 * 1.5,
		"Reverse allowance must remain a short correction distance.",
		failures
	)
	return failures
