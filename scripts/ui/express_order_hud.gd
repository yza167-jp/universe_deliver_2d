class_name ExpressOrderHUD
extends PanelContainer

## Persistent, single-owner runtime driver and compact view for active express orders.

const DRIVER_GROUP: StringName = &"express_order_timer_driver"
const DIALOGUE_PAUSE_GROUP: StringName = &"express_order_dialogue_pause"
const HELP_PAUSE_GROUP: StringName = &"express_order_help_pause"

@export var data_registry: GameDataRegistry

@onready var _primary_label: Label = %PrimaryLabel
@onready var _secondary_label: Label = %SecondaryLabel

var game_state_override: GameStateModel
var order_override: OrderDefinition

var _game_state: GameStateModel
var _active_order: OrderDefinition
var _timing_status: StringName = M1OrderRules.TIMING_STATUS_NONE
var _pause_override_enabled: bool = false
var _dialogue_pause_override: bool = false
var _help_pause_override: bool = false
var _game_pause_override: bool = false


func _enter_tree() -> void:
	add_to_group(DRIVER_GROUP)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_resolve_game_state()
	refresh_from_state()


func _exit_tree() -> void:
	_active_order = null
	_game_state = null


func _process(delta: float) -> void:
	advance_timing(delta)


func set_game_state_override(game_state: GameStateModel) -> void:
	game_state_override = game_state
	_game_state = null
	_resolve_game_state()
	refresh_from_state()


func set_order_override(order: OrderDefinition) -> void:
	order_override = order
	refresh_from_state()


## Test seam for the three independently required pause sources.
func set_pause_state_override(
	dialogue_open: bool,
	help_open: bool,
	game_paused: bool
) -> void:
	_pause_override_enabled = true
	_dialogue_pause_override = dialogue_open
	_help_pause_override = help_open
	_game_pause_override = game_paused
	refresh_from_state()


func clear_pause_state_override() -> void:
	_pause_override_enabled = false
	refresh_from_state()


func advance_timing(delta: float) -> bool:
	if not _is_authoritative_driver():
		visible = false
		return false
	var game_state: GameStateModel = _resolve_game_state()
	var order: OrderDefinition = _resolve_active_order()
	if game_state == null or order == null:
		_hide_timing()
		return false
	var pause_state: Dictionary[StringName, bool] = _get_pause_state()
	var advanced: bool = game_state.advance_active_order_time(
		order,
		delta,
		pause_state.get(&"dialogue", false),
		pause_state.get(&"help", false),
		pause_state.get(&"game", false)
	)
	refresh_from_state()
	return advanced


func refresh_from_state() -> void:
	if not _is_authoritative_driver():
		_hide_timing()
		return
	var game_state: GameStateModel = _resolve_game_state()
	var order: OrderDefinition = _resolve_active_order()
	if game_state == null or order == null:
		_hide_timing()
		return
	var run_state: OrderRunState = game_state.get_active_order_run_state()
	if run_state == null:
		_hide_timing()
		return
	var pause_state: Dictionary[StringName, bool] = _get_pause_state()
	var dialogue_open: bool = pause_state.get(&"dialogue", false)
	var help_open: bool = pause_state.get(&"help", false)
	var timing_paused: bool = M1OrderRules.is_timing_paused(
		dialogue_open,
		help_open,
		pause_state.get(&"game", false)
	)
	_timing_status = M1OrderRules.get_timing_status(
		order,
		run_state.elapsed_time,
		timing_paused
	)
	var reward_ratio: float = M1OrderRules.get_reward_ratio(
		order,
		run_state.elapsed_time
	)
	_primary_label.text = _build_primary_text(
		order,
		run_state.elapsed_time,
		timing_paused
	)
	_secondary_label.text = tr(
		String(_get_status_key(_timing_status))
	) % roundi(reward_ratio * 100.0)
	# Blocking modals own their pause notice, so the compact HUD cannot leave
	# clipped fragments around those panels. A pure system pause keeps it visible.
	visible = not dialogue_open and not help_open


