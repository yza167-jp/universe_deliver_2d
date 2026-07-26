extends ProjectTestSuite

const FORMAL_PLANET_PATH: String = "res://data/planets/white_noise.tres"
const FORMAL_ORDER_PATH: String = (
	"res://data/orders/m1_white_noise_archive_core.tres"
)


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_visual_identity_and_accessibility(failures)
	_test_procedural_audio_layers(failures)
	_test_formal_content_boundary(failures)
	return failures


func _test_visual_identity_and_accessibility(
	failures: Array[String]
) -> void:
	var visuals: WhiteNoiseRouteVisuals = WhiteNoiseRouteVisuals.new()
	expect_true(
		visuals.get_presentation_signature()
		== &"white_noise_ice_aurora_archive"
		and visuals.get_background_layer_count() >= 7
		and visuals.get_blizzard_streak_count() == 92
		and is_equal_approx(visuals.get_visual_noise_scale(), 1.0),
		"T-123 must expose a dedicated layered White Noise presentation.",
		failures
	)
	visuals.set_accessibility(true, true)
	expect_true(
		visuals.get_blizzard_streak_count() == 38
		and visuals.get_visual_noise_scale() < 0.5,
		"High contrast must reduce blizzard density and visual noise.",
		failures
	)
	visuals.free()


func _test_procedural_audio_layers(failures: Array[String]) -> void:
	var feedback: WhiteNoiseEnvironmentFeedback = (
		WhiteNoiseEnvironmentFeedback.new()
	)
	var safe_stream: AudioStreamWAV = feedback._create_ambience_stream(
		&"safe"
	)
	var storm_stream: AudioStreamWAV = feedback._create_ambience_stream(
		&"storm"
	)
	var archive_stream: AudioStreamWAV = feedback._create_ambience_stream(
		&"archive"
	)
	var motif_stream: AudioStreamWAV = feedback._create_memory_motif_stream()
	expect_true(
		feedback.get_presentation_signature()
		== &"white_noise_safe_storm_archive_motif"
		and _stream_has_signal(safe_stream)
		and _stream_has_signal(storm_stream)
		and _stream_has_signal(archive_stream)
		and _stream_has_signal(motif_stream)
		and safe_stream.data != storm_stream.data
		and storm_stream.data != archive_stream.data,
		"Safe, storm, archive, and motif audio must be distinct generated streams.",
		failures
	)
	feedback.free()


func _test_formal_content_boundary(failures: Array[String]) -> void:
	var planet: PlanetDefinition = load(FORMAL_PLANET_PATH) as PlanetDefinition
	var order: OrderDefinition = load(FORMAL_ORDER_PATH) as OrderDefinition
	expect_true(
		planet != null
		and order != null
		and planet.content_readiness
		== PlanetDefinition.ContentReadiness.REGISTERED_ONLY
		and planet.flight_scene_path.is_empty()
		and order.content_readiness
		== OrderDefinition.ContentReadiness.REGISTERED_ONLY,
		"T-123 presentation must not make formal White Noise content playable.",
		failures
	)


func _stream_has_signal(stream: AudioStreamWAV) -> bool:
	if stream == null or stream.data.is_empty():
		return false
	for byte: int in stream.data:
		if byte != 0:
			return true
	return false
