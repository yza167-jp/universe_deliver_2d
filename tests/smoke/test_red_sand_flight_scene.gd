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
		and route_scene.get_node_or_null("RedSandRouteHUD") is RedSandRouteHUD
		and route_scene.get_node_or_null(
			"RedSandRouteHUD/FlightControlsHelp"
		) is FlightControlsHelp,
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
		route_scene.get_node_or_null("Backdrop/AtmosphereHorizon") is Node2D
		and route_scene.get_node_or_null(
			"Backdrop/AtmosphereHorizon/CurvedSurface"
		) is Polygon2D
		and route_scene.get_node_or_null(
			"Backdrop/AtmosphereHorizon/HorizonGlow"
		) is Line2D,
		"Orbit-to-atmosphere handoff must bind one centralized curved-horizon layer.",
		failures
	)
	expect_true(
		route_scene.get_node_or_null("RedSandRouteHUD/FlightPanel") is PanelContainer
		and route_scene.get_node_or_null(
			"RedSandRouteHUD/DiagnosticsPanel"
		) is PanelContainer
		and route_scene.get_node_or_null(
			"RedSandRouteHUD/FlightPanel/Margin/Content/SafetyLabel"
		) is Label,
		"Route HUD must separate always-on essentials from H full diagnostics.",
		failures
	)
	expect_true(
		route_scene.route_definition != null
		and route_scene.route_definition.segments.size() == 8
		and route_scene.route_definition.validate().is_empty()
		and route_scene.get_altitude_reference_provider()
		is FlightAltitudeReferenceProvider,
		"Red Sand scene must bind its route data and shared altitude provider.",
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
		).is_empty()
		and route_scene.get_node_or_null(
			"World/LowFlightCourse/RouteHints/HighAltitudeSafeRouteLine"
		) is Line2D,
		"Gate C route must bind fixed low-altitude radar sectors and a high safe route.",
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
	var engine_trail: CPUParticles2D = flight_ship.get_node_or_null(
		"EngineTrailParticles"
	) as CPUParticles2D
	var boost_trail: CPUParticles2D = flight_ship.get_node_or_null(
		"BoostTrailParticles"
	) as CPUParticles2D
	expect_true(
		engine_trail != null
		and boost_trail != null
		and flight_ship.get_node_or_null("EngineAudio") is AudioStreamPlayer2D
		and flight_ship.get_node_or_null("BoostAudio") is AudioStreamPlayer2D
		and flight_ship.get_node_or_null("CollisionAudio") is AudioStreamPlayer2D,
		"T-044 route ship must bind propulsion particles and synthesized feedback audio.",
		failures
	)
	if engine_trail != null and boost_trail != null:
		expect_true(
			engine_trail.local_coords
			and boost_trail.local_coords
			and engine_trail.gravity == Vector2.ZERO
			and boost_trail.gravity == Vector2.ZERO
			and engine_trail.direction.x < 0.0
			and boost_trail.direction.x < 0.0
			and boost_trail.amount >= engine_trail.amount * 2
			and boost_trail.initial_velocity_min > engine_trail.initial_velocity_max,
			"Propulsion trails must stay ship-local, rearward, zero-gravity, and Boost-distinct.",
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
		and environment_feedback.get_node_or_null("LandingDustParticles") == null
		and route_scene.get_node_or_null(
			"World/LandingZone/TouchdownDustParticles"
		) is CPUParticles2D
		and route_scene.get_node_or_null(
			"World/LandingZone/TouchdownBurstParticles"
		) is CPUParticles2D,
		"Screen-space weather and world-space touchdown particles must stay separated.",
		failures
	)
	expect_true(
		route_scene.find_children("*", "CharacterBody2D", true, false).size() == 1,
		"T-042 must not add enemies or another controllable body.",
		failures
	)
	route_scene.free()
	return failures