func is_timing_visible() -> bool:
	return visible


func has_active_express_order() -> bool:
	return _active_order != null


func get_timing_status() -> StringName:
	return _timing_status


func get_primary_text() -> String:
	return "" if _primary_label == null else _primary_label.text


func get_secondary_text() -> String:
	return "" if _secondary_label == null else _secondary_label.text


func get_panel_rect() -> Rect2:
	return get_global_rect()


func _resolve_game_state() -> GameStateModel:
	var next_game_state: GameStateModel = game_state_override
	if next_game_state == null:
		next_game_state = get_node_or_null("/root/GameState") as GameStateModel
	_game_state = next_game_state
	return _game_state


func _resolve_active_order() -> OrderDefinition:
	_active_order = null
	if _game_state == null or _game_state.current_order_id.is_empty():
		return null
	var candidate: OrderDefinition = order_override
	if candidate == null and data_registry != null:
		candidate = data_registry.find_order(_game_state.current_order_id)
	if (
		candidate == null
		or candidate.id != _game_state.current_order_id
		or not candidate.is_express
		or _game_state.get_order_status(candidate.id)
		!= GameStateModel.OrderStatus.ACCEPTED
	):
		return null
	_active_order = candidate
	return _active_order


func _get_pause_state() -> Dictionary[StringName, bool]:
	if _pause_override_enabled:
		return {
			&"dialogue": _dialogue_pause_override,
			&"help": _help_pause_override,
			&"game": _game_pause_override,
		}
	var scene_tree: SceneTree = get_tree()
	return {
		&"dialogue": _has_visible_pause_source(DIALOGUE_PAUSE_GROUP),
		&"help": _has_visible_pause_source(HELP_PAUSE_GROUP),
		&"game": scene_tree != null and scene_tree.paused,
	}


func _has_visible_pause_source(group_id: StringName) -> bool:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return false
	for source: Node in scene_tree.get_nodes_in_group(group_id):
		if source is CanvasItem and (source as CanvasItem).is_visible_in_tree():
			return true
	return false


func _is_authoritative_driver() -> bool:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return true
	var authoritative_id: int = get_instance_id()
	for candidate: Node in scene_tree.get_nodes_in_group(DRIVER_GROUP):
		authoritative_id = mini(authoritative_id, candidate.get_instance_id())
	return get_instance_id() == authoritative_id


func _build_primary_text(
	order: OrderDefinition,
	elapsed_time: float,
	timing_paused: bool
) -> String:
	var elapsed_text: String = M1OrderRules.format_duration(elapsed_time)
	if timing_paused:
		return tr("UI_EXPRESS_HUD_PRIMARY_PAUSED") % elapsed_text
	var remaining_seconds: float = order.target_seconds - elapsed_time
	if remaining_seconds >= 0.0:
		return tr("UI_EXPRESS_HUD_PRIMARY_REMAINING") % [
			elapsed_text,
			M1OrderRules.format_duration(remaining_seconds, true),
		]
	return tr("UI_EXPRESS_HUD_PRIMARY_OVERTIME") % [
		elapsed_text,
		M1OrderRules.format_duration(-remaining_seconds),
	]


func _get_status_key(status: StringName) -> StringName:
	match status:
		M1OrderRules.TIMING_STATUS_GRACE:
			return &"UI_EXPRESS_HUD_STATUS_GRACE"
		M1OrderRules.TIMING_STATUS_FLOOR:
			return &"UI_EXPRESS_HUD_STATUS_FLOOR"
		M1OrderRules.TIMING_STATUS_PAUSED:
			return &"UI_EXPRESS_HUD_STATUS_PAUSED"
		_:
			return &"UI_EXPRESS_HUD_STATUS_FULL"


func _hide_timing() -> void:
	_active_order = null
	_timing_status = M1OrderRules.TIMING_STATUS_NONE
	visible = false
