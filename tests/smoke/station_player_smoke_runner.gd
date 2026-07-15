extends SceneTree

const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"

var _failures: PackedStringArray = []
var _interaction_signal_received: bool = false


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var original_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	var station: StationHub = station_scene.instantiate() as StationHub
	root.add_child(station)
	await process_frame
	await physics_frame

	var player: StationPlayer = station.get_station_player()
	_check(player != null, "Station player is missing from the live scene tree.")
	if player != null:
		await _check_live_movement(player)
		await _check_live_interaction(station, player)
		await process_frame

	Input.action_release(&"move_up")
	Input.action_release(&"move_right")
	station.queue_free()
	TranslationServer.set_locale(original_locale)
	await process_frame
	if _failures.is_empty():
		print("[station-player] PASS: movement, animation, prompt, priority target, and interaction signal.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("[station-player] %s" % failure)
	quit(1)


func _check_live_movement(player: StationPlayer) -> void:
	var start_position: Vector2 = player.position
	Input.action_press(&"move_up")
	Input.action_press(&"move_right")
	for _frame: int in 12:
		await physics_frame
	Input.action_release(&"move_up")
	Input.action_release(&"move_right")
	_check(player.position.x > start_position.x, "Diagonal input did not move the player right.")
	_check(player.position.y < start_position.y, "Diagonal input did not move the player up.")
	_check(
		player.velocity.length() <= player.move_speed + 0.1,
		"Live diagonal movement exceeded the configured speed."
	)
	_check(
		String(player.get_current_animation_name()).begins_with("walk_"),
		"Moving player did not enter a walk animation."
	)
	for _frame: int in 10:
		await physics_frame
	_check(player.velocity.length() < 0.1, "Player did not decelerate to rest after input release.")
	_check(
		String(player.get_current_animation_name()).begins_with("idle_"),
		"Stopped player did not return to an idle animation."
	)


func _check_live_interaction(station: StationHub, player: StationPlayer) -> void:
	var approach: Marker2D = station.get_feature_approach_anchor(&"order_terminal")
	var feature: Marker2D = station.get_feature_anchor(&"order_terminal")
	_check(approach != null and feature != null, "Order terminal interaction anchors are missing.")
	if approach == null or feature == null:
		return
	player.position = approach.position
	player.velocity = Vector2.ZERO
	player.set_facing_direction(feature.position - approach.position)
	await physics_frame
	await physics_frame
	var selected: Interactable2D = player.refresh_interaction_target()
	_check(selected != null, "Approaching the order terminal did not select an interaction target.")
	if selected == null:
		return
	_check(
		selected.interaction_id == &"order_terminal",
		"Approaching the order terminal selected the wrong target: %s" % selected.interaction_id
	)
	_check(player.is_interaction_prompt_visible(), "Interaction prompt is not visible near a target.")
	_check(
		player.get_interaction_prompt_text().contains("查看订单终端"),
		"Interaction prompt did not localize to the selected target."
	)
	selected.interaction_triggered.connect(_on_interaction_triggered)
	_check(player.try_interact(), "Selected interaction could not be triggered.")
	_check(_interaction_signal_received, "Interactable did not emit its interaction signal.")
	_check(
		player.get_interaction_prompt_text().contains("已确认"),
		"Interaction did not provide visible confirmation feedback."
	)
	await process_frame
	await process_frame


func _on_interaction_triggered(_actor: Node) -> void:
	_interaction_signal_received = true


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
