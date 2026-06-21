extends Node
class_name AgentJumpComponent

## Handles jump physics, gravity, and vertical movement

const GRAVITY := 980.0
const JUMP_STRENGTH := 600.00
const MAX_FALL_SPEED := 600.0

var player: CharacterBody2D
var state_manager: AgentState
var input_handler: AgentInputHandler

var y_offset := 0.0
var vertical_velocity := 0.0
var jump_momentum := Vector2.ZERO
var was_running_when_jumped := false
var jump_key_released := true

signal jump_started()
signal jump_landed()

func initialize(player_ref: CharacterBody2D, state_ref: AgentState, input_ref: AgentInputHandler) -> void:
	player = player_ref
	state_manager = state_ref
	input_handler = input_ref

func update(delta: float) -> void:
	_handle_jump_input()

	if state_manager.get_state_value("is_jumping"):
		_process_jump_physics(delta)

	state_manager.set_state_value("jump_height", y_offset)

func _handle_jump_input() -> void:
	if not input_handler:
		return

	if not input_handler.is_jump_pressed():
		jump_key_released = true

	if _check_can_jump():
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
	state_manager.set_state_value("is_jumping", true)
	input_handler.is_input_blocked = true
	jump_started.emit()

func _process_jump_physics(delta: float) -> void:
	vertical_velocity -= GRAVITY * delta
	vertical_velocity = max(vertical_velocity, -MAX_FALL_SPEED)

	y_offset += vertical_velocity * delta

	if y_offset <= 0.0:
		_land_from_jump()

func _land_from_jump() -> void:
	y_offset = 0.0
	vertical_velocity = 0.0
	jump_momentum = Vector2.ZERO
	was_running_when_jumped = false
	input_handler.is_input_blocked = false
	jump_landed.emit()

func get_current_height() -> float:
	return y_offset

func is_at_peak() -> bool:
	return state_manager.get_state_value("is_jumping") and abs(vertical_velocity) < 10.0

func is_falling() -> bool:
	return state_manager.get_state_value("is_jumping") and vertical_velocity < 0

func was_running_on_jump_start() -> bool:
	return was_running_when_jumped

func print_jump_state() -> void:
	if not OS.is_debug_build():
		return

	print("AgentJumpComponent: Height %.1f | Velocity %.1f | Peak: %s" % [
		y_offset, vertical_velocity, is_at_peak()
	])
