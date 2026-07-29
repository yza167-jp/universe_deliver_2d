class_name StationDepartureController
extends Node

signal departure_gate_opened
signal departure_gate_closed
signal cockpit_entered

enum FlowState {
	WAIT_FOR_TUTORIAL,
	WAIT_FOR_ORDER,
	WAIT_FOR_LOADOUT,
	READY_FOR_COCKPIT,
	FIRST_DELIVERY_COMPLETE,
}

const COCKPIT_LABEL_DEFAULT_COLOR: Color = Color("e7a85b")
const COCKPIT_LABEL_READY_COLOR: Color = Color("77c9c4")
const MODAL_DEPARTURE_GATE: StringName = &"station_departure_gate"

var _game_state: GameStateModel
var _data_registry: GameDataRegistry
var _scene_router: SceneRouterService
var _tutorial_controller: StationTutorialController
var _player: StationPlayer
var _modal_coordinator: StationModalCoordinator
var _cockpit_entry: Interactable2D
var _cockpit_entry_label: Label
var _objective_root: Control
var _objective_label: Label
var _departure_panel: Control
var _departure_title_label: Label
var _departure_summary_label: Label
var _departure_body_label: Label
var _close_button: Button
var _enter_cockpit_button: Button
var _feedback_timer: Timer


func _ready() -> void:
	call_deferred("_initialize_controller")


func _unhandled_input(event: InputEvent) -> void:
	if (
		_departure_panel != null
		and _departure_panel.visible
		and event.is_action_pressed(&"ui_cancel")
	):
		close_departure_gate()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_localize_departure_panel()
		_refresh_route_guidance()


func get_flow_state() -> FlowState:
	if _tutorial_controller == null or not _tutorial_controller.is_tutorial_complete():
		return FlowState.WAIT_FOR_TUTORIAL
	if _game_state == null:
		return FlowState.WAIT_FOR_ORDER
	if _game_state.current_order_id.is_empty():
		if _is_red_sand_revisit_available():
			return FlowState.WAIT_FOR_ORDER
		if _game_state.has_story_flag(M0ProgressIds.STORY_FIRST_DELIVERY_SETTLED):
			return FlowState.FIRST_DELIVERY_COMPLETE
		return FlowState.WAIT_FOR_ORDER
	if not _game_state.departure_confirmed:
		return FlowState.WAIT_FOR_LOADOUT
	return FlowState.READY_FOR_COCKPIT


func get_objective_text() -> String:
	return "" if _objective_label == null else _objective_label.text


func is_departure_gate_visible() -> bool:
	return _departure_panel != null and _departure_panel.visible


func get_departure_gate_text() -> String:
	if _departure_title_label == null:
		return ""
	return "\n".join(PackedStringArray([
		_departure_title_label.text,
		_departure_summary_label.text,
		_departure_body_label.text,
	]))


func close_departure_gate() -> void:
	if _departure_panel == null or not _departure_panel.visible:
		return
	_departure_panel.visible = false
	if _modal_coordinator != null:
		_modal_coordinator.end_modal(MODAL_DEPARTURE_GATE)
	departure_gate_closed.emit()


func enter_cockpit() -> bool:
	if (
		_scene_router == null
		or _departure_panel == null
		or not _departure_panel.visible
		or get_flow_state() != FlowState.READY_FOR_COCKPIT
	):
		return false
	_departure_panel.visible = false
	_modal_coordinator.end_modal(MODAL_DEPARTURE_GATE)
	if _scene_router.request_stage(SceneRouterService.Stage.COCKPIT):
		cockpit_entered.emit()
		return true
	_modal_coordinator.begin_modal(MODAL_DEPARTURE_GATE)
	_departure_panel.visible = true
	_enter_cockpit_button.grab_focus()
	return false


