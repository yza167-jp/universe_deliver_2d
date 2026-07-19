class_name RedSandArrival
extends Control

@onready var _landing_feedback_label: Label = %LandingFeedbackLabel

var game_state_override: GameStateModel


func _ready() -> void:
	refresh_landing_feedback()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh_landing_feedback()


func refresh_landing_feedback() -> void:
	if _landing_feedback_label == null:
		return
	var game_state: GameStateModel = game_state_override
	if game_state == null:
		game_state = get_node_or_null("/root/GameState") as GameStateModel
	var run_state: OrderRunState = (
		game_state.get_active_order_run_state()
		if game_state != null
		else null
	)
	if run_state == null or run_state.landing_result.is_empty():
		_landing_feedback_label.visible = false
		_landing_feedback_label.text = ""
		return
	var feedback_key: StringName = &""
	match run_state.landing_result:
		OrderRunState.LANDING_RESULT_SMOOTH:
			feedback_key = &"UI_RED_SAND_ARRIVAL_LANDING_SMOOTH"
		OrderRunState.LANDING_RESULT_ROUGH:
			feedback_key = &"UI_RED_SAND_ARRIVAL_LANDING_ROUGH"
		_:
			_landing_feedback_label.visible = false
			_landing_feedback_label.text = ""
			return
	_landing_feedback_label.text = tr(feedback_key) % roundi(run_state.cargo_integrity)
	_landing_feedback_label.visible = true


func get_landing_feedback_text() -> String:
	return "" if _landing_feedback_label == null else _landing_feedback_label.text
