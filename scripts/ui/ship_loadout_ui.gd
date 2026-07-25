class_name ShipLoadoutUI
extends Control

signal loadout_closed
signal departure_confirmed(order_id: StringName)

@export var order_definition: OrderDefinition

@onready var _title_label: Label = %TitleLabel
@onready var _ship_name_label: Label = %ShipNameLabel
@onready var _ship_subtitle_label: Label = %ShipSubtitleLabel
@onready var _status_badge_label: Label = %StatusBadgeLabel
@onready var _cargo_assignment_label: Label = %CargoAssignmentLabel
@onready var _hull_heading_label: Label = %HullHeadingLabel
@onready var _hull_value_label: Label = %HullValueLabel
@onready var _shield_heading_label: Label = %ShieldHeadingLabel
@onready var _shield_value_label: Label = %ShieldValueLabel
@onready var _fuel_heading_label: Label = %FuelHeadingLabel
@onready var _fuel_value_label: Label = %FuelValueLabel
@onready var _boost_heading_label: Label = %BoostHeadingLabel
@onready var _boost_value_label: Label = %BoostValueLabel
@onready var _cargo_heading_label: Label = %CargoHeadingLabel
@onready var _cargo_value_label: Label = %CargoValueLabel
@onready var _slots_heading_label: Label = %SlotsHeadingLabel
@onready var _power_heading_label: Label = %PowerHeadingLabel
@onready var _power_name_label: Label = %PowerNameLabel
@onready var _power_description_label: Label = %PowerDescriptionLabel
@onready var _power_status_label: Label = %PowerStatusLabel
@onready var _power_toggle_button: Button = %PowerToggleButton
@onready var _defense_heading_label: Label = %DefenseHeadingLabel
@onready var _defense_name_label: Label = %DefenseNameLabel
@onready var _defense_description_label: Label = %DefenseDescriptionLabel
@onready var _defense_status_label: Label = %DefenseStatusLabel
@onready var _defense_toggle_button: Button = %DefenseToggleButton
@onready var _utility_heading_label: Label = %UtilityHeadingLabel
@onready var _utility_name_label: Label = %UtilityNameLabel
@onready var _utility_description_label: Label = %UtilityDescriptionLabel
@onready var _utility_status_label: Label = %UtilityStatusLabel
@onready var _utility_toggle_button: Button = %UtilityToggleButton
@onready var _backup_power_heading_label: Label = %BackupPowerHeadingLabel
@onready var _backup_power_name_label: Label = %BackupPowerNameLabel
@onready var _backup_power_description_label: Label = %BackupPowerDescriptionLabel
@onready var _backup_power_status_label: Label = %BackupPowerStatusLabel
@onready var _backup_power_toggle_button: Button = %BackupPowerToggleButton
@onready var _requirements_heading_label: Label = %RequirementsHeadingLabel
@onready var _requirements_label: Label = %RequirementsLabel
@onready var _standard_issue_label: Label = %StandardIssueLabel
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _close_button: Button = %CloseButton
@onready var _laser_mount_visual: ColorRect = %LaserMountVisual
@onready var _shield_backup_power_visual: ColorRect = %ShieldBackupPowerVisual
@onready var _high_voltage_shielding_visual: Line2D = (
	%HighVoltageShieldingVisual
)

var game_state_override: GameStateModel
var _game_state: GameStateModel
var _controls_initialized: bool = false


func _ready() -> void:
	_initialize_controls()
	_bind_game_state()
	_refresh_content()
	visible = false


func _exit_tree() -> void:
	_disconnect_game_state()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close_loadout()
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


func open_loadout() -> bool:
	if not _initialize_controls():
		return false
	_bind_game_state()
	visible = true
	_refresh_content()
	if not _confirm_button.disabled:
		_confirm_button.grab_focus()
	elif not _utility_toggle_button.disabled:
		_utility_toggle_button.grab_focus()
	else:
		_close_button.grab_focus()
	return true


func close_loadout() -> void:
	if not visible:
		return
	visible = false
	loadout_closed.emit()


func toggle_module_for_slot(slot_type: ShipModuleDefinition.SlotType) -> bool:
	if _game_state == null:
		return false
	var module: ShipModuleDefinition = ShipLoadoutRules.get_module_for_slot(
		order_definition,
		slot_type
	)
	if module == null:
		return false
	var changed: bool = false
	if _game_state.is_ship_module_equipped(module.id):
		changed = _game_state.unequip_ship_module(module)
	else:
		changed = _game_state.equip_ship_module(module)
	_refresh_content()
	return changed


