extends SceneTree

const SCENE_PATH: String = (
	"res://scenes/arrival/white_noise_arrival.tscn"
)
const ORDER_PATH: String = (
	"res://data/orders/m1_white_noise_archive_core.tres"
)
const FLIGHT_SCENE_PATH: String = (
	"res://scenes/flight/white_noise_flight.tscn"
)
const CAPTURE_DIRECTORY: String = (
	"res://.omx/artifacts/t124_white_noise_arrival"
)

var _original_locale: String = ""
var _game_state: GameStateModel
var _arrival: WhiteNoiseArrival


func _initialize() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	if not _prepare_fixture():
		_fail("Could not prepare the White Noise arrival fixture.")
		return
	var packed_scene: PackedScene = load(SCENE_PATH) as PackedScene
	_arrival = packed_scene.instantiate() as WhiteNoiseArrival
	if _arrival == null:
		_fail("White Noise arrival scene could not instantiate.")
		return
	_arrival.game_state_override = _game_state
	root.add_child(_arrival)
	await _settle_frames(5)
	var player: StationPlayer = _arrival.get_station_player()
	var dialogue_ui: DialogueUI = _arrival.get_dialogue_ui()
	if player == null or dialogue_ui == null:
		_fail("White Noise arrival visual fixture is missing player or dialogue UI.")
		return
	if (
		dialogue_ui.skip_dialogue_sequence()
		!= DialogueRuntime.SequenceSkipResult.STOPPED_AT_CHOICE
	):
		_fail("White Noise arrival choice could not be staged.")
		return
	await _settle_frames(3)
	if not _save_frame("01_archive_access_choice.png"):
		return
	if (
		not dialogue_ui.select_choice(&"local_shared_custody")
		or dialogue_ui.skip_dialogue_sequence()
		!= DialogueRuntime.SequenceSkipResult.FINISHED
	):
		_fail("White Noise arrival choice could not finish.")
		return
	await _settle_frames(4)
	player.global_position = Vector2(390.0, 292.0)
	await _settle_physics_frames(3)
	if not _save_frame("02_delivery_and_archive_bays.png"):
		return
	player.global_position = Vector2(792.0, 292.0)
	await _settle_physics_frames(3)
	if not _arrival.get_memory_owner().interact(player):
		_fail("Memory-owner dialogue could not be staged.")
		return
	await _settle_frames(3)
	dialogue_ui.quick_show_current_line()
	await _settle_frames(1)
	if not _save_frame("03_memory_owner_followup.png"):
		return
	if (
		dialogue_ui.skip_dialogue_sequence()
		!= DialogueRuntime.SequenceSkipResult.FINISHED
	):
		_fail("Memory-owner dialogue could not finish.")
		return
	await _settle_frames(2)
	_arrival.dismiss_status()
	await _settle_frames(1)
	if not _arrival.get_index_terminal().interact(player):
		_fail("Index observation could not be staged.")
		return
	await _settle_frames(3)
	if not _save_frame("04_choice_aware_relay_index.png"):
		return
	_restore_runtime()
	_arrival.queue_free()
	await _settle_frames(2)
	print(
		"[t124-visual] PASS: saved archive choice, delivery bays, "
		+ "memory-owner follow-up, and choice-aware relay index frames."
	)
	quit(0)


func _prepare_fixture() -> bool:
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	var source: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	if _game_state == null or source == null or source.destination_planet == null:
		return false
	_game_state.reset_runtime_state()
	var fixture: OrderDefinition = source.duplicate(true) as OrderDefinition
	var planet: PlanetDefinition = (
		source.destination_planet.duplicate(true) as PlanetDefinition
	)
	if fixture == null or planet == null:
		return false
	fixture.content_readiness = OrderDefinition.ContentReadiness.PLAYABLE
	fixture.required_chapter = &""
	fixture.unlock_conditions.clear()
	fixture.story_requirements.clear()
	planet.content_readiness = PlanetDefinition.ContentReadiness.PLAYABLE
	planet.flight_scene_path = FLIGHT_SCENE_PATH
	fixture.destination_planet = planet
	if not _game_state.accept_order(fixture):
		return false
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	run_state.cargo_integrity = 94.0
	run_state.record_landing_result(
		OrderRunState.LANDING_RESULT_SMOOTH,
		0.0
	)
	return true


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _settle_physics_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await physics_frame


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
	print("[t124-visual] Saved %s" % output_path)
	return true


func _restore_runtime() -> void:
	if _game_state != null:
		_game_state.reset_runtime_state()
	TranslationServer.set_locale(_original_locale)


func _fail(message: String) -> void:
	printerr("[t124-visual] FAIL: %s" % message)
	_restore_runtime()
	if _arrival != null and is_instance_valid(_arrival):
		_arrival.queue_free()
	quit(1)
