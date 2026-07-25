class_name OrderTerminalUI
extends Control

signal terminal_closed
signal order_accepted(order_id: StringName)

@export var order_definition: OrderDefinition

@onready var _terminal_title_label: Label = %TerminalTitleLabel
@onready var _status_badge_label: Label = %StatusBadgeLabel
@onready var _body_scroll: ScrollContainer = %BodyScroll
@onready var _order_name_label: Label = %OrderNameLabel
@onready var _parties_label: Label = %PartiesLabel
@onready var _route_label: Label = %RouteLabel
@onready var _reward_label: Label = %RewardLabel
@onready var _environment_heading_label: Label = %EnvironmentHeadingLabel
@onready var _environment_label: Label = %EnvironmentLabel
@onready var _cargo_heading_label: Label = %CargoHeadingLabel
@onready var _cargo_name_label: Label = %CargoNameLabel
@onready var _cargo_description_label: Label = %CargoDescriptionLabel
@onready var _required_heading_label: Label = %RequiredHeadingLabel
@onready var _required_modules_label: Label = %RequiredModulesLabel
@onready var _history_heading_label: Label = %HistoryHeadingLabel
@onready var _customer_history_label: Label = %CustomerHistoryLabel
@onready var _future_heading_label: Label = %FutureHeadingLabel
@onready var _future_order_label: Label = %FutureOrderLabel
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _accept_button: Button = %AcceptButton
@onready var _close_button: Button = %CloseButton

var game_state_override: GameStateModel
var _game_state: GameStateModel
var _controls_initialized: bool = false


func _ready() -> void:
	_initialize_controls()
	_bind_game_state()
	visible = false


func _exit_tree() -> void:
	_disconnect_game_state()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close_terminal()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_content()


func set_game_state_override(game_state: GameStateModel) -> void:
	game_state_override = game_state
	if is_inside_tree():
		_bind_game_state()
		_refresh_content()


func set_order_definition(order: OrderDefinition) -> void:
	order_definition = order
	if is_inside_tree():
		_refresh_content()


func open_terminal() -> bool:
	if not _initialize_controls():
		return false
	_bind_game_state()
	visible = true
	_refresh_content()
	_body_scroll.scroll_vertical = 0
	if _accept_button.disabled:
		_close_button.grab_focus()
	else:
		_accept_button.grab_focus()
	return true


func close_terminal() -> void:
	if not visible:
		return
	visible = false
	terminal_closed.emit()


func accept_current_order() -> bool:
	if _game_state == null or order_definition == null or _accept_button.disabled:
		return false
	if not _game_state.accept_order(order_definition):
		_refresh_content()
		return false
	_refresh_content()
	order_accepted.emit(order_definition.id)
	return true


func is_accept_enabled() -> bool:
	return _accept_button != null and not _accept_button.disabled


func get_status_text() -> String:
	if _status_badge_label == null:
		return ""
	return _status_badge_label.text


func get_feedback_text() -> String:
	if _feedback_label == null:
		return ""
	return _feedback_label.text


func get_environment_text() -> String:
	if _environment_label == null:
		return ""
	return _environment_label.text


func get_cargo_text() -> String:
	if _cargo_description_label == null:
		return ""
	return "%s\n%s" % [_cargo_name_label.text, _cargo_description_label.text]


func get_required_modules_text() -> String:
	if _required_modules_label == null:
		return ""
	return _required_modules_label.text


func get_customer_history_text() -> String:
	if _customer_history_label == null:
		return ""
	return _customer_history_label.text


func get_future_order_text() -> String:
	if _future_order_label == null:
		return ""
	return _future_order_label.text


func get_panel_rect() -> Rect2:
	var panel: PanelContainer = get_node_or_null("TerminalPanel") as PanelContainer
	if panel == null:
		return Rect2()
	return panel.get_global_rect()


func get_body_scroll_value() -> int:
	return 0 if _body_scroll == null else _body_scroll.scroll_vertical


