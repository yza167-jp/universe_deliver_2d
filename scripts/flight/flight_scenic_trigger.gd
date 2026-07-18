class_name FlightScenicTrigger
extends Area2D

signal triggered(trigger_id: StringName)

@export var trigger_id: StringName = &""

@onready var _visual_root: Node2D = $VisualRoot

var _is_triggered: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_update_visual_state()


func try_trigger(body: Node) -> bool:
	if _is_triggered or trigger_id.is_empty() or not body is FlightLabShip:
		return false
	_is_triggered = true
	set_deferred("monitoring", false)
	_update_visual_state()
	triggered.emit(trigger_id)
	return true


func reset_trigger() -> void:
	_is_triggered = false
	set_deferred("monitoring", true)
	_update_visual_state()


func is_triggered() -> bool:
	return _is_triggered


func _on_body_entered(body: Node) -> void:
	try_trigger(body)


func _update_visual_state() -> void:
	if _visual_root == null:
		return
	_visual_root.modulate = (
		Color(0.55, 0.72, 0.72, 0.28)
		if _is_triggered
		else Color.WHITE
	)
