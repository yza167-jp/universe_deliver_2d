extends SceneTree

const SCENE_PATH: String = "res://scenes/flight/white_noise_flight.tscn"
const BRANCH_IDS: Array[StringName] = [
	&"white_noise_fast",
	&"white_noise_balanced",
	&"white_noise_scenic",
]

var _flight: WhiteNoiseFlight


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	_flight = packed.instantiate() as WhiteNoiseFlight
	if _flight == null:
		_fail("Independent White Noise scene could not instantiate.")
		return
	root.add_child(_flight)
	await process_frame
	await physics_frame
	if not _validate_scene_contract():
		return
	if not _validate_branches_and_checkpoints():
		return
	if not _validate_landing():
		return
	_flight.queue_free()
	await process_frame
	print(
		"[t120-route-smoke] PASS: six segments, three rejoining lanes, "
		+ "checkpoint retry, independent collision geometry, and landing."
	)
	quit(0)


func _validate_scene_contract() -> bool:
	var viewport_size: Vector2 = root.get_visible_rect().size
	if (
		_flight.get_flight_ship() == null
		or _flight.get_flight_camera() == null
		or _flight.get_route_hud() == null
		or _flight.get_route_visuals() == null
		or _flight.get_route_definition() == null
		or _flight.get_route_definition().segments.size() != 6
		or _flight.get_route_visuals().get_collision_body_count() < 5
		or viewport_size.x < 640.0
		or viewport_size.y < 360.0
	):
		_fail("White Noise scene contract or 640x360 HUD baseline is incomplete.")
		return false
	var forbidden: PackedStringArray = [
		"RedSandLowFlightCourse",
		"FlightRadarSector",
		"FlightRadarCover",
		"RedSandHazardDirector",
	]
	for node: Node in _walk_tree(_flight):
		for forbidden_type: String in forbidden:
			if node.get_class() == forbidden_type or node.name.contains(forbidden_type):
				_fail("White Noise route contains forbidden Red Sand component.")
				return false
	return true


func _validate_branches_and_checkpoints() -> bool:
	var route: WhiteNoiseRouteDefinition = _flight.get_route_definition()
	for branch_id: StringName in BRANCH_IDS:
		if not _flight.debug_set_route_state(11200.0, branch_id):
			_fail("Could not enter branch %s." % branch_id)
			return false
		if (
			_flight.get_active_branch_id() != branch_id
			or _flight.has_branch_rejoined()
		):
			_fail("Branch %s did not remain active before the join." % branch_id)
			return false
		var ship: FlightLabShip = _flight.get_flight_ship()
		ship.position += Vector2(140.0, 10.0)
		ship.velocity = Vector2(80.0, 0.0)
		if not _flight.restart_from_checkpoint(false):
			_fail("Checkpoint retry failed on branch %s." % branch_id)
			return false
		var branch: WhiteNoiseRouteBranch = route.get_branch(branch_id)
		if (
			ship.get_checkpoint_id() != &"checkpoint_white_noise_ice_rift"
			or absf(ship.position.y - branch.retry_y) > 0.1
			or ship.is_failed
		):
			_fail("Branch checkpoint restored an unsafe or wrong state.")
			return false
		if not _flight.debug_set_route_state(17100.0, branch_id):
			_fail("Could not reach the shared branch join.")
			return false
		if (
			_flight.get_active_branch_id() != branch_id
			or not _flight.has_branch_rejoined()
			or _flight.get_active_segment_index() != 3
		):
			_fail("Branch %s did not rejoin the aurora segment." % branch_id)
			return false
	return true


func _validate_landing() -> bool:
	var visuals: WhiteNoiseRouteVisuals = _flight.get_route_visuals()
	if (
		visuals.get_landing_pad_start_distance() < 32700.0
		or visuals.get_landing_contact_distance()
		- _flight.get_route_definition().segments[5].start_distance
		< 5000.0
	):
		_fail("Landing approach lacks a clear final corridor.")
		return false
	if not _flight.debug_set_route_state(
		visuals.get_landing_contact_distance() + 4.0
	):
		_fail("Could not enter the landing contact window.")
		return false
	var ship: FlightLabShip = _flight.get_flight_ship()
	ship.position.y = visuals.get_landing_pad_y() - 12.0
	ship.velocity = Vector2(42.0, 12.0)
	ship.rotation = deg_to_rad(3.0)
	_flight._process(0.0)
	if not _flight.is_route_completed() or not ship.is_landed:
		_fail("Safe final approach did not complete the T-120 route.")
		return false
	return true


func _walk_tree(node: Node) -> Array[Node]:
	var nodes: Array[Node] = [node]
	for child: Node in node.get_children():
		nodes.append_array(_walk_tree(child))
	return nodes


func _fail(message: String) -> void:
	printerr("[t120-route-smoke] FAIL: %s" % message)
	if _flight != null and is_instance_valid(_flight):
		_flight.queue_free()
	quit(1)