func toggle_module_by_id(module_id: StringName) -> bool:
	if _game_state == null:
		return false
	var module: ShipModuleDefinition = ShipLoadoutRules.get_module_by_id(
		order_definition,
		module_id
	)
	if module == null:
		return false
	var changed: bool = false
	if _game_state.is_ship_module_equipped(module.id):
		changed = _game_state.unequip_ship_module(module)
	else:
		changed = _game_state.equip_ship_module(module)
	_refresh_content()
	return changed


func confirm_departure() -> bool:
	if _game_state == null or order_definition == null or _confirm_button.disabled:
		return false
	if not _game_state.confirm_departure(order_definition):
		_refresh_content()
		return false
	_refresh_content()
	departure_confirmed.emit(order_definition.id)
	return true


func is_confirm_enabled() -> bool:
	return _confirm_button != null and not _confirm_button.disabled


func get_status_text() -> String:
	return "" if _status_badge_label == null else _status_badge_label.text


func get_order_definition_id() -> StringName:
	return &"" if order_definition == null else order_definition.id


func get_feedback_text() -> String:
	return "" if _feedback_label == null else _feedback_label.text


func get_requirements_text() -> String:
	return "" if _requirements_label == null else _requirements_label.text


func get_cargo_assignment_text() -> String:
	return "" if _cargo_assignment_label == null else _cargo_assignment_label.text


func get_stat_summary_text() -> String:
	if _hull_value_label == null:
		return ""
	return "\n".join(PackedStringArray([
		_hull_value_label.text,
		_shield_value_label.text,
		_fuel_value_label.text,
		_boost_value_label.text,
		_cargo_value_label.text,
	]))


func get_slot_status_text(slot_type: ShipModuleDefinition.SlotType) -> String:
	match slot_type:
		ShipModuleDefinition.SlotType.POWER:
			return _power_status_label.text
		ShipModuleDefinition.SlotType.DEFENSE:
			return _defense_status_label.text
		ShipModuleDefinition.SlotType.UTILITY:
			return _utility_status_label.text
	return ""


func is_laser_mount_visible() -> bool:
	return _laser_mount_visual != null and _laser_mount_visual.visible


func is_shield_backup_power_visual_visible() -> bool:
	return (
		_shield_backup_power_visual != null
		and _shield_backup_power_visual.visible
	)


func is_high_voltage_shielding_visual_visible() -> bool:
	return (
		_high_voltage_shielding_visual != null
		and _high_voltage_shielding_visual.visible
	)


func get_shield_backup_power_status_text() -> String:
	return (
		""
		if _backup_power_status_label == null
		else _backup_power_status_label.text
	)


func get_panel_rect() -> Rect2:
	var panel: PanelContainer = get_node_or_null("LoadoutPanel") as PanelContainer
	return Rect2() if panel == null else panel.get_global_rect()


func _initialize_controls() -> bool:
	if _controls_initialized:
		return true
	var required_controls: Array[Node] = [
		_title_label,
		_ship_name_label,
		_ship_subtitle_label,
		_status_badge_label,
		_cargo_assignment_label,
		_hull_heading_label,
		_hull_value_label,
		_shield_heading_label,
		_shield_value_label,
		_fuel_heading_label,
		_fuel_value_label,
		_boost_heading_label,
		_boost_value_label,
		_cargo_heading_label,
		_cargo_value_label,
		_slots_heading_label,
		_power_heading_label,
		_power_name_label,
		_power_description_label,
		_power_status_label,
		_power_toggle_button,
		_defense_heading_label,
		_defense_name_label,
		_defense_description_label,
		_defense_status_label,
		_defense_toggle_button,
		_utility_heading_label,
		_utility_name_label,
		_utility_description_label,
		_utility_status_label,
		_utility_toggle_button,
		_backup_power_heading_label,
		_backup_power_name_label,
		_backup_power_description_label,
		_backup_power_status_label,
		_backup_power_toggle_button,
		_requirements_heading_label,
		_requirements_label,
		_standard_issue_label,
		_feedback_label,
		_confirm_button,
		_close_button,
		_laser_mount_visual,
		_shield_backup_power_visual,
		_high_voltage_shielding_visual,
	]
	for control: Node in required_controls:
		if control == null:
			return false
	_power_toggle_button.pressed.connect(
		toggle_module_for_slot.bind(ShipModuleDefinition.SlotType.POWER)
	)
	_defense_toggle_button.pressed.connect(
		toggle_module_for_slot.bind(ShipModuleDefinition.SlotType.DEFENSE)
	)
	_utility_toggle_button.pressed.connect(
		toggle_module_for_slot.bind(ShipModuleDefinition.SlotType.UTILITY)
	)
	_backup_power_toggle_button.pressed.connect(
		toggle_module_by_id.bind(ShipLoadoutRules.SHIELD_BACKUP_POWER_MODULE_ID)
	)
	_confirm_button.pressed.connect(confirm_departure)
	_close_button.pressed.connect(close_loadout)
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
	if not _game_state.ship_configuration_changed.is_connected(_on_ship_configuration_changed):
		_game_state.ship_configuration_changed.connect(_on_ship_configuration_changed)
	if not _game_state.departure_readiness_changed.is_connected(_on_departure_readiness_changed):
		_game_state.departure_readiness_changed.connect(_on_departure_readiness_changed)
	if not _game_state.order_status_changed.is_connected(_on_order_status_changed):
		_game_state.order_status_changed.connect(_on_order_status_changed)
	if not _game_state.runtime_state_reset.is_connected(_on_runtime_state_reset):
		_game_state.runtime_state_reset.connect(_on_runtime_state_reset)


