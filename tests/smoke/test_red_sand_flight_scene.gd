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
		and route_scene.get_node_or_null("BackgroundLayers/LowerHaze") is Parallax2D,
		"Red Sand route must provide three distinct parallax depth layers.",
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
	expect_true(
		route_scene.find_children("*", "DestructibleAsteroid", true, false).is_empty(),
		"T-040 must not pre-implement T-041 asteroid hazards.",
		failures
	)
	route_scene.free()
	return failures
