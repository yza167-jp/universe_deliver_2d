extends ProjectTestSuite

const FLIGHT_LAB_SCENE_PATH: String = "res://scenes/flight/flight_lab.tscn"
const FLIGHT_STAGE_SCENE_PATH: String = "res://scenes/flight/flight_level.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	var packed_lab: PackedScene = load(FLIGHT_LAB_SCENE_PATH) as PackedScene
	var packed_stage: PackedScene = load(FLIGHT_STAGE_SCENE_PATH) as PackedScene
	expect_true(packed_lab != null, "Flight Lab scene must load.", failures)
	expect_true(packed_stage != null, "FLIGHT stage wrapper must load.", failures)
	if packed_lab == null or packed_stage == null:
		return failures

	var stage_scene: Node = packed_stage.instantiate()
	expect_true(stage_scene is FlightLab, "FLIGHT stage must host Flight Lab.", failures)
	expect_true(stage_scene.name == &"Flight", "FLIGHT stage root must remain Flight.", failures)
	stage_scene.free()

	var flight_lab: FlightLab = packed_lab.instantiate() as FlightLab
	expect_true(flight_lab != null, "Flight Lab root must use FlightLab.", failures)
	if flight_lab == null:
		return failures

	var flight_ship: FlightLabShip = flight_lab.get_node_or_null(
		"World/FlightShip"
	) as FlightLabShip
	var flight_camera: Camera2D = flight_lab.get_node_or_null(
		"World/FlightCamera"
	) as Camera2D
	var debug_hud: FlightDebugHUD = flight_lab.get_node_or_null(
		"FlightDebugHUD"
	) as FlightDebugHUD
	expect_true(flight_ship is CharacterBody2D, "Flight Lab ship must be CharacterBody2D.", failures)
	expect_true(
		flight_lab.get_node_or_null("World/FlightShip/ShipSprite") is Sprite2D,
		"Flight Lab must show a placeholder ship Sprite2D.",
		failures
	)
	expect_true(
		flight_lab.get_node_or_null("World/FlightShip/BoostGlow") is Polygon2D
		and flight_lab.get_node_or_null("World/FlightShip/ImpactSparks")
		is CPUParticles2D,
		"Flight Lab must expose minimum Boost and impact visual feedback.",
		failures
	)
	expect_true(flight_camera != null and flight_camera.enabled, "Flight Lab camera must be enabled.", failures)
	expect_true(debug_hud != null and debug_hud.visible, "Flight debug HUD must start visible.", failures)
	expect_true(
		flight_ship != null and flight_ship.tuning is FlightTuning,
		"Flight Lab ship must use a FlightTuning resource.",
		failures
	)
	expect_true(
		flight_ship != null
		and flight_ship.environment_profile is FlightEnvironmentProfile
		and flight_ship.environment_profile.id == &"environment_deep_space",
		"Flight Lab ship must start with the deep-space environment profile.",
		failures
	)
	expect_true(
		flight_ship != null
		and flight_ship.cargo_definition is CargoDefinition
		and flight_ship.cargo_definition.id == &"cargo_red_sand_m0",
		"Flight Lab must exercise the current story cargo resource rules.",
		failures
	)
	expect_true(
		flight_lab.environment_profiles.size() == 2
		and flight_lab.environment_profiles[1].id
		== &"environment_red_sand_atmosphere",
		"Flight Lab must expose deep-space and Red Sand atmosphere presets.",
		failures
	)
	expect_true(
		flight_lab.get_node_or_null("Backdrop/Space") is ColorRect,
		"Flight Lab must contain a space backdrop.",
		failures
	)
	expect_true(
		flight_lab.get_node_or_null("World/Terrain/Floor") is StaticBody2D
		and flight_lab.get_node_or_null("World/Terrain/Pillar") is StaticBody2D,
		"Flight Lab must contain simple collision terrain.",
		failures
	)
	expect_true(
		flight_lab.get_node_or_null("World/SpeedMarkers") is Node2D,
		"Flight Lab must contain world-space motion references.",
		failures
	)
	expect_true(
		flight_lab.get_node_or_null("Backdrop/AtmosphereTint") is ColorRect,
		"Flight Lab must provide minimal atmosphere transition feedback.",
		failures
	)

	if debug_hud != null:
		expect_true(
			debug_hud.get_node_or_null("HeaderPanel") is PanelContainer
			and debug_hud.get_node_or_null("StatsPanel") is PanelContainer,
			"Flight debug HUD must contain separate header and telemetry panels.",
			failures
		)

	if flight_ship != null:
		flight_ship.hull = 81.0
		flight_ship.shield = 52.0
		flight_ship.fuel = 63.0
		flight_ship.boost_energy = 47.0
		flight_ship.cargo_integrity = 88.0
		flight_ship.position = Vector2(420.0, 144.0)
		flight_ship.velocity = Vector2(74.0, -19.0)
		flight_ship.rotation = 0.24
		flight_ship.angular_velocity = -0.4
		expect_true(
			flight_ship.capture_checkpoint(&"checkpoint_test_custom"),
			"A non-empty checkpoint ID must capture stable flight state.",
			failures
		)
		flight_ship.resources.reset()
		flight_ship.position = Vector2(780.0, 92.0)
		flight_ship.velocity = Vector2(184.0, -73.0)
		flight_ship.rotation = 0.7
		flight_ship.angular_velocity = 1.4
		flight_ship.throttle_input = 1.0
		flight_ship.brake_input = 0.5
		flight_ship.pitch_input = -1.0
		flight_ship.cargo_integrity = 12.0
		flight_ship.gravity_acceleration = 88.0
		flight_ship.collision_state_key = &"temporary_collision_state"
		expect_true(
			flight_ship.restore_checkpoint(),
			"Captured checkpoint must be restorable.",
			failures
		)
	if flight_ship != null:
		expect_true(
			flight_ship.position == Vector2(420.0, 144.0)
			and flight_ship.velocity == Vector2(74.0, -19.0)
			and is_equal_approx(flight_ship.rotation, 0.24)
			and is_equal_approx(flight_ship.angular_velocity, -0.4)
			and is_zero_approx(flight_ship.throttle_input)
			and is_zero_approx(flight_ship.brake_input)
			and is_zero_approx(flight_ship.pitch_input)
			and is_zero_approx(flight_ship.boost_input),
			"Checkpoint restore must recover motion while clearing live input drift.",
			failures
		)
		expect_true(
			is_equal_approx(flight_ship.hull, 81.0)
			and is_equal_approx(flight_ship.shield, 52.0)
			and is_equal_approx(flight_ship.fuel, 63.0)
			and is_equal_approx(flight_ship.boost_energy, 47.0)
			and is_equal_approx(flight_ship.cargo_integrity, 88.0)
			and flight_ship.get_checkpoint_id() == &"checkpoint_test_custom"
			and flight_ship.collision_state_key == FlightLabShip.DEFAULT_COLLISION_KEY,
			"Checkpoint restore must recover all five resources and clear collision state.",
			failures
		)
	flight_lab.free()
	return failures
