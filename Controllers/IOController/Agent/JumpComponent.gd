extends Node
class_name JumpComponent

## Handles jump physics, gravity, and vertical movement

# Jump constants
const GRAVITY := 980.0
const JUMP_STRENGTH := 175.0
const MAX_FALL_SPEED := 600.0

# Component references
var player: CharacterBody2D
var state_manager: StateManager
var animated_sprite: AnimatedSprite2D
var input_handler

# Jump state
var y_offset := 0.0
var vertical_velocity := 0.0
var jump_momentum := Vector2.ZERO
var base_y_position := 0.0
var was_running_when_jumped := false
var jump_key_released := true

signal jump_started()
signal jump_landed()
signal jump_height_changed(height: float)

func initialize(player_ref: CharacterBody2D, state_ref: StateManager, sprite_ref: AnimatedSprite2D) -> void:
	player = player_ref
	state_manager = state_ref
	animated_sprite = sprite_ref

func set_base_position(y_pos: float) -> void:
	base_y_position = y_pos

func update(delta: float) -> void:
	_handle_jump_input()

	if state_manager.get_state_value("is_jumping"):
		_process_jump_physics(delta)

	animated_sprite.position.y = -y_offset

func _handle_jump_input() -> void:
	if not input_handler:
		return

	if not input_handler.is_jump_pressed():
		jump_key_released = true

	var can_jump := _check_can_jump()

	if can_jump:
		_start_jump()
		jump_key_released = false

func _check_can_jump() -> bool:
	if not input_handler or not input_handler.is_jump_pressed():
		return false

	if not jump_key_released:
		return false

	if state_manager.get_state_value("is_jumping"):
		return false

	if state_manager.get_state_value("is_aiming"):
		return false

	if state_manager.get_state_value("is_shooting"):
		return false

	return true

func _start_jump() -> void:
	was_running_when_jumped = state_manager.get_state_value("is_running")
	jump_momentum = player.velocity
	vertical_velocity = JUMP_STRENGTH
	jump_started.emit()

func _process_jump_physics(delta: float) -> void:
	vertical_velocity -= GRAVITY * delta
	vertical_velocity = max(vertical_velocity, -MAX_FALL_SPEED)

	y_offset += vertical_velocity * delta
	jump_height_changed.emit(y_offset)

	if y_offset <= 0.0:
		_land_from_jump()

func _land_from_jump() -> void:
	y_offset = 0.0
	vertical_velocity = 0.0
	jump_momentum = Vector2.ZERO
	was_running_when_jumped = false
	jump_landed.emit()

func get_jump_momentum() -> Vector2:
	return jump_momentum

func get_vertical_velocity() -> float:
	return vertical_velocity

func get_current_height() -> float:
	return y_offset

func is_at_peak() -> bool:
	return state_manager.get_state_value("is_jumping") and abs(vertical_velocity) < 10.0

func is_falling() -> bool:
	return state_manager.get_state_value("is_jumping") and vertical_velocity < 0

func was_running_on_jump_start() -> bool:
	return was_running_when_jumped

func force_land() -> void:
	if state_manager.get_state_value("is_jumping"):
		_land_from_jump()

func print_jump_state() -> void:
	if not OS.is_debug_build():
		return

	print("JumpComponent: Height %.1f | Velocity %.1f | Peak: %s" % [
		y_offset, vertical_velocity, is_at_peak()
	])