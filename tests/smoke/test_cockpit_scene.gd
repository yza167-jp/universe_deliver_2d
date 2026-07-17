extends ProjectTestSuite

const COCKPIT_SCENE_PATH: String = "res://scenes/cockpit/cockpit.tscn"
const EXPECTED_HOTSPOT_IDS: Array[StringName] = [
	&"navigation_screen",
	&"window_view",
	&"lao_pi_seat",
	&"company_terminal",
	&"radio",
	&"cargo_indicator",
]


func run() -> Array[String]:
	var failures: Array[String] = []
	var packed_scene: PackedScene = load(COCKPIT_SCENE_PATH) as PackedScene
	expect_true(packed_scene != null, "Cockpit scene must load.", failures)
	if packed_scene == null:
		return failures
	var cockpit: Cockpit = packed_scene.instantiate() as Cockpit
	expect_true(cockpit != null, "Cockpit scene root must use the Cockpit controller.", failures)
	if cockpit == null:
		return failures
	var hotspots_root: Control = cockpit.get_node_or_null("Hotspots") as Control
	var starfield: CockpitStarfield = cockpit.get_node_or_null("Starfield") as CockpitStarfield
	var modal_layer: Control = cockpit.get_node_or_null("ModalLayer") as Control
	var device_panel: PanelContainer = cockpit.get_node_or_null(
		"ModalLayer/DevicePanel"
	) as PanelContainer
	expect_true(hotspots_root != null, "Cockpit must contain its hotspot layer.", failures)
	expect_true(starfield != null, "Cockpit must contain its animated starfield.", failures)
	expect_true(modal_layer != null, "Cockpit must contain a modal input blocker.", failures)
	expect_true(device_panel != null, "Cockpit must contain its reusable device panel.", failures)
	expect_true(cockpit.data_registry != null, "Cockpit must expose M0 order and cargo data.", failures)
	expect_true(cockpit.lao_pi_dialogue != null, "Cockpit must provide Lao Pi's dialogue sequence.", failures)
	if starfield != null:
		expect_true(starfield.get_layer_count() >= 3, "Starfield must expose at least three layers.", failures)
	if hotspots_root != null:
		var found_ids: Array[StringName] = []
		for child: Node in hotspots_root.get_children():
			if not child is Button:
				continue
			var button: Button = child as Button
			var hotspot_id: StringName = StringName(String(button.get_meta("hotspot_id", "")))
			expect_true(
				not found_ids.has(hotspot_id),
				"Cockpit hotspot IDs must be unique: %s" % hotspot_id,
				failures
			)
			found_ids.append(hotspot_id)
			expect_true(
				button.focus_mode == Control.FOCUS_ALL,
				"Cockpit hotspot must support keyboard focus: %s" % hotspot_id,
				failures
			)
			expect_true(
				button.custom_minimum_size.x >= 80.0 and button.custom_minimum_size.y >= 48.0,
				"Cockpit hotspot is too small for reliable input: %s" % hotspot_id,
				failures
			)
			expect_true(
				button.tooltip_text.is_empty(),
				"Cockpit hotspot must not duplicate details through a tooltip: %s" % hotspot_id,
				failures
			)
		for hotspot_id: StringName in EXPECTED_HOTSPOT_IDS:
			expect_true(found_ids.has(hotspot_id), "Missing cockpit hotspot: %s" % hotspot_id, failures)
		expect_true(
			found_ids.size() == EXPECTED_HOTSPOT_IDS.size(),
			"Cockpit must expose exactly six task-scoped hotspots.",
			failures
		)
	expect_true(
		cockpit.get_node_or_null("Content/PlaceholderLabel") == null,
		"Cockpit must replace the old placeholder screen.",
		failures
	)
	cockpit.free()
	return failures