func _disconnect_game_state() -> void:
	if _game_state == null:
		return
	if _game_state.ship_configuration_changed.is_connected(_on_ship_configuration_changed):
		_game_state.ship_configuration_changed.disconnect(_on_ship_configuration_changed)
	if _game_state.departure_readiness_changed.is_connected(_on_departure_readiness_changed):
		_game_state.departure_readiness_changed.disconnect(_on_departure_readiness_changed)
	if _game_state.order_status_changed.is_connected(_on_order_status_changed):
		_game_state.order_status_changed.disconnect(_on_order_status_changed)
	if _game_state.runtime_state_reset.is_connected(_on_runtime_state_reset):
		_game_state.runtime_state_reset.disconnect(_on_runtime_state_reset)
	_game_state = null


func _on_ship_configuration_changed() -> void:
	_refresh_content()


func _on_departure_readiness_changed(_confirmed: bool) -> void:
	_refresh_content()


func _on_order_status_changed(
	order_id: StringName,
	_status: GameStateModel.OrderStatus
) -> void:
	if order_definition != null and order_definition.id == order_id:
		_refresh_content()


func _on_runtime_state_reset() -> void:
	_refresh_content()


func _refresh_content() -> void:
	if not _controls_initialized:
		return
	_localize_static_labels()
	_ship_name_label.text = tr(String(ShipLoadoutRules.SHIP_NAME_KEY))
	_hull_value_label.text = _format_resource_value(ShipLoadoutRules.BASE_HULL)
	_shield_value_label.text = _format_resource_value(ShipLoadoutRules.BASE_SHIELD)
	_fuel_value_label.text = _format_resource_value(ShipLoadoutRules.BASE_FUEL)
	_boost_value_label.text = _format_resource_value(ShipLoadoutRules.BASE_BOOST)
	_cargo_value_label.text = tr("UI_LOADOUT_CARGO_VALUE_FORMAT") % [
		1,
		ShipLoadoutRules.BASE_CARGO_CAPACITY,
	]
	_refresh_cargo_assignment()
	_refresh_slot(
		ShipModuleDefinition.SlotType.POWER,
		_power_name_label,
		_power_description_label,
		_power_status_label,
		_power_toggle_button
	)
	_refresh_slot(
		ShipModuleDefinition.SlotType.DEFENSE,
		_defense_name_label,
		_defense_description_label,
		_defense_status_label,
		_defense_toggle_button
	)
	_refresh_slot(
		ShipModuleDefinition.SlotType.UTILITY,
		_utility_name_label,
		_utility_description_label,
		_utility_status_label,
		_utility_toggle_button
	)
	_refresh_module(
		ShipLoadoutRules.get_module_by_id(
			order_definition,
			ShipLoadoutRules.SHIELD_BACKUP_POWER_MODULE_ID
		),
		_backup_power_name_label,
		_backup_power_description_label,
		_backup_power_status_label,
		_backup_power_toggle_button
	)
	_refresh_requirements()
	_refresh_departure_state()
	_laser_mount_visual.visible = (
		_game_state != null
		and _game_state.is_ship_module_equipped(ShipLoadoutRules.LASER_MODULE_ID)
	)
	_shield_backup_power_visual.visible = (
		_game_state != null
		and _game_state.is_ship_module_equipped(
			ShipLoadoutRules.SHIELD_BACKUP_POWER_MODULE_ID
		)
	)
	_high_voltage_shielding_visual.visible = (
		_game_state != null
		and _game_state.is_ship_module_equipped(
			ShipLoadoutRules.HIGH_VOLTAGE_SHIELDING_MODULE_ID
		)
	)


