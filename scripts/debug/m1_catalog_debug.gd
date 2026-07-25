class_name M1DebugCatalogView
extends Control

@onready var _order_terminal: OrderTerminalUI = %OrderTerminalUI

var last_error: String = ""


func configure_focus(
	registry: GameDataRegistry,
	order_id: StringName
) -> bool:
	last_error = ""
	if _order_terminal == null or registry == null:
		last_error = "Catalog debug view is missing its terminal or registry."
		return false
	var order: OrderDefinition = registry.find_order(order_id)
	if order == null:
		last_error = "Catalog debug order is unknown: %s." % order_id
		return false
	_order_terminal.set_order_definition(order)
	if not _order_terminal.open_terminal():
		last_error = "Catalog debug terminal could not open."
		return false
	if not _order_terminal.select_order(order.id):
		last_error = "Catalog debug terminal could not select %s." % order.id
		return false
	_order_terminal.focus_selected_order()
	return true


func get_order_terminal() -> OrderTerminalUI:
	return _order_terminal
