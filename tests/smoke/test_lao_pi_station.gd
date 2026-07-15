extends ProjectTestSuite

const LAO_PI_SCENE_PATH: String = "res://scenes/station/lao_pi_station.tscn"
const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	var scene: PackedScene = load(LAO_PI_SCENE_PATH) as PackedScene
	var lao_pi: LaoPiStation = scene.instantiate() as LaoPiStation
	expect_true(lao_pi != null, "Lao Pi station scene must instantiate.", failures)
	if lao_pi == null:
		return failures

	lao_pi.initialize_placeholder_animations()
	expect_true(lao_pi.interaction_id == &"lao_pi", "Lao Pi needs a stable ID.", failures)
	expect_true(
		lao_pi.prompt_key == &"UI_INTERACTION_LAO_PI",
		"Lao Pi interaction must use a localization key.",
		failures
	)
	expect_true(
		lao_pi.interaction_priority > 100,
		"Lao Pi must win interaction selection over nearby furniture.",
		failures
	)
	expect_true(
		lao_pi.get_node_or_null("CollisionShape2D") is CollisionShape2D,
		"Lao Pi must expose an interaction area.",
		failures
	)

	var sprite: AnimatedSprite2D = lao_pi.get_node_or_null(
		"VisualRoot/LaoPiSprite"
	) as AnimatedSprite2D
	expect_true(sprite != null, "Lao Pi needs an animated placeholder sprite.", failures)
	if sprite != null:
		for animation_name: StringName in [
			&"idle_down",
			&"idle_up",
			&"idle_side",
			&"walk_down",
			&"walk_up",
			&"walk_side",
			&"talk_down",
			&"talk_up",
			&"talk_side",
		]:
			expect_true(
				sprite.sprite_frames.has_animation(animation_name),
				"Lao Pi placeholder animation is missing: %s" % animation_name,
				failures
			)
		var frame_texture: Texture2D = sprite.sprite_frames.get_frame_texture(&"idle_down", 0)
		expect_true(
			frame_texture != null
			and frame_texture.get_width() == 48
			and frame_texture.get_height() == 56,
			"Lao Pi placeholder must remain inside the 48x56 character budget.",
			failures
		)
	lao_pi.free()

	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	var station: StationHub = station_scene.instantiate() as StationHub
	var stationed_lao_pi: LaoPiStation = station.get_lao_pi()
	expect_true(stationed_lao_pi != null, "Station must include Lao Pi.", failures)
	if stationed_lao_pi != null:
		expect_true(
			stationed_lao_pi.position.is_equal_approx(Vector2(338.0, 360.0)),
			"Lao Pi must start at the authored station position.",
			failures
		)
	station.free()
	return failures
