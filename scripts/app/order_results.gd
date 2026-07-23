class_name OrderResults
extends Control

signal settlement_committed(result: OrderSettlementResult)

@export var order: OrderDefinition

@onready var _title_label: Label = %TitleLabel
@onready var _base_reward_value: Label = %BaseRewardValue
@onready var _cargo_integrity_value: Label = %CargoIntegrityValue
@onready var _cargo_adjustment_value: Label = %CargoAdjustmentValue
@onready var _total_reward_value: Label = %TotalRewardValue
@onready var _credit_balance_value: Label = %CreditBalanceValue
@onready var _narrative_label: Label = %NarrativeLabel
@onready var _station_change_label: Label = %StationChangeLabel
@onready var _next_step_label: Label = %NextStepLabel
@onready var _return_button: Button = %ReturnButton

var game_state_override: GameStateModel
var scene_router_override: SceneRouterService

var _settlement_result: OrderSettlementResult
var _settlement_is_committed: bool = false


func _ready() -> void:
	if not _return_button.pressed.is_connected(_on_return_button_pressed):
		_return_button.pressed.connect(_on_return_button_pressed)
	present_settlement()
	if not _return_button.disabled:
		_return_button.call_deferred("grab_focus")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_render_settlement()


func present_settlement() -> bool:
	if _settlement_is_committed:
		_render_settlement()
		return true
	var game_state: GameStateModel = _resolve_game_state()
	if game_state == null or order == null:
		_render_unavailable()
		return false
	var run_state: OrderRunState = game_state.get_active_order_run_state()
	_settlement_result = OrderSettlementCalculator.calculate(order, run_state)
	if _settlement_result == null:
		_render_unavailable()
		return false
	var settlement_flags: Array[StringName] = [
		M0ProgressIds.STORY_FIRST_DELIVERY_SETTLED,
		M0ProgressIds.STORY_RETURN_DIALOGUE_PENDING,
	]
	_settlement_is_committed = game_state.settle_current_order(
		order,
		_settlement_result,
		M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY,
		settlement_flags
	)
	if not _settlement_is_committed:
		_render_unavailable()
		return false
	_render_settlement()
	settlement_committed.emit(_settlement_result)
	return true


func return_to_station() -> bool:
	if not _settlement_is_committed:
		return false
	var scene_router: SceneRouterService = _resolve_scene_router()
	if scene_router == null:
		return false
	_return_button.disabled = true
	if scene_router.request_stage(SceneRouterService.Stage.STATION):
		return true
	_return_button.disabled = false
	_station_change_label.text = tr("UI_RESULTS_RETURN_ERROR")
	return false


func is_settlement_committed() -> bool:
	return _settlement_is_committed


func get_settlement_result() -> OrderSettlementResult:
	return _settlement_result


func get_credit_balance_text() -> String:
	return "" if _credit_balance_value == null else _credit_balance_value.text


func get_station_change_text() -> String:
	return "" if _station_change_label == null else _station_change_label.text


func get_next_step_text() -> String:
	return "" if _next_step_label == null else _next_step_label.text


func get_return_button() -> Button:
	return _return_button


func _render_settlement() -> void:
	if not is_node_ready():
		return
	if not _settlement_is_committed or _settlement_result == null or order == null:
		_render_unavailable()
		return
	var game_state: GameStateModel = _resolve_game_state()
	_title_label.text = tr("UI_RESULTS_TITLE_FORMAT") % tr(String(order.display_name_key))
	_base_reward_value.text = tr("UI_RESULTS_CREDITS_FORMAT") % _settlement_result.base_reward
	_cargo_integrity_value.text = tr("UI_RESULTS_PERCENT_FORMAT") % roundi(
		_settlement_result.cargo_integrity
	)
	_cargo_adjustment_value.text = tr("UI_RESULTS_SIGNED_CREDITS_FORMAT") % (
		"%+d" % _settlement_result.cargo_adjustment
	)
	_total_reward_value.text = tr("UI_RESULTS_CREDITS_FORMAT") % _settlement_result.total_reward
	_credit_balance_value.text = tr("UI_RESULTS_CREDITS_FORMAT") % (
		game_state.get_credits() if game_state != null else _settlement_result.total_reward
	)
	_narrative_label.text = "\n".join([
		_get_entry_style_text(),
		_get_cargo_result_text(),
		_get_landing_result_text(),
	])
	_station_change_label.text = tr("UI_RESULTS_STATION_CHANGE_DETAIL")
	_next_step_label.text = tr("UI_RESULTS_NEXT_STEP")
	_return_button.disabled = false


func _render_unavailable() -> void:
	if not is_node_ready():
		return
	_title_label.text = tr("UI_STAGE_RESULTS")
	_base_reward_value.text = tr("UI_RESULTS_VALUE_UNAVAILABLE")
	_cargo_integrity_value.text = tr("UI_RESULTS_VALUE_UNAVAILABLE")
	_cargo_adjustment_value.text = tr("UI_RESULTS_VALUE_UNAVAILABLE")
	_total_reward_value.text = tr("UI_RESULTS_VALUE_UNAVAILABLE")
	_credit_balance_value.text = tr("UI_RESULTS_VALUE_UNAVAILABLE")
	_narrative_label.text = tr("UI_RESULTS_UNAVAILABLE")
	_station_change_label.text = tr("UI_RESULTS_UNAVAILABLE_DETAIL")
	_next_step_label.text = tr("UI_RESULTS_NEXT_STEP_UNAVAILABLE")
	_return_button.disabled = true


func _get_entry_style_text() -> String:
	match _settlement_result.entry_style:
		FlightStyleTracker.STYLE_DIVE:
			return tr("UI_RESULTS_NARRATIVE_STYLE_DIVE")
		FlightStyleTracker.STYLE_GLIDE:
			return tr("UI_RESULTS_NARRATIVE_STYLE_GLIDE")
		_:
			return tr("UI_RESULTS_NARRATIVE_STYLE_BALANCED")


func _get_cargo_result_text() -> String:
	if (
		_settlement_result.narrative_result
		== OrderSettlementCalculator.NARRATIVE_CARGO_SECURED
	):
		return tr("UI_RESULTS_NARRATIVE_CARGO_SECURED")
	return tr("UI_RESULTS_NARRATIVE_CARGO_RECOVERED")


func _get_landing_result_text() -> String:
	if _settlement_result.landing_result == OrderRunState.LANDING_RESULT_SMOOTH:
		return tr("UI_RESULTS_NARRATIVE_LANDING_SMOOTH")
	if _settlement_result.landing_result == OrderRunState.LANDING_RESULT_ROUGH:
		return tr("UI_RESULTS_NARRATIVE_LANDING_ROUGH")
	return tr("UI_RESULTS_NARRATIVE_LANDING_DELIVERED")


func _resolve_game_state() -> GameStateModel:
	if game_state_override != null:
		return game_state_override
	return get_node_or_null("/root/GameState") as GameStateModel


func _resolve_scene_router() -> SceneRouterService:
	if scene_router_override != null:
		return scene_router_override
	return get_node_or_null("/root/SceneRouter") as SceneRouterService


func _on_return_button_pressed() -> void:
	return_to_station()
