class_name StationPlayer
extends CharacterBody2D

signal interaction_target_changed(target: Interactable2D)
signal interaction_triggered(target: Interactable2D)

const INTERACTION_FEEDBACK_DURATION: float = 0.9
const MOVING_ANIMATION_THRESHOLD: float = 2.0

const TRANSPARENT: Color = Color(0.0, 0.0, 0.0, 0.0)
const UNIFORM_DARK: Color = Color("142a45")
const UNIFORM_CYAN: Color = Color("77c9c4")
const UNIFORM_AMBER: Color = Color("e7a85b")
const FACE_COLOR: Color = Color("e8dfc8")
const BOOT_COLOR: Color = Color("2a2430")
const VISOR_COLOR: Color = Color("08111f")

@export_range(20.0, 300.0, 1.0) var move_speed: float = 112.0
@export_range(50.0, 2000.0, 10.0) var acceleration: float = 720.0
@export_range(50.0, 2400.0, 10.0) var deceleration: float = 960.0
@export var initial_facing_direction: Vector2 = Vector2.UP
@export var interaction_action: StringName = &"interact"

@onready var _sprite: AnimatedSprite2D = %PlayerSprite
@onready var _interaction_sensor: Area2D = %InteractionSensor
@onready var _prompt_root: Control = %InteractionPrompt
@onready var _prompt_label: Label = %InteractionPromptLabel

var _facing_direction: Vector2 = Vector2.UP
var _current_interactable: Interactable2D
var _feedback_time_remaining: float = 0.0
var _animations_initialized: bool = false


func _ready() -> void:
	initialize_placeholder_animations()
	set_facing_direction(initial_facing_direction)
	refresh_interaction_target()
	_update_animation()


func _physics_process(delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down"
	)
	var target_velocity: Vector2 = calculate_target_velocity(input_direction, move_speed)
	velocity = step_velocity(
		velocity,
		target_velocity,
		acceleration,
		deceleration,
		delta
	)
	if not input_direction.is_zero_approx():
		set_facing_direction(input_direction)
	move_and_slide()
	refresh_interaction_target()
	if Input.is_action_just_pressed(interaction_action):
		try_interact()
	if _feedback_time_remaining > 0.0:
		_feedback_time_remaining = maxf(_feedback_time_remaining - delta, 0.0)
		if is_zero_approx(_feedback_time_remaining):
			_update_interaction_prompt()
	_update_animation()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_interaction_prompt()


static func calculate_target_velocity(input_direction: Vector2, speed: float) -> Vector2:
	return input_direction.limit_length(1.0) * maxf(speed, 0.0)


static func step_velocity(
	current_velocity: Vector2,
	target_velocity: Vector2,
	acceleration_rate: float,
	deceleration_rate: float,
	delta: float
) -> Vector2:
	var rate: float = acceleration_rate
	if target_velocity.is_zero_approx():
		rate = deceleration_rate
	return current_velocity.move_toward(
		target_velocity,
		maxf(rate, 0.0) * maxf(delta, 0.0)
	)


func set_facing_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	_facing_direction = direction.normalized()
	_update_animation()


func get_facing_direction() -> Vector2:
	return _facing_direction


func get_current_interactable() -> Interactable2D:
	return _current_interactable


func get_interaction_prompt_text() -> String:
	if _prompt_label == null:
		return ""
	return _prompt_label.text


func is_interaction_prompt_visible() -> bool:
	return _prompt_root != null and _prompt_root.visible


func get_current_animation_name() -> StringName:
	if _sprite == null:
		return StringName()
	return _sprite.animation


func refresh_interaction_target() -> Interactable2D:
	if _interaction_sensor == null:
		_interaction_sensor = get_node_or_null("InteractionSensor") as Area2D
	if _interaction_sensor == null:
		return null
	var candidates: Array[InteractionCandidate] = []
	for area: Area2D in _interaction_sensor.get_overlapping_areas():
		var interactable: Interactable2D = area as Interactable2D
		if interactable == null or not interactable.can_interact(self):
			continue
		candidates.append(interactable.build_candidate(global_position, _facing_direction))
	var selected_candidate: InteractionCandidate = InteractionSelector.select_best(candidates)
	var selected_interactable: Interactable2D = null
	if selected_candidate != null:
		selected_interactable = selected_candidate.payload as Interactable2D
	_set_current_interactable(selected_interactable)
	return _current_interactable


func try_interact() -> bool:
	if _current_interactable == null:
		return false
	if not _current_interactable.interact(self):
		return false
	_feedback_time_remaining = INTERACTION_FEEDBACK_DURATION
	interaction_triggered.emit(_current_interactable)
	_update_interaction_prompt()
	return true