func _initialize_controller() -> void:
	_game_state = get_node_or_null("/root/GameState") as GameStateModel
	var order_terminal_ui: OrderTerminalUI = get_node_or_null(
		"../OrderTerminalUILayer/OrderTerminalUI"
	) as OrderTerminalUI
	_data_registry = (
		order_terminal_ui.data_registry
		if order_terminal_ui != null
		else null
	)
	_scene_router = get_node_or_null("/root/SceneRouter") as SceneRouterService
	_tutorial_controller = get_node_or_null(
		"../StationTutorialController"
	) as StationTutorialController
	_player = get_node_or_null("../StationPlayer") as StationPlayer
	_modal_coordinator = get_node_or_null("../StationModalCoordinator") as StationModalCoordinator
	_cockpit_entry = get_node_or_null(
		"../Interactables/CockpitEntry"
	) as Interactable2D
	_cockpit_entry_label = get_node_or_null(
		"../FeatureLabels/CockpitEntryLabel"
	) as Label
	_objective_root = get_node_or_null(
		"../TutorialUILayer/TutorialObjective"
	) as Control
	_objective_label = get_node_or_null(
		"../TutorialUILayer/TutorialObjective/Panel/TutorialObjectiveLabel"
	) as Label
	_departure_panel = get_node_or_null(
		"../DepartureUILayer/DepartureReadyPanel"
	) as Control
	_departure_title_label = get_node_or_null(
		"../DepartureUILayer/DepartureReadyPanel/Panel/Margin/Content/TitleLabel"
	) as Label
	_departure_summary_label = get_node_or_null(
		"../DepartureUILayer/DepartureReadyPanel/Panel/Margin/Content/SummaryLabel"
	) as Label
	_departure_body_label = get_node_or_null(
		"../DepartureUILayer/DepartureReadyPanel/Panel/Margin/Content/BodyLabel"
	) as Label
	_close_button = get_node_or_null(
		"../DepartureUILayer/DepartureReadyPanel/Panel/Margin/Content/ButtonRow/CloseButton"
	) as Button
	_enter_cockpit_button = get_node_or_null(
		"../DepartureUILayer/DepartureReadyPanel/Panel/Margin/Content/ButtonRow/EnterCockpitButton"
	) as Button
	_feedback_timer = get_node_or_null("FeedbackTimer") as Timer
	if (
		_game_state == null
		or _data_registry == null
		or _scene_router == null
		or _tutorial_controller == null
		or _player == null
		or _modal_coordinator == null
		or _cockpit_entry == null
		or _cockpit_entry_label == null
		or _objective_root == null
		or _objective_label == null
		or _departure_panel == null
		or _departure_title_label == null
		or _departure_summary_label == null
		or _departure_body_label == null
		or _close_button == null
		or _enter_cockpit_button == null
		or _feedback_timer == null
	):
		push_error("Station departure flow could not resolve its state, guidance, or UI nodes.")
		return
	_connect_runtime_signals()
	_departure_panel.visible = false
	_localize_departure_panel()
	_refresh_route_guidance()


func _connect_runtime_signals() -> void:
	if not _tutorial_controller.tutorial_stage_changed.is_connected(
		_on_tutorial_stage_changed
	):
		_tutorial_controller.tutorial_stage_changed.connect(_on_tutorial_stage_changed)
	if not _game_state.runtime_state_reset.is_connected(_on_runtime_state_reset):
		_game_state.runtime_state_reset.connect(_on_runtime_state_reset)
	if not _game_state.order_status_changed.is_connected(_on_order_status_changed):
		_game_state.order_status_changed.connect(_on_order_status_changed)
	if not _game_state.ship_configuration_changed.is_connected(
		_on_ship_configuration_changed
	):
		_game_state.ship_configuration_changed.connect(_on_ship_configuration_changed)
	if not _game_state.departure_readiness_changed.is_connected(
		_on_departure_readiness_changed
	):
		_game_state.departure_readiness_changed.connect(_on_departure_readiness_changed)
	if not _cockpit_entry.interaction_triggered.is_connected(_on_cockpit_entry_interacted):
		_cockpit_entry.interaction_triggered.connect(_on_cockpit_entry_interacted)
	if not _close_button.pressed.is_connected(close_departure_gate):
		_close_button.pressed.connect(close_departure_gate)
	if not _enter_cockpit_button.pressed.is_connected(_on_enter_cockpit_pressed):
		_enter_cockpit_button.pressed.connect(_on_enter_cockpit_pressed)
	if not _feedback_timer.timeout.is_connected(_refresh_route_guidance):
		_feedback_timer.timeout.connect(_refresh_route_guidance)


func _on_tutorial_stage_changed(_stage: StationTutorialController.Stage) -> void:
	_refresh_route_guidance()


func _on_runtime_state_reset() -> void:
	close_departure_gate()
	_localize_departure_panel()
	_refresh_route_guidance()


func _on_order_status_changed(
	_order_id: StringName,
	_status: GameStateModel.OrderStatus
) -> void:
	_localize_departure_panel()
	_refresh_route_guidance()


func _on_ship_configuration_changed() -> void:
	_refresh_route_guidance()


func _on_departure_readiness_changed(_confirmed: bool) -> void:
	_refresh_route_guidance()


func _on_cockpit_entry_interacted(_actor: Node) -> void:
	match get_flow_state():
		FlowState.WAIT_FOR_TUTORIAL:
			return
		FlowState.WAIT_FOR_ORDER:
			_show_temporary_objective("UI_STATION_COCKPIT_BLOCKED_ORDER")
		FlowState.WAIT_FOR_LOADOUT:
			_show_temporary_objective("UI_STATION_COCKPIT_BLOCKED_LOADOUT")
		FlowState.READY_FOR_COCKPIT:
			_open_departure_gate()
		FlowState.FIRST_DELIVERY_COMPLETE:
			_show_temporary_objective("UI_STATION_OBJECTIVE_FIRST_DELIVERY_COMPLETE")


func _open_departure_gate() -> void:
	if _departure_panel == null or _departure_panel.visible:
		return
	_localize_departure_panel()
	_modal_coordinator.begin_modal(MODAL_DEPARTURE_GATE)
	_departure_panel.visible = true
	_enter_cockpit_button.grab_focus()
	departure_gate_opened.emit()


