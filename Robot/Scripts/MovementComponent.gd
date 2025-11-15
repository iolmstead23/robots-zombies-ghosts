extends Node
class_name MovementComponent

## Handles all horizontal movement logic including walking and running

# Movement constants
const SPEED := 275.0
const RUN_SPEED_MULTIPLIER := 1.75
const AIM_SPEED_MULTIPLIER := 0.8  # 20% speed reduction while aiming
const MOVEMENT_THRESHOLD := 1.0

# Component references
var player: CharacterBody2D
var state_manager: StateManager
var input_handler: BaseInputHandler

# Current movement state
var current_velocity := Vector2.ZERO
var current_speed := SPEED

# Signals
signal velocity_calculated(velocity: Vector2)
signal speed_changed(new_speed: float)

func initialize(player_ref: CharacterBody2D, state_ref: StateManager, input_ref: BaseInputHandler) -> void:
	player = player_ref
	state_manager = state_ref
	input_handler = input_ref

func update(_delta: float) -> void:
	_calculate_movement()

func _calculate_movement() -> void:
	var input_dir := input_handler.get_movement_vector()
	var is_shift_pressed := input_handler.is_run_pressed()
	var is_aiming: bool = state_manager.get_state_value("is_aiming")
	var is_shooting: bool = state_manager.get_state_value("is_shooting")
	var is_jumping: bool = state_manager.get_state_value("is_jumping")
	
	# Update has_input state
	state_manager.set_state_value("has_input", input_dir.length() > 0.1)
	
	# Skip velocity calculation if jumping (jump component handles it)
	if is_jumping:
		return
	
	# Calculate speed based on current state
	var speed := SPEED
	
	# Priority: Aiming/Shooting > Running > Walking
	if is_aiming or is_shooting:
		# Reduced speed while aiming or shooting
		speed = SPEED * AIM_SPEED_MULTIPLIER
		state_manager.set_state_value("is_running", false)
	elif is_shift_pressed and not is_aiming and not is_shooting:
		# Running (only if not aiming/shooting)
		speed = SPEED * RUN_SPEED_MULTIPLIER
		state_manager.set_state_value("is_running", true)
	else:
		# Normal walking
		speed = SPEED
		state_manager.set_state_value("is_running", false)
	
	# Calculate final velocity
	if state_manager.get_state_value("has_input"):
		current_velocity = input_dir.normalized() * speed
	else:
		current_velocity = Vector2.ZERO
		state_manager.set_state_value("is_running", false)
	
	# Track speed changes
	if speed != current_speed:
		current_speed = speed
		speed_changed.emit(current_speed)
	
	velocity_calculated.emit(current_velocity)

func get_velocity() -> Vector2:
	return current_velocity

func get_current_speed() -> float:
	return current_speed

func is_moving() -> bool:
	return current_velocity.length() > MOVEMENT_THRESHOLD

## Get the speed modifier based on current state
func get_speed_modifier() -> float:
	var is_aiming: bool = state_manager.get_state_value("is_aiming")
	var is_shooting: bool = state_manager.get_state_value("is_shooting")
	var is_running: bool = state_manager.get_state_value("is_running")
	
	if is_aiming or is_shooting:
		return AIM_SPEED_MULTIPLIER
	elif is_running:
		return RUN_SPEED_MULTIPLIER
	else:
		return 1.0
