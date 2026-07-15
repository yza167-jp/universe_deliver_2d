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
		terminal.order_definition != null
		and terminal.order_definition.id == &"order_red_sand_m0",
		"Order terminal must reference the single Red Sand Resource.",
		failures
	)
	expect_true(
		terminal.get_node_or_null("TerminalPanel") is PanelContainer,
		"Order terminal must provide a readable full-screen panel.",
		failures
	)
	expect_true(
		terminal.find_child("CancelButton", true, false) == null,
		"Main-order terminal must not expose a cancellation button.",
		failures
	)
	terminal.free()
	return failures