func _initialize_controls() -> bool:
	if _controls_initialized:
		return true
	_terminal_title_label = get_node_or_null("%TerminalTitleLabel") as Label
	_status_badge_label = get_node_or_null("%StatusBadgeLabel") as Label
	_body_scroll = get_node_or_null("%BodyScroll") as ScrollContainer
	_order_name_label = get_node_or_null("%OrderNameLabel") as Label
	_parties_label = get_node_or_null("%PartiesLabel") as Label
	_route_label = get_node_or_null("%RouteLabel") as Label
	_reward_label = get_node_or_null("%RewardLabel") as Label
	_environment_heading_label = get_node_or_null("%EnvironmentHeadingLabel") as Label
	_environment_label = get_node_or_null("%EnvironmentLabel") as Label
	_cargo_heading_label = get_node_or_null("%CargoHeadingLabel") as Label
	_cargo_name_label = get_node_or_null("%CargoNameLabel") as Label
	_cargo_description_label = get_node_or_null("%CargoDescriptionLabel") as Label
	_required_heading_label = get_node_or_null("%RequiredHeadingLabel") as Label
	_required_modules_label = get_node_or_null("%RequiredModulesLabel") as Label
	_history_heading_label = get_node_or_null("%HistoryHeadingLabel") as Label
	_customer_history_label = get_node_or_null("%CustomerHistoryLabel") as Label
	_future_heading_label = get_node_or_null("%FutureHeadingLabel") as Label
	_future_order_label = get_node_or_null("%FutureOrderLabel") as Label
	_feedback_label = get_node_or_null("%FeedbackLabel") as Label
	_accept_button = get_node_or_null("%AcceptButton") as Button
	_close_button = get_node_or_null("%CloseButton") as Button
	if (
		_terminal_title_label == null
		or _status_badge_label == null
		or _body_scroll == null
		or _order_name_label == null
		or _parties_label == null
		or _route_label == null
		or _reward_label == null
		or _environment_heading_label == null
		or _environment_label == null
		or _cargo_heading_label == null
		or _cargo_name_label == null
		or _cargo_description_label == null
		or _required_heading_label == null
		or _required_modules_label == null
		or _history_heading_label == null
		or _customer_history_label == null
		or _future_heading_label == null
		or _future_order_label == null
		or _feedback_label == null
		or _accept_button == null
		or _close_button == null
	):
		return false
	_accept_button.pressed.connect(accept_current_order)
	_close_button.pressed.connect(close_terminal)
	_controls_initialized = true
	return true


func _bind_game_state() -> void:
	var next_game_state: GameStateModel = game_state_override
	if next_game_state == null:
		next_game_state = get_node_or_null("/root/GameState") as GameStateModel
	if _game_state == next_game_state:
		return
	_disconnect_game_state()
	_game_state = next_game_state
	if _game_state == null:
		return
	if not _game_state.order_status_changed.is_connected(_on_order_status_changed):
		_game_state.order_status_changed.connect(_on_order_status_changed)
	if not _game_state.runtime_state_reset.is_connected(_on_runtime_state_reset):
		_game_state.runtime_state_reset.connect(_on_runtime_state_reset)


func _disconnect_game_state() -> void:
	if _game_state == null:
		return
	if _game_state.order_status_changed.is_connected(_on_order_status_changed):
		_game_state.order_status_changed.disconnect(_on_order_status_changed)
	if _game_state.runtime_state_reset.is_connected(_on_runtime_state_reset):
		_game_state.runtime_state_reset.disconnect(_on_runtime_state_reset)
	_game_state = null


func _on_order_status_changed(order_id: StringName, _status: GameStateModel.OrderStatus) -> void:
	if order_definition != null and order_definition.id == order_id:
		_refresh_content()


func _on_runtime_state_reset() -> void:
	_refresh_content()


