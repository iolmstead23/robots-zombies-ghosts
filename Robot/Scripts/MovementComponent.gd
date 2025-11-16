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

var _safe_velocity: Vector2 = Vector2.ZERO # Variable to store the safe velocity from NavigationAgent

func initialize(player_ref: CharacterBody2D, state_ref: StateManager, input_ref: BaseInputHandler) -> void:
	player = player_ref
	state_manager = state_ref
	input_handler = input_ref

func update(_delta: float) -> void:
	_calculate_movement()
	
func set_safe_velocity(vel: Vector2) -> void:
	_safe_velocity = vel
	# Debug output when safe velocity is set
	if vel.length() > 0 and Engine.get_physics_frames() % 60 == 0:
		print("MovementComponent: Safe velocity set to: ", vel)

func _calculate_movement() -> void:
	var is_jumping: bool = state_manager.get_state_value("is_jumping")
	
	# Skip velocity calculation if jumping (jump component handles it)
	if is_jumping:
		return
	
	# Check if we're in pathfinding mode
	if player.movement_mode == "pathfinding":
		# In pathfinding mode, we use the safe velocity from the NavigationAgent
		# The safe velocity already has the correct speed and direction
		
		# Update has_input state based on whether we have a safe velocity
		state_manager.set_state_value("has_input", _safe_velocity.length() > 0.1)
		
		# Handle speed modifiers for pathfinding (aiming/shooting)
		var is_aiming: bool = state_manager.get_state_value("is_aiming")
		var is_shooting: bool = state_manager.get_state_value("is_shooting")
		
		# Calculate speed modifier
		var speed_modifier := 1.0
		if is_aiming or is_shooting:
			speed_modifier = AIM_SPEED_MULTIPLIER
			state_manager.set_state_value("is_running", false)
		else:
			# No running in pathfinding mode
			state_manager.set_state_value("is_running", false)
		
		# CRITICAL FIX: Use the safe velocity directly!
		# It already has the correct magnitude from the NavigationAgent2D
		# Just apply modifier if aiming/shooting
		if _safe_velocity.length() > 0:
			current_velocity = _safe_velocity * speed_modifier
		else:
			current_velocity = Vector2.ZERO
		
		# Track speed for animation purposes
		var effective_speed = _safe_velocity.length() * speed_modifier
		if abs(effective_speed - current_speed) > 0.1:
			current_speed = effective_speed
			speed_changed.emit(current_speed)
		
	else:
		# Direct control mode - original logic
		var input_dir := input_handler.get_movement_vector()
		var is_shift_pressed := input_handler.is_run_pressed()
		var is_aiming: bool = state_manager.get_state_value("is_aiming")
		var is_shooting: bool = state_manager.get_state_value("is_shooting")
		
		# Update has_input state
		state_manager.set_state_value("has_input", input_dir.length() > 0.1)
		
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
	# Return the current velocity which was properly calculated above
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
