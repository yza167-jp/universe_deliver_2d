class_name Interactable2D
extends Area2D

signal interaction_triggered(actor: Node)

@export var interaction_id: StringName
@export var prompt_key: StringName
@export var interaction_priority: int = 0
@export var interaction_enabled: bool = true


func can_interact(_actor: Node) -> bool:
	return interaction_enabled and not interaction_id.is_empty() and not prompt_key.is_empty()


func get_interaction_prompt() -> String:
	return tr(String(prompt_key))


func build_candidate(
	actor_global_position: Vector2,
	actor_facing: Vector2
) -> InteractionCandidate:
	var offset: Vector2 = global_position - actor_global_position
	var alignment: float = 1.0
	if not offset.is_zero_approx() and not actor_facing.is_zero_approx():
		alignment = actor_facing.normalized().dot(offset.normalized())
	return InteractionCandidate.new(
		interaction_id,
		interaction_priority,
		offset.length_squared(),
		alignment,
		self
	)


func interact(actor: Node) -> bool:
	if not can_interact(actor):
		return false
	interaction_triggered.emit(actor)
	return true
