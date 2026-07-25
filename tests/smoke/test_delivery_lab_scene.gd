extends ProjectTestSuite

const DELIVERY_LAB_SCENE_PATH: String = "res://scenes/flight/delivery_lab.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	var packed_scene: PackedScene = load(DELIVERY_LAB_SCENE_PATH) as PackedScene
	expect_true(packed_scene != null, "Delivery Lab scene must load.", failures)
	if packed_scene == null:
		return failures

	var delivery_lab: DeliveryLab = packed_scene.instantiate() as DeliveryLab
	expect_true(
		delivery_lab != null and delivery_lab.name == &"DeliveryLab",
		"Delivery Lab root must use the reusable DeliveryLab controller.",
		failures
	)
	if delivery_lab == null:
		return failures
	var flight_ship: FlightLabShip = delivery_lab.get_node_or_null(
		"World/FlightShip"
	) as FlightLabShip
	expect_true(
		flight_ship is CharacterBody2D
		and flight_ship.tuning is FlightTuning
		and flight_ship.environment_profile is FlightEnvironmentProfile
		and flight_ship.environment_profile.id == &"environment_canopy_world_placeholder",
		"Delivery Lab must reuse the M0 CharacterBody2D flight baseline in the Canopy placeholder environment.",
		failures
	)
	expect_true(
		flight_ship != null
		and flight_ship.cargo_definition is CargoDefinition
		and flight_ship.cargo_definition.id == &"cargo_canopy_spore_stabilizer",
		"Delivery Lab must carry the registered Canopy spore stabilizer cargo.",
		failures
	)
	expect_true(
		delivery_lab.drop_profile is LowAltitudeDropProfile
		and delivery_lab.drop_profile.validate().is_empty(),
		"Delivery Lab must use one valid centralized low-altitude drop profile.",
		failures
	)
	expect_true(
		delivery_lab.get_node_or_null("World/ReceiveZone/CoreZone") is Polygon2D
		and delivery_lab.get_node_or_null("World/ReceiveZone/OuterZone") is Polygon2D
		and delivery_lab.get_node_or_null("World/CargoMarker") is Polygon2D
		and delivery_lab.get_node_or_null("World/PredictionMarker") is Polygon2D,
		"Delivery Lab must make core, outer, cargo, and predicted landing feedback visible.",
		failures
	)
	expect_true(
		not _contains_rigid_body(delivery_lab),
		"Low-altitude delivery must not introduce rigid-body projectile simulation.",
		failures
	)
	expect_true(
		UniverseDeliverApp.DELIVERY_LAB_SCENE_PATH == DELIVERY_LAB_SCENE_PATH
		and UniverseDeliverApp.should_start_in_delivery_lab(
			true,
			PackedStringArray([UniverseDeliverApp.DEBUG_DELIVERY_LAB_ARGUMENT])
		),
		"Delivery Lab must have an explicit direct debug route.",
		failures
	)
	delivery_lab.free()
	return failures


func _contains_rigid_body(node: Node) -> bool:
	if node is RigidBody2D:
		return true
	for child: Node in node.get_children():
		if _contains_rigid_body(child):
			return true
	return false
