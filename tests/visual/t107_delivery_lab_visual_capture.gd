extends SceneTree

const DELIVERY_LAB_SCENE_PATH: String = "res://scenes/flight/delivery_lab.tscn"
const CAPTURE_DIRECTORY: String = "res://.omx/artifacts/t107_delivery_lab"


func _initialize() -> void:
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	var packed_scene: PackedScene = load(DELIVERY_LAB_SCENE_PATH) as PackedScene
	var delivery_lab: DeliveryLab = (
		null if packed_scene == null else packed_scene.instantiate() as DeliveryLab
	)
	if delivery_lab == null:
		printerr("[t107-visual] Delivery Lab could not be instantiated.")
		quit(1)
		return
	root.add_child(delivery_lab)
	await _settle_frames(3)

	var ship: FlightLabShip = delivery_lab.get_flight_ship()
	var profile: LowAltitudeDropProfile = delivery_lab.get_drop_profile()
	if ship == null or profile == null:
		printerr("[t107-visual] Delivery Lab fixture is incomplete.")
		quit(1)
		return
	ship.process_mode = Node.PROCESS_MODE_DISABLED

	var altitude: float = 150.0
	var speed: float = 140.0
	var inherited_travel: float = (
		speed
		* profile.horizontal_velocity_inheritance
		* altitude
		/ profile.cargo_descent_speed
	)
	delivery_lab.debug_set_ship_state(
		delivery_lab.target_center_x - inherited_travel,
		altitude,
		speed
	)
	await _settle_frames(2)
	if not _save_frame("delivery_ready.png"):
		quit(1)
		return

	delivery_lab.request_drop()
	delivery_lab.debug_complete_cargo_fall()
	if delivery_lab.get_settled_result().status != LowAltitudeDropModel.Status.CORE_SUCCESS:
		printerr("[t107-visual] Core-success fixture resolved incorrectly.")
		quit(1)
		return
	await _settle_frames(2)
	if not _save_frame("delivery_core_success.png"):
		quit(1)
		return

	if not delivery_lab.restart_from_checkpoint(false):
		printerr("[t107-visual] Partial fixture could not restore checkpoint.")
		quit(1)
		return
	ship.process_mode = Node.PROCESS_MODE_DISABLED
	var partial_landing_x: float = (
		delivery_lab.target_center_x
		+ profile.core_zone_half_width
		+ 24.0
	)
	delivery_lab.debug_set_ship_state(
		partial_landing_x - inherited_travel,
		altitude,
		speed
	)
	var partial_result: LowAltitudeDropResult = delivery_lab.request_drop()
	delivery_lab.debug_complete_cargo_fall()
	if partial_result.status != LowAltitudeDropModel.Status.OUTER_PARTIAL:
		printerr("[t107-visual] Outer-partial fixture resolved incorrectly.")
		quit(1)
		return
	await _settle_frames(2)
	if not _save_frame("delivery_outer_partial.png"):
		quit(1)
		return

	if not delivery_lab.restart_from_checkpoint(false):
		printerr("[t107-visual] Missed fixture could not restore checkpoint.")
		quit(1)
		return
	ship.process_mode = Node.PROCESS_MODE_DISABLED
	var missed_landing_x: float = (
		delivery_lab.target_center_x
		+ profile.outer_zone_half_width
		+ 40.0
	)
	delivery_lab.debug_set_ship_state(
		missed_landing_x - inherited_travel,
		altitude,
		speed
	)
	var missed_result: LowAltitudeDropResult = delivery_lab.request_drop()
	delivery_lab.debug_complete_cargo_fall()
	if missed_result.status != LowAltitudeDropModel.Status.MISSED:
		printerr(
			"[t107-visual] Missed fixture resolved incorrectly: %d"
			% missed_result.status
		)
		quit(1)
		return
	await _settle_frames(2)
	if not _save_frame("delivery_missed.png"):
		quit(1)
		return

	delivery_lab.queue_free()
	await _settle_frames(2)
	print(
		"[t107-visual] PASS: saved ready, core, partial, and missed "
		+ "640x360 Chinese frames."
	)
	quit(0)


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _save_frame(file_name: String) -> bool:
	var absolute_directory: String = ProjectSettings.globalize_path(
		CAPTURE_DIRECTORY
	)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		printerr("[t107-visual] Could not create capture directory.")
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("[t107-visual] Viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	if image.save_png(output_path) != OK:
		printerr("[t107-visual] Could not save %s." % output_path)
		return false
	print("[t107-visual] Saved %s" % output_path)
	return true
