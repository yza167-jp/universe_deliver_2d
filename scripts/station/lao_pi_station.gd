class_name LaoPiStation
extends Interactable2D

signal scripted_movement_finished

const TRANSPARENT: Color = Color(0.0, 0.0, 0.0, 0.0)
const FUR_DARK: Color = Color("6f4938")
const FUR_MID: Color = Color("9b6a4b")
const FUR_LIGHT: Color = Color("c89465")
const UNIFORM_DARK: Color = Color("142a45")
const UNIFORM_CYAN: Color = Color("77c9c4")
const UNIFORM_AMBER: Color = Color("e7a85b")
const EYE_COLOR: Color = Color("08111f")

@export_range(12.0, 120.0, 1.0) var scripted_move_speed: float = 44.0
@export var initial_facing_direction: Vector2 = Vector2.RIGHT

@onready var _sprite: AnimatedSprite2D = %LaoPiSprite

var _facing_direction: Vector2 = Vector2.RIGHT
var _movement_target: Vector2 = Vector2.ZERO
var _is_moving: bool = false
var _is_talking: bool = false
var _animations_initialized: bool = false


func _ready() -> void:
	initialize_placeholder_animations()
	set_facing_direction(initial_facing_direction)
	set_process(false)
	_update_animation()


func _process(delta: float) -> void:
	if not _is_moving:
		set_process(false)
		return
	var offset: Vector2 = _movement_target - global_position
	var movement_step: float = scripted_move_speed * delta
	if offset.length() <= movement_step:
		global_position = _movement_target
		_is_moving = false
		set_process(false)
		_update_animation()
		scripted_movement_finished.emit()
		return
	set_facing_direction(offset)
	global_position += offset.normalized() * movement_step
	_update_animation()


func move_to(target_global_position: Vector2) -> void:
	_movement_target = target_global_position
	if global_position.is_equal_approx(_movement_target):
		_is_moving = false
		_update_animation()
		scripted_movement_finished.emit()
		return
	_is_talking = false
	_is_moving = true
	set_process(true)
	_update_animation()


func face_toward(target_global_position: Vector2) -> void:
	set_facing_direction(target_global_position - global_position)


func set_facing_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	_facing_direction = direction.normalized()
	_update_animation()


func set_talking(talking: bool) -> void:
	_is_talking = talking
	_update_animation()


func is_moving_to_scripted_position() -> bool:
	return _is_moving


func is_talking() -> bool:
	return _is_talking


func get_current_animation_name() -> StringName:
	if _sprite == null:
		return StringName()
	return _sprite.animation


func initialize_placeholder_animations() -> void:
	if _animations_initialized:
		return
	if _sprite == null:
		_sprite = get_node_or_null("VisualRoot/LaoPiSprite") as AnimatedSprite2D
	if _sprite == null:
		return
	var frames: SpriteFrames = SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	for direction_name: StringName in [&"down", &"up", &"side"]:
		_add_animation(frames, &"idle", direction_name, 2, 2.0)
		_add_animation(frames, &"walk", direction_name, 4, 7.0)
		_add_animation(frames, &"talk", direction_name, 3, 5.0)
	_sprite.sprite_frames = frames
	_animations_initialized = true


func _add_animation(
	frames: SpriteFrames,
	state_name: StringName,
	direction_name: StringName,
	frame_count: int,
	frames_per_second: float
) -> void:
	var animation_name: StringName = StringName("%s_%s" % [state_name, direction_name])
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, true)
	frames.set_animation_speed(animation_name, frames_per_second)
	for frame_index: int in frame_count:
		frames.add_frame(
			animation_name,
			_create_placeholder_texture(direction_name, state_name, frame_index)
		)


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
	if _is_moving:
		state_name = "walk"
	elif _is_talking:
		state_name = "talk"
	var animation_name: StringName = StringName("%s_%s" % [state_name, direction_name])
	if _sprite.animation != animation_name or not _sprite.is_playing():
		_sprite.play(animation_name)


func _create_placeholder_texture(
	direction_name: StringName,
	state_name: StringName,
	frame_index: int
) -> ImageTexture:
	var image: Image = Image.create(48, 56, false, Image.FORMAT_RGBA8)
	image.fill(TRANSPARENT)
	var is_walking: bool = state_name == &"walk"
	var is_talking_frame: bool = state_name == &"talk" and frame_index % 2 == 1
	var bob_offset: int = -1 if is_walking and frame_index % 2 == 1 else 0

	_fill_image_rect(image, Rect2i(9, 5 + bob_offset, 7, 7), FUR_DARK)
	_fill_image_rect(image, Rect2i(32, 5 + bob_offset, 7, 7), FUR_DARK)
	_fill_image_rect(image, Rect2i(7, 9 + bob_offset, 34, 18), FUR_MID)
	_fill_image_rect(image, Rect2i(11, 16 + bob_offset, 27, 13), FUR_LIGHT)
	_fill_image_rect(image, Rect2i(10, 26 + bob_offset, 28, 22), FUR_DARK)
	_fill_image_rect(image, Rect2i(13, 29 + bob_offset, 22, 15), UNIFORM_DARK)
	_fill_image_rect(image, Rect2i(15, 31 + bob_offset, 18, 8), UNIFORM_CYAN)
	_fill_image_rect(image, Rect2i(13, 40 + bob_offset, 22, 3), UNIFORM_AMBER)

	var left_step: int = 0
	var right_step: int = 0
	if is_walking:
		left_step = 1 if frame_index in [0, 1] else -1
		right_step = -left_step
	_fill_image_rect(image, Rect2i(12 + left_step, 46 + bob_offset, 9, 8), FUR_DARK)
	_fill_image_rect(image, Rect2i(27 + right_step, 46 + bob_offset, 9, 8), FUR_DARK)

	match direction_name:
		&"up":
			_fill_image_rect(image, Rect2i(12, 11 + bob_offset, 24, 5), FUR_DARK)
		&"side":
			_fill_image_rect(image, Rect2i(34, 17 + bob_offset, 10, 7), FUR_LIGHT)
			_fill_image_rect(image, Rect2i(35, 14 + bob_offset, 2, 2), EYE_COLOR)
			if is_talking_frame:
				_fill_image_rect(image, Rect2i(40, 22 + bob_offset, 3, 2), EYE_COLOR)
		_:
			_fill_image_rect(image, Rect2i(15, 14 + bob_offset, 2, 2), EYE_COLOR)
			_fill_image_rect(image, Rect2i(31, 14 + bob_offset, 2, 2), EYE_COLOR)
			_fill_image_rect(image, Rect2i(20, 20 + bob_offset, 8, 4), FUR_DARK)
			if is_talking_frame:
				_fill_image_rect(image, Rect2i(22, 24 + bob_offset, 4, 2), EYE_COLOR)
	return ImageTexture.create_from_image(image)


func _fill_image_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			image.set_pixel(x, y, color)
