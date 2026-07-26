class_name DialogueUI
extends Control

signal dialogue_started(sequence_id: StringName)
signal dialogue_finished
signal flow_event_emitted(event_id: StringName)

@export_range(1.0, 240.0, 1.0) var characters_per_second: float = 42.0

@onready var speaker_label: Label = %SpeakerLabel
@onready var express_pause_label: Label = %ExpressPauseLabel
@onready var body_label: RichTextLabel = %BodyLabel
@onready var choice_container: VBoxContainer = %ChoiceContainer
@onready var quick_show_button: Button = %QuickShowButton
@onready var skip_read_button: Button = %SkipReadButton
@onready var skip_sequence_button: Button = %SkipSequenceButton
@onready var history_button: Button = %HistoryButton
@onready var continue_button: Button = %ContinueButton
@onready var history_panel: PanelContainer = %HistoryPanel
@onready var history_text: RichTextLabel = %HistoryText
@onready var close_history_button: Button = %CloseHistoryButton

var _runtime: DialogueRuntime
var _full_text: String = ""
var _revealed_characters: float = 0.0
var _is_revealing: bool = false
var _history_lines: PackedStringArray = []
var _controls_initialized: bool = false
var _settings_service: SettingsServiceModel
var _pending_choice_buttons: Array[Button] = []


func _ready() -> void:
	add_to_group(ExpressOrderHUD.DIALOGUE_PAUSE_GROUP)
	_initialize_controls()
	_bind_settings_service()
	if _runtime == null:
		visible = false
	set_process(_is_revealing)


func _exit_tree() -> void:
	if _settings_service == null:
		return
	if _settings_service.settings_changed.is_connected(_apply_text_speed_setting):
		_settings_service.settings_changed.disconnect(_apply_text_speed_setting)


func _process(delta: float) -> void:
	if not _is_revealing:
		return
	_revealed_characters += characters_per_second * delta
	body_label.visible_characters = mini(int(_revealed_characters), _full_text.length())
	if body_label.visible_characters >= _full_text.length():
		_finish_reveal()


## Starts a sequence with an isolated runtime while writing approved effects to GameState.
func start_dialogue(sequence: DialogueSequence, game_state: GameStateModel) -> bool:
	if not _initialize_controls():
		return false
	_disconnect_runtime()
	_runtime = DialogueRuntime.new()
	_runtime.line_changed.connect(_on_line_changed)
	_runtime.dialogue_finished.connect(_on_runtime_finished)
	_runtime.flow_event_emitted.connect(_on_flow_event_emitted)
	_history_lines.clear()
	history_text.text = ""
	history_panel.visible = false
	visible = true
	if not _runtime.start(sequence, game_state):
		visible = false
		return false
	_refresh_express_pause_notice()
	dialogue_started.emit(sequence.id)
	return true


func continue_dialogue() -> bool:
	if _runtime == null:
		return false
	if _is_revealing:
		quick_show_current_line()
		return true
	return _runtime.advance()


## Closes the current dialogue without marking the visible line as read.
func cancel_dialogue() -> bool:
	if _runtime == null:
		return false
	return _runtime.cancel()


func select_choice(choice_id: StringName) -> bool:
	if _runtime == null or _is_revealing:
		return false
	return _runtime.select_choice(choice_id)


func quick_show_current_line() -> void:
	if _is_revealing:
		_finish_reveal()


func skip_read_lines() -> int:
	if _runtime == null or _is_revealing:
		return 0
	return _runtime.skip_read_lines()


## Skips linear content, applies its effects once, and reveals the nearest choice.
func skip_dialogue_sequence() -> DialogueRuntime.SequenceSkipResult:
	if _runtime == null:
		return DialogueRuntime.SequenceSkipResult.REJECTED
	if _is_revealing:
		quick_show_current_line()
	var result: DialogueRuntime.SequenceSkipResult = _runtime.skip_sequence()
	if (
		result == DialogueRuntime.SequenceSkipResult.STOPPED_AT_CHOICE
		or (result == DialogueRuntime.SequenceSkipResult.REJECTED and _runtime.is_running())
	):
		quick_show_current_line()
	_refresh_controls()
	return result


func show_history() -> void:
	if _history_lines.is_empty():
		history_text.text = tr("UI_DIALOGUE_HISTORY_EMPTY")
	else:
		history_text.text = "\n\n".join(_history_lines)
	history_panel.visible = true
	if close_history_button.is_inside_tree():
		close_history_button.grab_focus()


func hide_history() -> void:
	history_panel.visible = false
	if history_button.is_inside_tree():
		history_button.grab_focus()


func get_displayed_speaker() -> String:
	return speaker_label.text


func get_full_text() -> String:
	return _full_text


func get_body_content_height() -> float:
	return body_label.get_content_height()


func get_body_view_height() -> float:
	return body_label.size.y


func get_body_minimum_height() -> float:
	return body_label.custom_minimum_size.y


func body_font_has_glyph(codepoint: int) -> bool:
	var body_font: Font = body_label.get_theme_font(&"normal_font")
	return body_font != null and body_font.has_char(codepoint)


func is_express_pause_notice_visible() -> bool:
	return express_pause_label != null and express_pause_label.visible


func _on_line_changed(line: DialogueLine) -> void:
	var speaker_name: String = ""
	if line.speaker != null:
		speaker_name = tr(String(line.speaker.display_name_key))
	speaker_label.text = speaker_name
	_full_text = tr(String(line.text_key))
	body_label.text = _full_text
	body_label.visible_characters = 0
	_revealed_characters = 0.0
	_is_revealing = true
	_history_lines.append("%s：%s" % [speaker_name, _full_text])
	_clear_choice_buttons()
	_refresh_controls()
	set_process(true)