func _refresh_content() -> void:
	if not _controls_initialized:
		return
	_localize_static_labels()
	var unavailable_text: String = tr("UI_ORDER_VALUE_UNAVAILABLE")
	if order_definition == null:
		_order_name_label.text = unavailable_text
		_parties_label.text = unavailable_text
		_route_label.text = unavailable_text
		_reward_label.text = unavailable_text
		_environment_label.text = unavailable_text
		_cargo_name_label.text = unavailable_text
		_cargo_description_label.text = unavailable_text
		_required_modules_label.text = unavailable_text
		_customer_history_label.text = unavailable_text
		_apply_invalid_state(&"missing_data")
		return

	_order_name_label.text = _translate_key(order_definition.display_name_key, unavailable_text)
	_parties_label.text = tr("UI_ORDER_PARTIES_FORMAT") % [
		_translate_character(order_definition.sender, unavailable_text),
		_translate_character(order_definition.recipient, unavailable_text),
	]
	_route_label.text = tr("UI_ORDER_ROUTE_FORMAT") % [
		_translate_planet(order_definition.destination_planet, unavailable_text),
		order_definition.route_distance,
		order_definition.risk_level,
		_translate_delivery_type(order_definition.delivery_type),
	]
	_reward_label.text = tr("UI_ORDER_REWARD_FORMAT") % order_definition.credit_reward
	_environment_label.text = _translate_planet_description(
		order_definition.destination_planet,
		unavailable_text
	)
	_cargo_name_label.text = _translate_cargo_name(order_definition.cargo, unavailable_text)
	_cargo_description_label.text = _translate_cargo_description(
		order_definition.cargo,
		unavailable_text
	)
	_required_modules_label.text = _build_required_modules_text(
		order_definition.required_modules,
		unavailable_text
	)
	_customer_history_label.text = _build_customer_history_text(
		order_definition.customer_history_keys,
		unavailable_text
	)
	_refresh_order_state()


func _localize_static_labels() -> void:
	_terminal_title_label.text = tr("UI_ORDER_TERMINAL_TITLE")
	_environment_heading_label.text = tr("UI_ORDER_ENVIRONMENT_HEADING")
	_cargo_heading_label.text = tr("UI_ORDER_CARGO_HEADING")
	_required_heading_label.text = tr("UI_ORDER_REQUIRED_MODULES_HEADING")
	_history_heading_label.text = tr("UI_ORDER_CUSTOMER_HISTORY_HEADING")
	_future_heading_label.text = tr("UI_ORDER_FUTURE_HEADING")
	_future_order_label.text = tr("UI_ORDER_FUTURE_PLACEHOLDER")
	_close_button.text = tr("UI_ORDER_CLOSE")


func _refresh_order_state() -> void:
	if _game_state == null:
		_apply_invalid_state(&"state_unavailable")
		return
	var status: GameStateModel.OrderStatus = _game_state.get_order_status(order_definition.id)
	match status:
		GameStateModel.OrderStatus.AVAILABLE:
			_status_badge_label.text = tr("UI_ORDER_STATUS_NOT_ACCEPTED")
			_accept_button.text = tr("UI_ORDER_ACCEPT")
			var error_id: StringName = _game_state.get_order_acceptance_error(order_definition)
			if error_id.is_empty():
				_accept_button.disabled = false
				_feedback_label.text = tr("UI_ORDER_FEEDBACK_READY")
			else:
				_apply_invalid_state(error_id)
		GameStateModel.OrderStatus.ACCEPTED:
			_status_badge_label.text = tr("UI_ORDER_STATUS_ACCEPTED")
			_accept_button.text = tr("UI_ORDER_ACCEPTED_BUTTON")
			_accept_button.disabled = true
			_feedback_label.text = tr("UI_ORDER_FEEDBACK_ACCEPTED")
		GameStateModel.OrderStatus.COMPLETED:
			_status_badge_label.text = tr("UI_ORDER_STATUS_COMPLETED")
			_accept_button.text = tr("UI_ORDER_COMPLETED_BUTTON")
			_accept_button.disabled = true
			_feedback_label.text = tr("UI_ORDER_FEEDBACK_COMPLETED")
		GameStateModel.OrderStatus.FAILED, GameStateModel.OrderStatus.ABANDONED:
			_status_badge_label.text = tr("UI_ORDER_STATUS_UNAVAILABLE")
			_accept_button.text = tr("UI_ORDER_ACCEPT")
			_accept_button.disabled = true
			_feedback_label.text = tr("UI_ORDER_ERROR_STATE_UNAVAILABLE")
		GameStateModel.OrderStatus.ARCHIVED:
			_status_badge_label.text = tr("UI_ORDER_STATUS_UNAVAILABLE")
			_accept_button.text = tr("UI_ORDER_COMPLETED_BUTTON")
			_accept_button.disabled = true
			_feedback_label.text = tr("UI_ORDER_ERROR_STATE_UNAVAILABLE")


