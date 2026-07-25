extends ProjectTestSuite

const ORDER_TERMINAL_SCENE_PATH: String = "res://scenes/ui/order_terminal.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	var scene: PackedScene = load(ORDER_TERMINAL_SCENE_PATH) as PackedScene
	var terminal: OrderTerminalUI = scene.instantiate() as OrderTerminalUI
	expect_true(terminal != null, "Order terminal scene must instantiate.", failures)
	if terminal == null:
		return failures
	expect_true(
		terminal.data_registry != null
		and terminal.data_registry.registry_id == &"m1_four_planet_demo"
		and terminal.order_definition == null,
		"Normal order terminal scenes must consume the M1 registry without a fixed order override.",
		failures
	)
	expect_true(
		terminal.get_node_or_null("TerminalPanel") is PanelContainer,
		"Order terminal must provide a readable full-screen panel.",
		failures
	)
	expect_true(
		terminal.get_node_or_null(
			"TerminalPanel/Margin/Content/Body/DirectoryPanel"
		) is PanelContainer
		and terminal.get_node_or_null(
			"TerminalPanel/Margin/Content/Body/DetailPanel"
		) is PanelContainer,
		"Order terminal must provide separate directory and selected-detail regions.",
		failures
	)
	expect_true(
		terminal.find_child("CancelButton", true, false) == null,
		"Main-order terminal must not expose a cancellation button.",
		failures
	)
	terminal.free()
	return failures
