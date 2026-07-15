extends ProjectTestSuite

const LOADOUT_SCENE_PATH: String = "res://scenes/ui/ship_loadout.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	var loadout_scene: PackedScene = load(LOADOUT_SCENE_PATH) as PackedScene
	var loadout_ui: ShipLoadoutUI = loadout_scene.instantiate() as ShipLoadoutUI

	expect_true(loadout_ui != null, "Ship loadout scene must instantiate as ShipLoadoutUI.", failures)
	if loadout_ui == null:
		return failures
	expect_true(
		loadout_ui.order_definition != null
		and loadout_ui.order_definition.id == &"order_red_sand_m0",
		"Ship loadout must use the accepted Red Sand order data.",
		failures
	)
	for node_name: String in [
		"PowerSlot",
		"DefenseSlot",
		"UtilitySlot",
		"ConfirmButton",
		"LaserMountVisual",
	]:
		expect_true(
			loadout_ui.find_child(node_name, true, false) != null,
			"Ship loadout scene is missing: %s" % node_name,
			failures
		)
	expect_true(
		loadout_ui.find_child("ShipSelector", true, false) == null
		and loadout_ui.find_child("BuyButton", true, false) == null
		and loadout_ui.find_child("UpgradeTree", true, false) == null,
		"M0 loadout must not introduce ship purchasing, random modules, or an upgrade tree.",
		failures
	)
	loadout_ui.free()
	return failures