func _on_enter_cockpit_pressed() -> void:
	if not enter_cockpit():
		push_warning("Station departure flow could not enter the cockpit: %s" % _scene_router.last_error)


func _show_temporary_objective(localization_key: String) -> void:
	if _objective_root == null or _objective_label == null or _feedback_timer == null:
		return
	_objective_root.visible = true
	_objective_label.text = tr(localization_key)
	_feedback_timer.start()


func _refresh_route_guidance() -> void:
	if (
		_game_state == null
		or _tutorial_controller == null
		or _objective_root == null
		or _objective_label == null
		or _cockpit_entry == null
		or _cockpit_entry_label == null
	):
		return
	if not _tutorial_controller.is_tutorial_complete():
		_cockpit_entry.prompt_key = &"UI_INTERACTION_COCKPIT_ENTRY"
		_cockpit_entry_label.text = tr("UI_STATION_COCKPIT_ENTRY")
		_cockpit_entry_label.add_theme_color_override(
			"font_color",
			COCKPIT_LABEL_DEFAULT_COLOR
		)
		return

	var objective_key: String = ""
	var prompt_key: StringName = &"UI_INTERACTION_COCKPIT_ENTRY"
	var cockpit_label_key: String = "UI_STATION_COCKPIT_ENTRY"
	var cockpit_label_color: Color = COCKPIT_LABEL_DEFAULT_COLOR
	match get_flow_state():
		FlowState.WAIT_FOR_ORDER:
			objective_key = (
				"UI_STATION_OBJECTIVE_ACCEPT_RED_SAND_REVISIT"
				if _is_red_sand_revisit_available()
				else "UI_STATION_OBJECTIVE_ACCEPT_ORDER"
			)
			prompt_key = &"UI_INTERACTION_COCKPIT_ENTRY_LOCKED_ORDER"
		FlowState.WAIT_FOR_LOADOUT:
			objective_key = "UI_STATION_OBJECTIVE_CONFIGURE_SHIP"
			prompt_key = &"UI_INTERACTION_COCKPIT_ENTRY_LOCKED_LOADOUT"
		FlowState.READY_FOR_COCKPIT:
			objective_key = "UI_STATION_OBJECTIVE_ENTER_COCKPIT"
			prompt_key = &"UI_INTERACTION_COCKPIT_ENTRY_READY"
			cockpit_label_key = "UI_STATION_COCKPIT_ENTRY_READY"
			cockpit_label_color = COCKPIT_LABEL_READY_COLOR
		FlowState.FIRST_DELIVERY_COMPLETE:
			objective_key = "UI_STATION_OBJECTIVE_FIRST_DELIVERY_COMPLETE"
			prompt_key = &"UI_INTERACTION_COCKPIT_ENTRY_ORDER_COMPLETE"
		_:
			return
	_objective_root.visible = true
	_objective_label.text = tr(objective_key)
	_cockpit_entry.prompt_key = prompt_key
	_cockpit_entry_label.text = tr(cockpit_label_key)
	_cockpit_entry_label.add_theme_color_override("font_color", cockpit_label_color)


func _is_red_sand_revisit_available() -> bool:
	return (
		_game_state != null
		and _game_state.main_story_chapter
		== M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
		and _game_state.has_completed_order(
			GameProgressData.LEGACY_RED_SAND_ORDER_ID
		)
		and _game_state.has_story_flag(
			GameProgressData.RED_SAND_ORDER_COMPLETION_FLAG
		)
		and not _game_state.has_completed_order(
			M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT
		)
	)


func _localize_departure_panel() -> void:
	if _departure_title_label == null:
		return
	var active_order: OrderDefinition = _resolve_active_order()
	_departure_title_label.text = tr("UI_DEPARTURE_GATE_TITLE")
	if (
		active_order != null
		and active_order.destination_planet != null
		and active_order.cargo != null
	):
		var planet_name: String = tr(
			String(active_order.destination_planet.display_name_key)
		)
		var cargo_name: String = tr(String(active_order.cargo.display_name_key))
		_departure_summary_label.text = tr(
			"UI_DEPARTURE_GATE_DYNAMIC_SUMMARY"
		) % [planet_name, cargo_name]
		_departure_body_label.text = tr(
			"UI_DEPARTURE_GATE_DYNAMIC_BODY"
		) % [cargo_name, planet_name]
	else:
		_departure_summary_label.text = tr("UI_DEPARTURE_GATE_SUMMARY")
		_departure_body_label.text = tr("UI_DEPARTURE_GATE_BODY")
	_close_button.text = tr("UI_DEPARTURE_GATE_CLOSE")
	_enter_cockpit_button.text = tr("UI_DEPARTURE_GATE_ENTER_COCKPIT")


func _resolve_active_order() -> OrderDefinition:
	if (
		_game_state == null
		or _data_registry == null
		or _game_state.current_order_id.is_empty()
	):
		return null
	return _data_registry.find_order(_game_state.current_order_id)
