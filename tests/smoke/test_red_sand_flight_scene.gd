extends ProjectTestSuite

const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const FLIGHT_STAGE_SCENE_PATH: String = "res://scenes/flight/flight_level.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	var packed_route: PackedScene = load(ROUTE_SCENE_PATH) as PackedScene
	var packed_stage: PackedScene = load(FLIGHT_STAGE_SCENE_PATH) as PackedScene
	expect_true(packed_route != null, "Red Sand route scene must load.", failures)
	expect_true(packed_stage != null, "FLIGHT stage wrapper must load.", failures)
	if packed_route == null or packed_stage == null:
		return failures

	var stage_scene: Node = packed_stage.instantiate()
	expect_true(
		stage_scene is RedSandFlight,
		"Standard FLIGHT stage must host the Red Sand route instead of Flight Lab.",
		failures
	)
	expect_true(stage_scene.name == &"Flight", "FLIGHT stage root must remain Flight.", failures)
	stage_scene.free()

	var route_scene: RedSandFlight = packed_route.instantiate() as RedSandFlight
	expect_true(route_scene != null, "Red Sand route root must use RedSandFlight.", failures)
	if route_scene == null:
		return failures
	var flight_ship: FlightLabShip = route_scene.get_node_or_null(
		"World/FlightShip"
	) as FlightLabShip
	expect_true(flight_ship is CharacterBody2D, "Route ship must remain CharacterBody2D.", failures)
	expect_true(
		route_scene.get_node_or_null("World/FlightCamera") is Camera2D
		and route_scene.get_node_or_null("RedSandRouteHUD") is RedSandRouteHUD,
		"Red Sand route must include its camera and localized graybox HUD.",
		failures
	)
	expect_true(
		route_scene.get_node_or_null("BackgroundLayers/FarStars") is Parallax2D
		and route_scene.get_node_or_null("BackgroundLayers/DustBands") is Parallax2D
		and route_scene.get_node_or_null("BackgroundLayers/LowerHaze") is Parallax2D
		and route_scene.get_node_or_null("BackgroundLayers/FarTerrain") is Parallax2D
		and route_scene.get_node_or_null("BackgroundLayers/NearFacilities") is Parallax2D,
		"Red Sand route must provide five distinct parallax depth layers.",
		failures
	)
	expect_true(
		route_scene.get_node_or_null("Backdrop/PlanetAnchor") is Node2D
		and route_scene.get_node_or_null("Backdrop/PlanetAnchor/PlanetDisc") is Polygon2D,
		"Red Sand route must expose the progressively scaled planet graybox.",
		failures
	)
	expect_true(
		route_scene.route_definition != null
		and route_scene.route_definition.segments.size() == 8
		and route_scene.route_definition.validate().is_empty(),
		"Red Sand scene must bind the validated eight-stage route data.",
		failures
	)
	var asteroid_hazards: Array[Node] = route_scene.find_children(
		"*",
		"DestructibleAsteroid",
		true,
		false
	)
	var lightning_hazards: Array[Node] = route_scene.find_children(
		"*",
		"FlightLightningStrike",
		true,
		false
	)
	expect_true(
		asteroid_hazards.size() == 8
		and lightning_hazards.size() == 4
		and route_scene.get_node_or_null("World/Hazards") is RedSandHazardDirector
		and route_scene.get_node_or_null(
			"EnvironmentFeedback"
		) is RedSandEnvironmentFeedback,
		"T-041 route must bind its fixed asteroid, lightning, and feedback components.",
		failures
	)
	expect_true(
		route_scene.get_node_or_null(
			"World/LowFlightCourse"
		) is RedSandLowFlightCourse
		and route_scene.find_children(
			"*",
			"FlightRadarSector",
			true,
			false
		).size() == 3
		and route_scene.find_children(
			"*",
			"FlightRadarCover",
			true,
			false
		).size() == 3,
		"T-042 route must bind its fixed canyon radar sectors and terrain covers.",
		failures
	)
	expect_true(
		route_scene.get_node_or_null("World/LandingZone") is RedSandLandingZone
		and route_scene.get_node_or_null(
			"World/LandingZone/PadBody"
		) is StaticBody2D
		and route_scene.get_node_or_null(
			"World/LandingZone/ApproachSensor"
		) is Area2D,
		"T-043 route must bind one explicit landing zone and collidable pad.",
		failures
	)
	expect_true(
		flight_ship.get_node_or_null("EngineTrailParticles") is CPUParticles2D
		and flight_ship.get_node_or_null("BoostTrailParticles") is CPUParticles2D
		and flight_ship.get_node_or_null("EngineAudio") is AudioStreamPlayer2D
		and flight_ship.get_node_or_null("BoostAudio") is AudioStreamPlayer2D
		and flight_ship.get_node_or_null("CollisionAudio") is AudioStreamPlayer2D,
		"T-044 route ship must bind propulsion particles and synthesized feedback audio.",
		failures
	)
	var environment_feedback: RedSandEnvironmentFeedback = route_scene.get_node_or_null(
		"EnvironmentFeedback"
	) as RedSandEnvironmentFeedback
	expect_true(
		environment_feedback != null
		and environment_feedback.get_node_or_null("MusicAudio") is AudioStreamPlayer
		and environment_feedback.get_node_or_null(
			"SpeedStreakParticles"
		) is CPUParticles2D
		and environment_feedback.get_node_or_null(
			"AtmosphereEntryParticles"
		) is CPUParticles2D
		and environment_feedback.get_node_or_null("StormParticles") is CPUParticles2D
		and environment_feedback.get_node_or_null(
			"LandingDustParticles"
		) is CPUParticles2D,
		"T-044 route must bind music and stage-specific environment particles.",
		failures
	)
	expect_true(
		route_scene.find_children("*", "CharacterBody2D", true, false).size() == 1,
		"T-042 must not add enemies or another controllable body.",
		failures
	)
	route_scene.free()
	return failures
