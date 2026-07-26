class_name OrderTerminalUI
extends Control

signal terminal_closed
signal order_accepted(order_id: StringName)

@export var data_registry: GameDataRegistry
## Optional focused fixture used by compatibility tests; normal scenes use data_registry.
@export var order_definition: OrderDefinition

@onready var _terminal_title_label: Label = %TerminalTitleLabel
@onready var _catalog_summary_label: Label = %CatalogSummaryLabel
@onready var _directory_heading_label: Label = %DirectoryHeadingLabel
@onready var _directory_panel: PanelContainer = %DirectoryPanel
@onready var _directory_scroll: ScrollContainer = %DirectoryScroll
@onready var _directory_list: VBoxContainer = %DirectoryList
@onready var _status_badge_label: Label = %StatusBadgeLabel
@onready var _type_label: Label = %TypeLabel
@onready var _body_scroll: ScrollContainer = %BodyScroll
@onready var _order_name_label: Label = %OrderNameLabel
@onready var _parties_label: Label = %PartiesLabel
@onready var _route_label: Label = %RouteLabel
@onready var _reward_label: Label = %RewardLabel
@onready var _relation_reward_label: Label = %RelationRewardLabel
@onready var _express_timing_label: Label = %ExpressTimingLabel
@onready var _required_heading_label: Label = %RequiredHeadingLabel
@onready var _required_modules_label: Label = %RequiredModulesLabel
@onready var _recommended_heading_label: Label = %RecommendedHeadingLabel
@onready var _recommended_modules_label: Label = %RecommendedModulesLabel
@onready var _environment_heading_label: Label = %EnvironmentHeadingLabel
@onready var _environment_label: Label = %EnvironmentLabel
@onready var _cargo_heading_label: Label = %CargoHeadingLabel
@onready var _cargo_name_label: Label = %CargoNameLabel
@onready var _cargo_description_label: Label = %CargoDescriptionLabel
@onready var _history_heading_label: Label = %HistoryHeadingLabel
@onready var _customer_history_label: Label = %CustomerHistoryLabel
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _accept_button: Button = %AcceptButton
@onready var _close_button: Button = %CloseButton

var game_state_override: GameStateModel
var _game_state: GameStateModel
var _controls_initialized: bool = false
var _entries: Array[M1OrderCatalogEntry] = []
var _selectable_entries: Array[M1OrderCatalogEntry] = []
var _entry_buttons: Dictionary[StringName, Button] = {}
var _selected_order_id: StringName = &""
var _history_count: int = 0


func _ready() -> void:
	_initialize_controls()
	_bind_game_state()
	visible = false