func _localize_static_labels() -> void:
	_title_label.text = tr("UI_LOADOUT_TITLE")
	_ship_subtitle_label.text = tr("UI_LOADOUT_FIXED_SHIP_SUBTITLE")
	_hull_heading_label.text = tr("UI_LOADOUT_STAT_HULL")
	_shield_heading_label.text = tr("UI_LOADOUT_STAT_SHIELD")
	_fuel_heading_label.text = tr("UI_LOADOUT_STAT_FUEL")
	_boost_heading_label.text = tr("UI_LOADOUT_STAT_BOOST")
	_cargo_heading_label.text = tr("UI_LOADOUT_STAT_CARGO")
	_slots_heading_label.text = tr("UI_LOADOUT_SLOTS_HEADING")
	_power_heading_label.text = tr("UI_LOADOUT_SLOT_POWER")
	_defense_heading_label.text = tr("UI_LOADOUT_SLOT_DEFENSE")
	_utility_heading_label.text = tr("UI_LOADOUT_SLOT_UTILITY")
	_backup_power_heading_label.text = tr("UI_LOADOUT_SLOT_SHIELD_BACKUP_POWER")
	_requirements_heading_label.text = tr("UI_LOADOUT_REQUIREMENTS_HEADING")
	_standard_issue_label.text = tr(
		"UI_LOADOUT_STORY_MODULE_NOTE"
		if _order_has_story_module()
		else "UI_LOADOUT_STANDARD_ISSUE_NOTE"
	)
	_close_button.text = tr("UI_LOADOUT_CLOSE")


func _refresh_cargo_assignment() -> void:
	if (
		_game_state != null
		and order_definition != null
		and order_definition.cargo != null
		and _game_state.current_order_id == order_definition.id
	):
		_cargo_assignment_label.text = tr("UI_LOADOUT_CARGO_ASSIGNED_FORMAT") % tr(
			String(order_definition.cargo.display_name_key)
		)
		return
	_cargo_assignment_label.text = tr("UI_LOADOUT_CARGO_UNASSIGNED")


func _refresh_slot(
	slot_type: ShipModuleDefinition.SlotType,
	name_label: Label,
	description_label: Label,
	status_label: Label,
	toggle_button: Button
) -> void:
	var module: ShipModuleDefinition = ShipLoadoutRules.get_module_for_slot(
		order_definition,
		slot_type
	)
	_refresh_module(
		module,
		name_label,
		description_label,
		status_label,
		toggle_button
	)


func _refresh_module(
	module: ShipModuleDefinition,
	name_label: Label,
	description_label: Label,
	status_label: Label,
	toggle_button: Button
) -> void:
	if module == null:
		name_label.text = tr("UI_LOADOUT_VALUE_NOT_LISTED")
		description_label.text = tr("UI_LOADOUT_VALUE_NOT_LISTED")
		status_label.text = tr("UI_LOADOUT_STATE_NOT_LISTED")
		toggle_button.text = tr("UI_LOADOUT_INSTALL")
		toggle_button.disabled = true
		return
	var installed: bool = (
		_game_state != null and _game_state.is_ship_module_equipped(module.id)
	)
	var owned: bool = (
		_game_state != null and _game_state.has_ship_module(module.id)
	)
	name_label.text = tr(String(module.display_name_key))
	description_label.text = tr(String(module.description_key))
	name_label.tooltip_text = description_label.text
	var role_text: String = tr("UI_LOADOUT_ROLE_RECOMMENDED")
	if order_definition.required_modules.has(module):
		role_text = tr(
			"UI_LOADOUT_ROLE_REQUIRED_STORY"
			if not module.story_unlock_flags.is_empty()
			else "UI_LOADOUT_ROLE_REQUIRED"
		)
	var state_text: String = tr("UI_LOADOUT_STATE_EMPTY")
	if installed:
		state_text = tr("UI_LOADOUT_STATE_INSTALLED")
	elif not owned:
		state_text = tr("UI_LOADOUT_STATE_NOT_OBTAINED")
	status_label.text = tr("UI_LOADOUT_SLOT_STATUS_FORMAT") % [role_text, state_text]
	if not owned:
		toggle_button.text = tr("UI_LOADOUT_NOT_OBTAINED")
		toggle_button.disabled = true
	else:
		toggle_button.text = tr(
			"UI_LOADOUT_UNINSTALL" if installed else "UI_LOADOUT_INSTALL"
		)
		toggle_button.disabled = _game_state == null


