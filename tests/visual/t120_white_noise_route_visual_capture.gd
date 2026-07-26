extends SceneTree

const SCENE_PATH: String = "res://scenes/flight/white_noise_flight.tscn"
const CAPTURE_DIRECTORY: String = (
	"res://.omx/artifacts/t120_white_noise_route"
)

var _flight: WhiteNoiseFlight


func _initialize() -> void:
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	_flight = packed.instantiate() as WhiteNoiseFlight
	if _flight == null:
		_fail("White Noise route scene could not instantiate.")
		return
	root.add_child(_flight)
	await _settle_frames(3)
	_flight.get_flight_ship().process_mode = Node.PROCESS_MODE_DISABLED
	var requests: Array[Dictionary] = [
		{
			"file": "01_open_icefield_hud.png",
			"distance": 6200.0,
			"branch": &"white_noise_balanced",
			"ship_y": 470.0,
		},
		{
			"file": "02_ice_rift_entry.png",
			"distance": 9700.0,
			"branch": &"white_noise_balanced",
		},
		{
			"file": "03_branch_fast.png",
			"distance": 12100.0,
			"branch": &"white_noise_fast",
		},
		{
			"file": "04_branch_balanced.png",
			"distance": 12100.0,
			"branch": &"white_noise_balanced",
		},
		{
			"file": "05_branch_scenic.png",
			"distance": 12100.0,
			"branch": &"white_noise_scenic",
		},
		{
			"file": "06_aurora_blizzard_placeholder.png",
			"distance": 19000.0,
			"branch": &"white_noise_scenic",
		},
		{
			"file": "07_archive_entrance.png",
			"distance": 26500.0,
			"branch": &"white_noise_scenic",
			"ship_y": 380.0,
		},
		{
			"file": "08_branch_rejoin.png",
			"distance": 17150.0,
			"branch": &"white_noise_fast",
		},
		{
			"file": "09_landing_approach.png",
			"distance": 32600.0,
			"branch": &"white_noise_balanced",
			"ship_y": 500.0,
		},
	]
	for request: Dictionary in requests:
		if not _flight.debug_set_route_state(
			float(request.get("distance", 0.0)),
			StringName(request.get("branch", &"white_noise_balanced"))
		):
			_fail("Could not stage capture %s." % request.get("file", ""))
			return
		if request.has("ship_y"):
			_flight.get_flight_ship().position.y = float(
				request.get("ship_y", 240.0)
			)
			_flight._process(0.0)
		await _settle_frames(3)
		if not _save_frame(String(request.get("file", ""))):
			return
	_flight.queue_free()
	await _settle_frames(2)
	print(
		"[t120-visual] PASS: saved icefield, rift branches/rejoin, aurora "
		+ "placeholder, archive entrance, and landing approach frames."
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
		_fail("Could not create capture directory.")
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	if image.save_png(output_path) != OK:
		_fail("Could not save %s." % output_path)
		return false
	print("[t120-visual] Saved %s" % output_path)
	return true


func _fail(message: String) -> void:
	printerr("[t120-visual] FAIL: %s" % message)
	if _flight != null and is_instance_valid(_flight):
		_flight.queue_free()
	quit(1)