func _apply_invalid_state(error_id: StringName) -> void:
	_status_badge_label.text = tr("UI_ORDER_STATUS_UNAVAILABLE")
	_accept_button.text = tr("UI_ORDER_ACCEPT")
	_accept_button.disabled = true
	match error_id:
		GameStateModel.ORDER_ERROR_STORY_REQUIREMENT:
			_feedback_label.text = tr("UI_ORDER_ERROR_STORY_REQUIREMENT")
		GameStateModel.ORDER_ERROR_ACTIVE_ORDER:
			_feedback_label.text = tr("UI_ORDER_ERROR_ACTIVE_ORDER")
		&"state_unavailable":
			_feedback_label.text = tr("UI_ORDER_ERROR_STATE_UNAVAILABLE")
		_:
			_feedback_label.text = tr("UI_ORDER_ERROR_MISSING_DATA")


func _translate_key(key: StringName, fallback: String) -> String:
	if key.is_empty():
		return fallback
	return tr(String(key))


func _translate_character(character: CharacterDefinition, fallback: String) -> String:
	if character == null:
		return fallback
	return _translate_key(character.display_name_key, fallback)


func _translate_planet(planet: PlanetDefinition, fallback: String) -> String:
	if planet == null:
		return fallback
	return _translate_key(planet.display_name_key, fallback)


func _translate_planet_description(planet: PlanetDefinition, fallback: String) -> String:
	if planet == null:
		return fallback
	return _translate_key(planet.description_key, fallback)


func _translate_cargo_name(cargo: CargoDefinition, fallback: String) -> String:
	if cargo == null:
		return fallback
	return _translate_key(cargo.display_name_key, fallback)


func _translate_cargo_description(cargo: CargoDefinition, fallback: String) -> String:
	if cargo == null:
		return fallback
	return _translate_key(cargo.company_description_key, fallback)


func _translate_delivery_type(delivery_type: OrderDefinition.DeliveryType) -> String:
	match delivery_type:
		OrderDefinition.DeliveryType.LANDING:
			return tr("UI_ORDER_DELIVERY_LANDING")
		OrderDefinition.DeliveryType.LOW_ALTITUDE_DROP:
			return tr("UI_ORDER_DELIVERY_AIRDROP")
	return tr("UI_ORDER_VALUE_UNAVAILABLE")


func _build_required_modules_text(
	modules: Array[ShipModuleDefinition],
	fallback: String
) -> String:
	if modules.is_empty():
		return tr("UI_ORDER_NO_REQUIRED_MODULES")
	var entries: PackedStringArray = []
	for module: ShipModuleDefinition in modules:
		var module_name: String = fallback
		if module != null:
			module_name = _translate_key(module.display_name_key, fallback)
		entries.append(tr("UI_ORDER_LIST_ENTRY_FORMAT") % module_name)
	return "\n".join(entries)


func _build_customer_history_text(keys: Array[StringName], fallback: String) -> String:
	if keys.is_empty():
		return fallback
	var entries: PackedStringArray = []
	for key: StringName in keys:
		entries.append(tr("UI_ORDER_LIST_ENTRY_FORMAT") % _translate_key(key, fallback))
	return "\n".join(entries)