func _refresh_requirements() -> void:
	if order_definition == null:
		_requirements_label.text = tr("UI_LOADOUT_VALUE_UNAVAILABLE")
		return
	var installed_required_count: int = 0
	for module: ShipModuleDefinition in order_definition.required_modules:
		if (
			_game_state != null
			and module != null
			and _game_state.is_ship_module_equipped(module.id)
		):
			installed_required_count += 1
	var installed_optional_count: int = 0
	for module: ShipModuleDefinition in order_definition.recommended_modules:
		if (
			_game_state != null
			and module != null
			and _game_state.is_ship_module_equipped(module.id)
		):
			installed_optional_count += 1
	_requirements_label.text = tr("UI_LOADOUT_REQUIREMENTS_SUMMARY_FORMAT") % [
		installed_required_count,
		order_definition.required_modules.size(),
		installed_optional_count,
		order_definition.recommended_modules.size(),
	]


func _refresh_departure_state() -> void:
	_confirm_button.text = tr("UI_LOADOUT_CONFIRM_DEPARTURE")
	if _game_state == null:
		_apply_departure_state(
			"UI_LOADOUT_STATUS_UNAVAILABLE",
			"UI_LOADOUT_FEEDBACK_STATE_UNAVAILABLE",
			true
		)
		return
	if not _has_complete_loadout_data():
		_apply_departure_state(
			"UI_LOADOUT_STATUS_UNAVAILABLE",
			"UI_LOADOUT_FEEDBACK_DATA_UNAVAILABLE",
			true
		)
		return
	if _game_state.current_order_id != order_definition.id:
		_apply_departure_state(
			"UI_LOADOUT_STATUS_WAITING_ORDER",
			"UI_LOADOUT_FEEDBACK_WAITING_ORDER",
			true
		)
		return
	if _game_state.is_departure_confirmed_for_order(order_definition):
		_status_badge_label.text = tr("UI_LOADOUT_STATUS_CONFIRMED")
		_feedback_label.text = tr("UI_LOADOUT_FEEDBACK_CONFIRMED")
		_confirm_button.text = tr("UI_LOADOUT_CONFIRMED_BUTTON")
		_confirm_button.disabled = true
		return
	var missing_modules: Array[ShipModuleDefinition] = _game_state.get_missing_required_modules(
		order_definition
	)
	if not missing_modules.is_empty():
		var not_obtained_names: PackedStringArray = []
		var not_installed_names: PackedStringArray = []
		for module: ShipModuleDefinition in missing_modules:
			if _game_state.has_ship_module(module.id):
				not_installed_names.append(_translate_module_name(module))
			else:
				not_obtained_names.append(_translate_module_name(module))
		_status_badge_label.text = tr("UI_LOADOUT_STATUS_INCOMPLETE")
		if not not_obtained_names.is_empty():
			_feedback_label.text = tr(
				"UI_LOADOUT_FEEDBACK_NOT_OBTAINED_FORMAT"
			) % tr("UI_LOADOUT_LIST_SEPARATOR").join(not_obtained_names)
		else:
			_feedback_label.text = tr(
				"UI_LOADOUT_FEEDBACK_MISSING_REQUIRED_FORMAT"
			) % tr("UI_LOADOUT_LIST_SEPARATOR").join(not_installed_names)
		_confirm_button.disabled = true
		return
	_apply_departure_state(
		"UI_LOADOUT_STATUS_READY",
		"UI_LOADOUT_FEEDBACK_READY",
		false
	)


func _apply_departure_state(status_key: String, feedback_key: String, disabled: bool) -> void:
	_status_badge_label.text = tr(status_key)
	_feedback_label.text = tr(feedback_key)
	_confirm_button.disabled = disabled


func _has_complete_loadout_data() -> bool:
	if (
		order_definition == null
		or order_definition.id.is_empty()
		or order_definition.cargo == null
		or order_definition.destination_planet == null
	):
		return false
	for module: ShipModuleDefinition in order_definition.required_modules:
		if (
			module == null
			or module.id.is_empty()
			or ShipLoadoutRules.get_configuration_slot_id(module).is_empty()
		):
			return false
	return true


func _order_has_story_module() -> bool:
	for module: ShipModuleDefinition in ShipLoadoutRules.get_order_modules(
		order_definition
	):
		if (
			module != null
			and not ShipLoadoutRules.BASE_OWNED_MODULE_IDS.has(module.id)
		):
			return true
	return false


func _translate_module_name(module: ShipModuleDefinition) -> String:
	if module == null or module.display_name_key.is_empty():
		return tr("UI_LOADOUT_VALUE_UNAVAILABLE")
	return tr(String(module.display_name_key))


func _format_resource_value(value: int) -> String:
	return tr("UI_LOADOUT_RESOURCE_VALUE_FORMAT") % [value, value]