func _exit_tree() -> void:
	_disconnect_game_state()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close_terminal()
		get_viewport().set_input_as_handled()
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if event.is_action_pressed(&"ui_up") and _entry_buttons.values().has(focus_owner):
		_move_directory_focus(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_down") and _entry_buttons.values().has(focus_owner):
		_move_directory_focus(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right") and _entry_buttons.values().has(focus_owner):
		(_accept_button if not _accept_button.disabled else _close_button).grab_focus()
		get_viewport().set_input_as_handled()
	elif (
		event.is_action_pressed(&"ui_left")
		and focus_owner in [_accept_button, _close_button]
	):
		var selected_button: Button = _entry_buttons.get(_selected_order_id)
		if selected_button != null:
			selected_button.grab_focus()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_catalog()


func set_game_state_override(game_state: GameStateModel) -> void:
	game_state_override = game_state
	if is_inside_tree():
		_bind_game_state()
		_refresh_catalog()


func set_data_registry(registry: GameDataRegistry) -> void:
	data_registry = registry
	order_definition = null
	if is_inside_tree():
		_refresh_catalog()


func set_order_definition(order: OrderDefinition) -> void:
	order_definition = order
	if is_inside_tree():
		_refresh_catalog()


func open_terminal() -> bool:
	if not _initialize_controls():
		return false
	_bind_game_state()
	visible = true
	if _game_state != null and not _game_state.current_order_id.is_empty():
		_selected_order_id = _game_state.current_order_id
	_refresh_catalog()
	_body_scroll.scroll_vertical = 0
	_directory_scroll.scroll_vertical = 0
	var selected_button: Button = _entry_buttons.get(_selected_order_id)
	if selected_button != null:
		selected_button.grab_focus()
	else:
		_close_button.grab_focus()
	return true


func close_terminal() -> void:
	if not visible:
		return
	visible = false
	terminal_closed.emit()


func accept_current_order() -> bool:
	var entry: M1OrderCatalogEntry = _find_entry(_selected_order_id)
	if (
		_game_state == null
		or entry == null
		or entry.order == null
		or not entry.accept_enabled
	):
		return false
	if not _game_state.accept_order(entry.order):
		_refresh_catalog()
		return false
	var accepted_order_id: StringName = entry.order_id
	_selected_order_id = accepted_order_id
	_refresh_catalog()
	order_accepted.emit(accepted_order_id)
	return true


func select_order(order_id: StringName) -> bool:
	var entry: M1OrderCatalogEntry = _find_entry(order_id)
	if entry == null or not entry.is_selectable:
		return false
	_selected_order_id = order_id
	_refresh_detail(entry)
	return true


func focus_selected_order() -> bool:
	var button: Button = _entry_buttons.get(_selected_order_id)
	if button == null:
		return false
	button.grab_focus()
	return true


func is_accept_enabled() -> bool:
	return _accept_button != null and not _accept_button.disabled


func get_selected_order_id() -> StringName:
	return _selected_order_id


func get_directory_entry_count() -> int:
	return _entry_buttons.size()


func get_directory_entry_texts() -> PackedStringArray:
	var texts: PackedStringArray = []
	for entry: M1OrderCatalogEntry in _selectable_entries:
		var button: Button = _entry_buttons.get(entry.order_id)
		if button != null:
			texts.append(button.text)
	return texts


func get_directory_button(order_id: StringName) -> Button:
	return _entry_buttons.get(order_id)


func get_history_count() -> int:
	return _history_count


func get_status_text() -> String:
	return "" if _status_badge_label == null else _status_badge_label.text


func get_feedback_text() -> String:
	return "" if _feedback_label == null else _feedback_label.text


func get_order_name_text() -> String:
	return "" if _order_name_label == null else _order_name_label.text


func get_parties_text() -> String:
	return "" if _parties_label == null else _parties_label.text


func get_route_text() -> String:
	return "" if _route_label == null else _route_label.text


func get_reward_text() -> String:
	return "" if _reward_label == null else _reward_label.text


func get_environment_text() -> String:
	return "" if _environment_label == null else _environment_label.text


func get_cargo_text() -> String:
	if _cargo_description_label == null:
		return ""
	return "%s\n%s" % [_cargo_name_label.text, _cargo_description_label.text]


func get_required_modules_text() -> String:
	return "" if _required_modules_label == null else _required_modules_label.text


func get_recommended_modules_text() -> String:
	return (
		""
		if _recommended_modules_label == null
		else _recommended_modules_label.text
	)


func get_relation_reward_text() -> String:
	return "" if _relation_reward_label == null else _relation_reward_label.text


func get_express_timing_text() -> String:
	return "" if _express_timing_label == null else _express_timing_label.text


func is_express_timing_visible() -> bool:
	return _express_timing_label != null and _express_timing_label.visible


func get_customer_history_text() -> String:
	return "" if _customer_history_label == null else _customer_history_label.text


func get_accept_button_text() -> String:
	return "" if _accept_button == null else _accept_button.text


## Compatibility getter retained for the M0 smoke surface.
func get_future_order_text() -> String:
	return "" if _catalog_summary_label == null else _catalog_summary_label.text


func get_panel_rect() -> Rect2:
	var panel: PanelContainer = get_node_or_null("TerminalPanel") as PanelContainer
	return Rect2() if panel == null else panel.get_global_rect()


func get_directory_panel_rect() -> Rect2:
	return Rect2() if _directory_panel == null else _directory_panel.get_global_rect()


func get_detail_scroll_rect() -> Rect2:
	return Rect2() if _body_scroll == null else _body_scroll.get_global_rect()


func get_body_scroll_value() -> int:
	return 0 if _body_scroll == null else _body_scroll.scroll_vertical


func _initialize_controls() -> bool:
	if _controls_initialized:
		return true
	var required_controls: Array[Control] = [
		_terminal_title_label,
		_catalog_summary_label,
		_directory_heading_label,
		_directory_panel,
		_directory_scroll,
		_directory_list,
		_status_badge_label,
		_type_label,
		_body_scroll,
		_order_name_label,
		_parties_label,
		_route_label,
		_reward_label,
		_relation_reward_label,
		_express_timing_label,
		_required_heading_label,
		_required_modules_label,
		_recommended_heading_label,
		_recommended_modules_label,
		_environment_heading_label,
		_environment_label,
		_cargo_heading_label,
		_cargo_name_label,
		_cargo_description_label,
		_history_heading_label,
		_customer_history_label,
		_feedback_label,
		_accept_button,
		_close_button,
	]
	for control: Control in required_controls:
		if control == null:
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
	_game_state.order_status_changed.connect(_on_order_status_changed)
	_game_state.runtime_state_reset.connect(_on_state_refresh)
	_game_state.runtime_state_restored.connect(_on_state_refresh)
	_game_state.ship_configuration_changed.connect(_on_state_refresh)
	_game_state.departure_readiness_changed.connect(
		_on_departure_readiness_changed
	)


func _disconnect_game_state() -> void:
	if _game_state == null:
		return
	if _game_state.order_status_changed.is_connected(_on_order_status_changed):
		_game_state.order_status_changed.disconnect(_on_order_status_changed)
	if _game_state.runtime_state_reset.is_connected(_on_state_refresh):
		_game_state.runtime_state_reset.disconnect(_on_state_refresh)
	if _game_state.runtime_state_restored.is_connected(_on_state_refresh):
		_game_state.runtime_state_restored.disconnect(_on_state_refresh)
	if _game_state.ship_configuration_changed.is_connected(_on_state_refresh):
		_game_state.ship_configuration_changed.disconnect(_on_state_refresh)
	if (
		_game_state.departure_readiness_changed.is_connected(
			_on_departure_readiness_changed
		)
	):
		_game_state.departure_readiness_changed.disconnect(
			_on_departure_readiness_changed
		)
	_game_state = null


func _on_order_status_changed(
	_order_id: StringName,
	_status: GameStateModel.OrderStatus
) -> void:
	_refresh_catalog()


func _on_state_refresh() -> void:
	_refresh_catalog()


func _on_departure_readiness_changed(_confirmed: bool) -> void:
	_refresh_catalog()


func _refresh_catalog() -> void:
	if not _controls_initialized:
		return
	_localize_static_labels()
	_entries.clear()
	if _game_state != null:
		if order_definition != null:
			var focused_entry: M1OrderCatalogEntry = (
				M1CatalogModel.build_single_order_entry(
					order_definition,
					_game_state
				)
			)
			if focused_entry != null:
				_entries.append(focused_entry)
		elif data_registry != null:
			_entries = M1CatalogModel.get_visible_order_entries(
				data_registry,
				_game_state
			)
	_rebuild_directory()
	var selected_entry: M1OrderCatalogEntry = _find_entry(_selected_order_id)
	if selected_entry == null or not selected_entry.is_selectable:
		_selected_order_id = _choose_initial_order_id()
		selected_entry = _find_entry(_selected_order_id)
	_refresh_detail(selected_entry)


func _localize_static_labels() -> void:
	_terminal_title_label.text = tr("UI_ORDER_TERMINAL_TITLE")
	_directory_heading_label.text = tr("UI_ORDER_DIRECTORY_HEADING")
	_required_heading_label.text = tr("UI_ORDER_REQUIRED_MODULES_HEADING")
	_recommended_heading_label.text = tr(
		"UI_ORDER_RECOMMENDED_MODULES_HEADING"
	)
	_environment_heading_label.text = tr("UI_ORDER_ENVIRONMENT_HEADING")
	_cargo_heading_label.text = tr("UI_ORDER_CARGO_HEADING")
	_history_heading_label.text = tr("UI_ORDER_CUSTOMER_HISTORY_HEADING")
	_close_button.text = tr("UI_ORDER_CLOSE")


func _rebuild_directory() -> void:
	for child: Node in _directory_list.get_children():
		_directory_list.remove_child(child)
		child.queue_free()
	_selectable_entries.clear()
	_entry_buttons.clear()
	_history_count = 0
	for entry: M1OrderCatalogEntry in _entries:
		if entry.is_visible and entry.is_history():
			_history_count += 1
	var category_order: Array[M1OrderCatalogEntry.DisplayCategory] = [
		M1OrderCatalogEntry.DisplayCategory.CURRENT_ACCEPTED,
		M1OrderCatalogEntry.DisplayCategory.CURRENT_MAINLINE,
		M1OrderCatalogEntry.DisplayCategory.OPTIONAL,
		M1OrderCatalogEntry.DisplayCategory.NEXT_CLUE,
		M1OrderCatalogEntry.DisplayCategory.HISTORY,
	]
	for category: M1OrderCatalogEntry.DisplayCategory in category_order:
		var category_entries: Array[M1OrderCatalogEntry] = []
		for entry: M1OrderCatalogEntry in _entries:
			if entry.is_visible and entry.display_category == category:
				category_entries.append(entry)
		if category_entries.is_empty():
			continue
		_add_category_label(category)
		for entry: M1OrderCatalogEntry in category_entries:
			_add_entry_button(entry)
	_catalog_summary_label.text = tr("UI_ORDER_CATALOG_SUMMARY_FORMAT") % [
		_selectable_entries.size(),
		_history_count,
	]


func _add_category_label(
	category: M1OrderCatalogEntry.DisplayCategory
) -> void:
	var label: Label = Label.new()
	label.text = tr(String(_get_category_key(category)))
	label.add_theme_color_override("font_color", Color("77c9c4"))
	label.add_theme_font_size_override("font_size", 11)
	_directory_list.add_child(label)


func _add_entry_button(entry: M1OrderCatalogEntry) -> void:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 11)
	button.text = tr("UI_ORDER_DIRECTORY_ENTRY_FORMAT") % [
		_get_type_text(entry),
		_get_status_text(entry),
		_get_entry_name(entry),
	]
	button.set_meta("order_id", entry.order_id)
	button.pressed.connect(_on_entry_button_pressed.bind(entry.order_id))
	button.focus_entered.connect(
		_on_entry_button_focused.bind(entry.order_id)
	)
	_directory_list.add_child(button)
	_selectable_entries.append(entry)
	_entry_buttons[entry.order_id] = button


func _on_entry_button_pressed(order_id: StringName) -> void:
	select_order(order_id)


func _on_entry_button_focused(order_id: StringName) -> void:
	select_order(order_id)


func _move_directory_focus(offset: int) -> void:
	if _selectable_entries.is_empty():
		return
	var current_index: int = 0
	for index: int in _selectable_entries.size():
		if _selectable_entries[index].order_id == _selected_order_id:
			current_index = index
			break
	var next_index: int = clampi(
		current_index + offset,
		0,
		_selectable_entries.size() - 1
	)
	var next_entry: M1OrderCatalogEntry = _selectable_entries[next_index]
	select_order(next_entry.order_id)
	var next_button: Button = _entry_buttons.get(next_entry.order_id)
	if next_button != null:
		next_button.grab_focus()


func _choose_initial_order_id() -> StringName:
	for entry: M1OrderCatalogEntry in _selectable_entries:
		if (
			entry.display_category
			== M1OrderCatalogEntry.DisplayCategory.CURRENT_ACCEPTED
		):
			return entry.order_id
	if not _selectable_entries.is_empty():
		return _selectable_entries[0].order_id
	return &""


func _find_entry(order_id: StringName) -> M1OrderCatalogEntry:
	if order_id.is_empty():
		return null
	for entry: M1OrderCatalogEntry in _entries:
		if entry.order_id == order_id:
			return entry
	return null


func _refresh_detail(entry: M1OrderCatalogEntry) -> void:
	var unavailable: String = tr("UI_ORDER_VALUE_UNAVAILABLE")
	if entry == null or entry.order == null:
		_order_name_label.text = unavailable
		_status_badge_label.text = tr("UI_ORDER_STATUS_UNAVAILABLE")
		_type_label.text = ""
		_parties_label.text = unavailable
		_route_label.text = unavailable
		_reward_label.text = unavailable
		_relation_reward_label.text = unavailable
		_express_timing_label.text = ""
		_express_timing_label.visible = false
		_required_modules_label.text = unavailable
		_recommended_modules_label.text = unavailable
		_environment_label.text = unavailable
		_cargo_name_label.text = unavailable
		_cargo_description_label.text = unavailable
		_customer_history_label.text = unavailable
		_feedback_label.text = tr("UI_ORDER_FEEDBACK_SELECT")
		_accept_button.text = tr("UI_ORDER_ACCEPT")
		_accept_button.disabled = true
		return

	var order: OrderDefinition = entry.order
	_order_name_label.text = _get_entry_name(entry)
	_status_badge_label.text = _get_status_text(entry)
	_type_label.text = _get_type_text(entry)
	if entry.is_name_disclosed:
		_parties_label.text = tr("UI_ORDER_PARTIES_FORMAT") % [
			_translate_character(order.sender, unavailable),
			_translate_character(order.recipient, unavailable),
		]
		_route_label.text = tr("UI_ORDER_ROUTE_FORMAT") % [
			_translate_planet(order.destination_planet, unavailable),
			order.route_distance,
			order.risk_level,
			_translate_delivery_type(order.delivery_type),
		]
		_reward_label.text = tr("UI_ORDER_REWARD_FORMAT") % order.credit_reward
		_relation_reward_label.text = _build_relation_reward_text(order)
		_express_timing_label.visible = order.is_express
		_express_timing_label.text = (
			_build_express_timing_text(order)
			if order.is_express
			else ""
		)
		_required_modules_label.text = _build_module_text(
			order.required_modules,
			tr("UI_ORDER_NO_REQUIRED_MODULES")
		)
		_recommended_modules_label.text = _build_module_text(
			order.recommended_modules,
			tr("UI_ORDER_NO_RECOMMENDED_MODULES")
		)
		_environment_label.text = _translate_planet_description(
			order.destination_planet,
			unavailable
		)
		_cargo_name_label.text = _translate_cargo_name(order.cargo, unavailable)
		_cargo_description_label.text = _translate_cargo_description(
			order.cargo,
			unavailable
		)
		_customer_history_label.text = (
			_build_order_history_detail(entry, unavailable)
			if entry.is_history()
			else _build_customer_history_text(
				order.customer_history_keys,
				unavailable
			)
		)
	else:
		_parties_label.text = unavailable
		_route_label.text = unavailable
		_reward_label.text = unavailable
		_relation_reward_label.text = unavailable
		_express_timing_label.text = ""
		_express_timing_label.visible = false
		_required_modules_label.text = unavailable
		_recommended_modules_label.text = unavailable
		_environment_label.text = unavailable
		_cargo_name_label.text = unavailable
		_cargo_description_label.text = unavailable
		_customer_history_label.text = unavailable
	_accept_button.disabled = (
		entry.is_history() or not entry.accept_enabled
	)
	_accept_button.text = _get_accept_button_text(entry)
	if entry.status == GameStateModel.OrderStatus.ACCEPTED:
		_feedback_label.text = tr("UI_ORDER_FEEDBACK_ACCEPTED")
	elif entry.is_history():
		_feedback_label.text = tr("UI_ORDER_HISTORY_READ_ONLY")
	elif not entry.lock_hint_key.is_empty():
		_feedback_label.text = tr(String(entry.lock_hint_key))
	elif entry.accept_enabled:
		_feedback_label.text = tr("UI_ORDER_LOCK_READY")
	else:
		_feedback_label.text = tr("UI_CATALOG_HINT_DATA_UNAVAILABLE")
	_body_scroll.scroll_vertical = 0


func _build_express_timing_text(order: OrderDefinition) -> String:
	return tr("UI_ORDER_EXPRESS_TIMING_FORMAT") % [
		M1OrderRules.format_duration(order.target_seconds, true),
		M1OrderRules.format_duration(order.grace_seconds, true),
		roundi(order.minimum_reward_ratio * 100.0),
	]


func _get_entry_name(entry: M1OrderCatalogEntry) -> String:
	if entry == null or entry.order == null:
		return tr("UI_ORDER_VALUE_UNAVAILABLE")
	if not entry.is_name_disclosed:
		return tr("UI_ORDER_NEXT_CLUE_NAME")
	return _translate_key(
		entry.order.display_name_key,
		tr("UI_ORDER_VALUE_UNAVAILABLE")
	)


func _get_type_text(entry: M1OrderCatalogEntry) -> String:
	var key: StringName = &"UI_ORDER_TYPE_MAIN"
	match entry.order_type:
		OrderDefinition.OrderType.SIDE:
			key = &"UI_ORDER_TYPE_OPTIONAL"
		OrderDefinition.OrderType.REVISIT:
			key = &"UI_ORDER_TYPE_REVISIT"
	var parts: PackedStringArray = [tr(String(key))]
	if entry.is_express:
		parts.append(tr("UI_ORDER_TYPE_EXPRESS"))
	return " · ".join(parts)


func _get_status_text(entry: M1OrderCatalogEntry) -> String:
	match entry.status:
		GameStateModel.OrderStatus.ACCEPTED:
			return tr("UI_ORDER_STATUS_ACCEPTED")
		GameStateModel.OrderStatus.COMPLETED:
			return tr("UI_ORDER_STATUS_COMPLETED")
		GameStateModel.OrderStatus.ARCHIVED:
			return tr("UI_ORDER_STATUS_ARCHIVED")
	if entry.accept_enabled:
		return tr("UI_ORDER_STATUS_AVAILABLE")
	return tr("UI_ORDER_STATUS_LOCKED")


func _get_accept_button_text(entry: M1OrderCatalogEntry) -> String:
	match entry.status:
		GameStateModel.OrderStatus.ACCEPTED:
			return tr("UI_ORDER_ACCEPTED_BUTTON")
	if entry.status in [
		GameStateModel.OrderStatus.COMPLETED,
		GameStateModel.OrderStatus.ARCHIVED,
	]:
		return tr("UI_ORDER_HISTORY_READ_ONLY_BUTTON")
	return tr("UI_ORDER_ACCEPT")


func _get_category_key(
	category: M1OrderCatalogEntry.DisplayCategory
) -> StringName:
	match category:
		M1OrderCatalogEntry.DisplayCategory.CURRENT_ACCEPTED:
			return &"UI_ORDER_CATEGORY_CURRENT_ACCEPTED"
		M1OrderCatalogEntry.DisplayCategory.CURRENT_MAINLINE:
			return &"UI_ORDER_CATEGORY_CURRENT_MAINLINE"
		M1OrderCatalogEntry.DisplayCategory.OPTIONAL:
			return &"UI_ORDER_CATEGORY_OPTIONAL"
		M1OrderCatalogEntry.DisplayCategory.NEXT_CLUE:
			return &"UI_ORDER_CATEGORY_NEXT_CLUE"
		M1OrderCatalogEntry.DisplayCategory.HISTORY:
			return &"UI_ORDER_CATEGORY_HISTORY"
	return &"UI_ORDER_DIRECTORY_HEADING"


func _build_module_text(
	modules: Array[ShipModuleDefinition],
	empty_text: String
) -> String:
	if modules.is_empty():
		return empty_text
	var lines: PackedStringArray = []
	for module: ShipModuleDefinition in modules:
		if module == null:
			continue
		var state: M1CatalogModel.ModuleInstallState = (
			M1CatalogModel.get_module_install_state(module, _game_state)
		)
		lines.append(
			tr("UI_ORDER_MODULE_ENTRY_FORMAT") % [
				_translate_key(
					module.display_name_key,
					tr("UI_ORDER_VALUE_UNAVAILABLE")
				),
				tr(String(M1CatalogModel.get_module_state_key(state))),
			]
		)
	return empty_text if lines.is_empty() else "\n".join(lines)


func _build_relation_reward_text(order: OrderDefinition) -> String:
	if order.relation_rewards.is_empty():
		return tr("UI_ORDER_NO_RELATION_REWARD")
	var lines: PackedStringArray = []
	for planet_id: StringName in order.relation_rewards:
		var planet: PlanetDefinition = (
			data_registry.find_planet(planet_id)
			if data_registry != null
			else order.destination_planet
		)
		lines.append(
			tr("UI_ORDER_RELATION_REWARD_FORMAT") % [
				_translate_planet(planet, tr("UI_ORDER_VALUE_UNAVAILABLE")),
				int(order.relation_rewards.get(planet_id, 0)),
			]
		)
	return "\n".join(lines)


func _translate_key(key: StringName, fallback: String) -> String:
	return fallback if key.is_empty() else tr(String(key))


func _translate_character(
	character: CharacterDefinition,
	fallback: String
) -> String:
	return (
		fallback
		if character == null
		else _translate_key(character.display_name_key, fallback)
	)


func _translate_planet(planet: PlanetDefinition, fallback: String) -> String:
	return (
		fallback
		if planet == null
		else _translate_key(planet.display_name_key, fallback)
	)


func _translate_planet_description(
	planet: PlanetDefinition,
	fallback: String
) -> String:
	return (
		fallback
		if planet == null
		else _translate_key(planet.description_key, fallback)
	)


func _translate_cargo_name(cargo: CargoDefinition, fallback: String) -> String:
	return (
		fallback
		if cargo == null
		else _translate_key(cargo.display_name_key, fallback)
	)


func _translate_cargo_description(
	cargo: CargoDefinition,
	fallback: String
) -> String:
	return (
		fallback
		if cargo == null
		else _translate_key(cargo.company_description_key, fallback)
	)


func _translate_delivery_type(
	delivery_type: OrderDefinition.DeliveryType
) -> String:
	match delivery_type:
		OrderDefinition.DeliveryType.LANDING:
			return tr("UI_ORDER_DELIVERY_LANDING")
		OrderDefinition.DeliveryType.LOW_ALTITUDE_DROP:
			return tr("UI_ORDER_DELIVERY_AIRDROP")
	return tr("UI_ORDER_VALUE_UNAVAILABLE")


func _build_customer_history_text(
	keys: Array[StringName],
	fallback: String
) -> String:
	if keys.is_empty():
		return fallback
	var entries: PackedStringArray = []
	for key: StringName in keys:
		entries.append(
			tr("UI_ORDER_LIST_ENTRY_FORMAT") % _translate_key(key, fallback)
		)
	return "\n".join(entries)


func _build_order_history_detail(
	entry: M1OrderCatalogEntry,
	fallback: String
) -> String:
	if entry == null or entry.order == null:
		return fallback
	var lines: PackedStringArray = []
	var customer_history: String = _build_customer_history_text(
		entry.order.customer_history_keys,
		""
	)
	if not customer_history.is_empty():
		lines.append(customer_history)
	var result_key: StringName = &""
	if entry.order_id == M1CatalogModel.M0_ORDER_ID:
		result_key = &"UI_ORDER_HISTORY_RESULT_M0"
	elif entry.order_id == M1CatalogModel.RED_SAND_REVISIT_ORDER_ID:
		if (
			_game_state != null
			and _game_state.has_story_flag(
				&"story_m1_red_sand_retrofit_records_kept_local"
			)
		):
			result_key = &"UI_ORDER_HISTORY_RESULT_REVISIT_LOCAL"
		elif (
			_game_state != null
			and _game_state.has_story_flag(
				&"story_m1_red_sand_retrofit_records_uploaded_full"
			)
		):
			result_key = &"UI_ORDER_HISTORY_RESULT_REVISIT_UPLOADED"
		else:
			result_key = &"UI_ORDER_HISTORY_RESULT_REVISIT"
	if not result_key.is_empty():
		lines.append(
			tr("UI_ORDER_HISTORY_RESULT_FORMAT") % tr(String(result_key))
		)
	lines.append(tr("UI_ORDER_HISTORY_SETTLEMENT_NOT_RETAINED"))
	return fallback if lines.is_empty() else "\n".join(lines)
