extends BaseInputHandler
class_name InputHandler

## Centralized input handling system that provides clean input interface for other components

# Input state
var movement_vector := Vector2.ZERO
var is_run_button_pressed := false
var is_jump_button_pressed := false
var is_aim_button_pressed := false
var is_fire_button_pressed := false

# Input buffer for better responsiveness (optional enhancement)
var jump_buffer_timer := 0.0
var fire_buffer_timer := 0.0
const BUFFER_TIME := 0.1

# Signals for input events
signal jump_pressed()
signal jump_released()
signal fire_pressed()
signal fire_released()
signal aim_pressed()
signal aim_released()
signal run_pressed()
signal run_released()

func _ready() -> void:
	# Set process priority to ensure input is read first
	process_priority = -1

func update_input() -> void:
	# Update movement vector
	movement_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Update button states with edge detection
	_update_run_input()
	_update_jump_input()
	_update_aim_input()
	_update_fire_input()

func _update_run_input() -> void:
	var was_pressed := is_run_button_pressed
	is_run_button_pressed = Input.is_action_pressed("ui_run")
	
	if is_run_button_pressed and not was_pressed:
		run_pressed.emit()
	elif not is_run_button_pressed and was_pressed:
		run_released.emit()

func _update_jump_input() -> void:
	var was_pressed := is_jump_button_pressed
	is_jump_button_pressed = Input.is_action_pressed("ui_accept")
	
	if is_jump_button_pressed and not was_pressed:
		jump_pressed.emit()
		jump_buffer_timer = BUFFER_TIME
	elif not is_jump_button_pressed and was_pressed:
		jump_released.emit()

func _update_aim_input() -> void:
	var was_pressed := is_aim_button_pressed
	is_aim_button_pressed = Input.is_action_pressed("ui_aim")
	
	if is_aim_button_pressed and not was_pressed:
		aim_pressed.emit()
	elif not is_aim_button_pressed and was_pressed:
		aim_released.emit()

func _update_fire_input() -> void:
	var was_pressed := is_fire_button_pressed
	is_fire_button_pressed = Input.is_action_pressed("ui_fire")
	
	if is_fire_button_pressed and not was_pressed:
		fire_pressed.emit()
		fire_buffer_timer = BUFFER_TIME
	elif not is_fire_button_pressed and was_pressed:
		fire_released.emit()

## Get normalized movement vector
func get_movement_vector() -> Vector2:
	return movement_vector

## Get raw movement input (not normalized)
func get_raw_movement_vector() -> Vector2:
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

## Check if player has movement input
func has_movement_input() -> bool:
	return movement_vector.length() > 0.1

## Check individual button states
func is_run_pressed() -> bool:
	return is_run_button_pressed

func is_jump_pressed() -> bool:
	return is_jump_button_pressed

func is_aim_pressed() -> bool:
	return is_aim_button_pressed

func is_fire_pressed() -> bool:
	return is_fire_button_pressed

## Get movement direction as angle in radians
func get_movement_angle() -> float:
	if has_movement_input():
		return movement_vector.angle()
	return 0.0

## Get movement direction as 8-way direction string
func get_movement_direction() -> String:
	if has_movement_input():
		return DirectionHelper.vector_to_direction_name(movement_vector)
	return ""

## Check if any combat action is pressed
func is_any_combat_action() -> bool:
	return is_aim_button_pressed or is_fire_button_pressed

## Input buffer checks (for more responsive controls)
func is_jump_buffered() -> bool:
	return jump_buffer_timer > 0

func is_fire_buffered() -> bool:
	return fire_buffer_timer > 0

func clear_jump_buffer() -> void:
	jump_buffer_timer = 0.0

func clear_fire_buffer() -> void:
	fire_buffer_timer = 0.0

func _process(delta: float) -> void:
	# Update input buffers
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if fire_buffer_timer > 0:
		fire_buffer_timer -= delta