func _finish_reveal() -> void:
	body_label.visible_characters = -1
	_revealed_characters = float(_full_text.length())
	_is_revealing = false
	set_process(false)
	_build_choice_buttons()
	_refresh_controls()


func _build_choice_buttons() -> void:
	_clear_choice_buttons()
	if _runtime == null:
		return
	for choice: DialogueChoice in _runtime.get_available_choices():
		var button: Button = Button.new()
		button.text = tr(String(choice.text_key))
		button.custom_minimum_size = Vector2(0.0, 24.0)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_choice_pressed.bind(choice.id))
		choice_container.add_child(button)
	choice_container.visible = choice_container.get_child_count() > 0
	if choice_container.visible:
		var first_button: Button = choice_container.get_child(0) as Button
		if first_button != null and first_button.is_inside_tree():
			first_button.grab_focus()


func _clear_choice_buttons() -> void:
	if choice_container == null:
		return
	for child: Node in choice_container.get_children():
		choice_container.remove_child(child)
		_pending_choice_buttons.append(child as Button)
	choice_container.visible = false
	call_deferred("_flush_pending_choice_buttons")


func _flush_pending_choice_buttons() -> void:
	for button in _pending_choice_buttons:
		if is_instance_valid(button):
			button.call_deferred("queue_free")
	_pending_choice_buttons.clear()


func _refresh_controls() -> void:
	quick_show_button.disabled = not _is_revealing
	var has_choices: bool = false
	if _runtime != null and not _is_revealing:
		has_choices = (
			_runtime.current_line != null and not _runtime.current_line.choices.is_empty()
		)
	skip_read_button.disabled = (
		_is_revealing or _runtime == null or not _runtime.can_skip_current_line()
	)
	skip_sequence_button.disabled = _runtime == null or not _runtime.is_running()
	continue_button.disabled = _runtime == null or has_choices


func _on_choice_pressed(choice_id: StringName) -> void:
	select_choice(choice_id)


func _on_flow_event_emitted(event_id: StringName) -> void:
	flow_event_emitted.emit(event_id)


func _on_runtime_finished() -> void:
	_is_revealing = false
	set_process(false)
	visible = false
	history_panel.visible = false
	express_pause_label.visible = false
	dialogue_finished.emit()


func _disconnect_runtime() -> void:
	if _runtime == null:
		return
	if _runtime.line_changed.is_connected(_on_line_changed):
		_runtime.line_changed.disconnect(_on_line_changed)
	if _runtime.dialogue_finished.is_connected(_on_runtime_finished):
		_runtime.dialogue_finished.disconnect(_on_runtime_finished)
	if _runtime.flow_event_emitted.is_connected(_on_flow_event_emitted):
		_runtime.flow_event_emitted.disconnect(_on_flow_event_emitted)


func _initialize_controls() -> bool:
	if _controls_initialized:
		return true
	speaker_label = get_node_or_null("%SpeakerLabel") as Label
	express_pause_label = get_node_or_null("%ExpressPauseLabel") as Label
	body_label = get_node_or_null("%BodyLabel") as RichTextLabel
	choice_container = get_node_or_null("%ChoiceContainer") as VBoxContainer
	quick_show_button = get_node_or_null("%QuickShowButton") as Button
	skip_read_button = get_node_or_null("%SkipReadButton") as Button
	skip_sequence_button = get_node_or_null("%SkipSequenceButton") as Button
	history_button = get_node_or_null("%HistoryButton") as Button
	continue_button = get_node_or_null("%ContinueButton") as Button
	history_panel = get_node_or_null("%HistoryPanel") as PanelContainer
	history_text = get_node_or_null("%HistoryText") as RichTextLabel
	close_history_button = get_node_or_null("%CloseHistoryButton") as Button
	if (
		speaker_label == null
		or express_pause_label == null
		or body_label == null
		or choice_container == null
		or quick_show_button == null
		or skip_read_button == null
		or skip_sequence_button == null
		or history_button == null
		or continue_button == null
		or history_panel == null
		or history_text == null
		or close_history_button == null
	):
		return false
	quick_show_button.pressed.connect(quick_show_current_line)
	skip_read_button.pressed.connect(skip_read_lines)
	skip_sequence_button.pressed.connect(skip_dialogue_sequence)
	skip_sequence_button.text = tr("UI_DIALOGUE_SKIP_SEQUENCE")
	history_button.pressed.connect(show_history)
	continue_button.pressed.connect(continue_dialogue)
	close_history_button.pressed.connect(hide_history)
	history_panel.visible = false
	express_pause_label.visible = false
	_controls_initialized = true
	return true


func _refresh_express_pause_notice() -> void:
	if express_pause_label == null:
		return
	express_pause_label.text = tr("UI_EXPRESS_MODAL_PAUSED")
	express_pause_label.visible = false
	if not is_inside_tree():
		return
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	for candidate: Node in scene_tree.get_nodes_in_group(
		ExpressOrderHUD.DRIVER_GROUP
	):
		if not candidate is ExpressOrderHUD:
			continue
		var hud: ExpressOrderHUD = candidate as ExpressOrderHUD
		hud.refresh_from_state()
		if hud.has_active_express_order():
			express_pause_label.visible = true
			return


func _bind_settings_service() -> void:
	_settings_service = get_node_or_null("/root/SettingsService") as SettingsServiceModel
	if _settings_service == null:
		return
	if not _settings_service.settings_changed.is_connected(_apply_text_speed_setting):
		_settings_service.settings_changed.connect(_apply_text_speed_setting)
	_apply_text_speed_setting()


func _apply_text_speed_setting() -> void:
	if _settings_service != null:
		characters_per_second = _settings_service.settings.text_speed
