extends ProjectTestSuite

const PLAYER_SCENE_PATH: String = "res://scenes/station/station_player.tscn"
const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene
	var standalone_player: StationPlayer = player_scene.instantiate() as StationPlayer
	expect_true(standalone_player != null, "Station player scene must instantiate.", failures)
	if standalone_player != null:
		standalone_player.initialize_placeholder_animations()
		_check_player_components(standalone_player, failures)
		standalone_player.free()

	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	var station: StationHub = station_scene.instantiate() as StationHub
	expect_true(station != null, "Station scene must instantiate with its player.", failures)
	if station == null:
		return failures
	expect_true(station.initialize_player(), "Station player must initialize at its spawn.", failures)
	var station_player: StationPlayer = station.get_station_player()
	var spawn: Marker2D = station.get_player_spawn()
	expect_true(station_player != null, "Station must expose its reusable player.", failures)
	expect_true(spawn != null, "Station must retain its player spawn anchor.", failures)
	if station_player != null and spawn != null:
		expect_true(
			station_player.position.is_equal_approx(spawn.position),
			"Station player must use the authored PlayerSpawn position.",
			failures
		)
		expect_true(
			station_player.get_facing_direction().is_equal_approx(Vector2.UP),
			"Station player must use the authored spawn facing.",
			failures
		)

	var interactables: Array[Interactable2D] = station.get_interactables()
	expect_true(
		interactables.size() == station.get_required_feature_ids().size(),
		"Every required station feature must have one interactable component.",
		failures
	)
	var seen_ids: Dictionary[StringName, bool] = {}
	for interactable: Interactable2D in interactables:
		expect_true(
			not interactable.interaction_id.is_empty(),
			"Station interactables must have stable IDs.",
			failures
		)
		expect_true(
			not seen_ids.has(interactable.interaction_id),
			"Station interaction IDs must be unique: %s" % interactable.interaction_id,
			failures
		)
		seen_ids[interactable.interaction_id] = true
		expect_true(
			not interactable.prompt_key.is_empty(),
			"Station interactables must use localized prompt keys.",
			failures
		)
		expect_true(
			interactable.get_node_or_null("CollisionShape2D") is CollisionShape2D,
			"Station interactables must expose a detection shape: %s" % interactable.name,
			failures
		)
	station.free()
	return failures


func _check_player_components(player: StationPlayer, failures: Array[String]) -> void:
	expect_true(player.move_speed > 0.0, "Player move speed must be tunable and positive.", failures)
	expect_true(player.acceleration > 0.0, "Player acceleration must be tunable and positive.", failures)
	expect_true(player.deceleration > 0.0, "Player deceleration must be tunable and positive.", failures)
	expect_true(
		player.get_node_or_null("CollisionShape2D") is CollisionShape2D,
		"Player must have a collision footprint.",
		failures
	)
	var sensor: Area2D = player.get_node_or_null("InteractionSensor") as Area2D
	expect_true(sensor != null, "Player must have an interaction sensor.", failures)
	if sensor != null:
		expect_true(sensor.collision_mask == 8, "Interaction sensor must use its isolated layer.", failures)
	var sprite: AnimatedSprite2D = player.get_node_or_null(
		"VisualRoot/PlayerSprite"
	) as AnimatedSprite2D
	expect_true(sprite != null, "Player must have an animated placeholder sprite.", failures)
	if sprite == null:
		return
	for animation_name: StringName in [
		&"idle_down",
		&"idle_up",
		&"idle_side",
		&"walk_down",
		&"walk_up",
		&"walk_side",
	]:
		expect_true(
			sprite.sprite_frames.has_animation(animation_name),
			"Player placeholder animation is missing: %s" % animation_name,
			failures
		)