func initialize_placeholder_animations() -> void:
	if _animations_initialized:
		return
	if _sprite == null:
		_sprite = get_node_or_null("VisualRoot/PlayerSprite") as AnimatedSprite2D
	if _sprite == null:
		return
	var frames: SpriteFrames = SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	for direction_name: StringName in [&"down", &"up", &"side"]:
		var idle_animation: StringName = StringName("idle_%s" % direction_name)
		frames.add_animation(idle_animation)
		frames.set_animation_loop(idle_animation, true)
		frames.set_animation_speed(idle_animation, 2.0)
		for frame_index: int in 2:
			frames.add_frame(
				idle_animation,
				_create_placeholder_texture(direction_name, frame_index, false)
			)

		var walk_animation: StringName = StringName("walk_%s" % direction_name)
		frames.add_animation(walk_animation)
		frames.set_animation_loop(walk_animation, true)
		frames.set_animation_speed(walk_animation, 8.0)
		for frame_index: int in 4:
			frames.add_frame(
				walk_animation,
				_create_placeholder_texture(direction_name, frame_index, true)
			)
	_sprite.sprite_frames = frames
	_animations_initialized = true


func _set_current_interactable(interactable: Interactable2D) -> void:
	if _current_interactable == interactable:
		return
	_current_interactable = interactable
	_feedback_time_remaining = 0.0
	interaction_target_changed.emit(_current_interactable)
	_update_interaction_prompt()


func _update_interaction_prompt() -> void:
	if _prompt_root == null:
		_prompt_root = get_node_or_null("InteractionPromptLayer/InteractionPrompt") as Control
	if _prompt_label == null:
		_prompt_label = get_node_or_null(
			"InteractionPromptLayer/InteractionPrompt/Panel/InteractionPromptLabel"
		) as Label
	if _prompt_root == null or _prompt_label == null:
		return
	if _current_interactable == null:
		_prompt_root.visible = false
		_prompt_label.text = ""
		return
	_prompt_root.visible = true
	var prompt_text: String = _current_interactable.get_interaction_prompt()
	if _feedback_time_remaining > 0.0:
		_prompt_label.text = tr("UI_INTERACTION_FEEDBACK") % prompt_text
		return
	_prompt_label.text = tr("UI_INTERACTION_PROMPT") % [
		_get_action_binding_label(interaction_action),
		prompt_text,
	]


func _get_action_binding_label(action: StringName) -> String:
	for input_event: InputEvent in InputMap.action_get_events(action):
		if input_event is InputEventKey:
			var key_event: InputEventKey = input_event as InputEventKey
			var keycode: Key = key_event.physical_keycode
			if keycode == KEY_NONE:
				keycode = key_event.keycode
			var key_label: String = OS.get_keycode_string(keycode)
			if not key_label.is_empty():
				return key_label
		var event_label: String = input_event.as_text()
		if not event_label.is_empty():
			return event_label
	return String(action).to_upper()


func _update_animation() -> void:
	if not _animations_initialized or _sprite == null:
		return
	var direction_name: String = "down"
	_sprite.flip_h = false
	if absf(_facing_direction.x) > absf(_facing_direction.y):
		direction_name = "side"
		_sprite.flip_h = _facing_direction.x < 0.0
	elif _facing_direction.y < 0.0:
		direction_name = "up"
	var state_name: String = "idle"
	if velocity.length() > MOVING_ANIMATION_THRESHOLD:
		state_name = "walk"
	var animation_name: StringName = StringName("%s_%s" % [state_name, direction_name])
	if _sprite.animation != animation_name or not _sprite.is_playing():
		_sprite.play(animation_name)


func _create_placeholder_texture(
	direction_name: StringName,
	frame_index: int,
	is_walking: bool
) -> ImageTexture:
	var image: Image = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	image.fill(TRANSPARENT)
	var bob_offset: int = 0
	if is_walking and frame_index % 2 == 1:
		bob_offset = -1
	_fill_image_rect(image, Rect2i(10, 4 + bob_offset, 12, 12), FACE_COLOR)
	_fill_image_rect(image, Rect2i(8, 16 + bob_offset, 16, 21), UNIFORM_DARK)
	_fill_image_rect(image, Rect2i(10, 18 + bob_offset, 12, 13), UNIFORM_CYAN)
	_fill_image_rect(image, Rect2i(8, 22 + bob_offset, 3, 12), UNIFORM_AMBER)
	_fill_image_rect(image, Rect2i(21, 22 + bob_offset, 3, 12), UNIFORM_AMBER)

	var left_step: int = 0
	var right_step: int = 0
	if is_walking:
		left_step = 1 if frame_index in [0, 1] else -1
		right_step = -left_step
	_fill_image_rect(image, Rect2i(9 + left_step, 36 + bob_offset, 6, 9), BOOT_COLOR)
	_fill_image_rect(image, Rect2i(17 + right_step, 36 + bob_offset, 6, 9), BOOT_COLOR)

	match direction_name:
		&"up":
			_fill_image_rect(image, Rect2i(11, 6 + bob_offset, 10, 4), UNIFORM_DARK)
		&"side":
			_fill_image_rect(image, Rect2i(19, 8 + bob_offset, 2, 2), VISOR_COLOR)
		_:
			_fill_image_rect(image, Rect2i(12, 8 + bob_offset, 2, 2), VISOR_COLOR)
			_fill_image_rect(image, Rect2i(18, 8 + bob_offset, 2, 2), VISOR_COLOR)
	if not is_walking and frame_index == 1:
		_fill_image_rect(image, Rect2i(15, 24, 2, 2), UNIFORM_AMBER.lightened(0.18))
	return ImageTexture.create_from_image(image)


func _fill_image_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			image.set_pixel(x, y, color)
