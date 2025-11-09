extends CharacterBody2D

# Movement constants
const SPEED = 275.0
const RUN_SPEED_MULTIPLIER = 1.5
const ANIM_SPEED = 4.5
const MOVEMENT_THRESHOLD = 1.0  # Minimum pixels moved to consider as "moving"

# Jump constants
const GRAVITY = 980.0
const JUMP_STRENGTH = 175.0
const MAX_FALL_SPEED = 600.0

@onready var animated_sprite = $AnimatedSprite2D

# Position tracking for movement detection
var previous_position: Vector2 = Vector2.ZERO

# Jump physics
var y_offset: float = 0.0
var vertical_velocity: float = 0.0
var jump_momentum: Vector2 = Vector2.ZERO
var base_y_position: float = 0.0
var was_running_when_jumped: bool = false
var jump_key_released: bool = true

# Current state - single source of truth
var state := {
	"facing_direction": "down",
	"is_moving": false,          # Actually changing position
	"has_input": false,          # Pressing movement keys
	"is_running": false,         # Running (shift + moving)
	"is_jumping": false,         # In air
	"animation_type": "idle"     # Current animation category
}

# Cached previous state for change detection
var prev_state := {}

# Animation mappings
var animations := {
	"idle": {
		"up": "Idle_Up", "up_left": "Idle_UpLeft", "left": "Idle_Left",
		"down_left": "Idle_DownLeft", "down": "Idle_Down", "down_right": "Idle_DownRight",
		"right": "Idle_Right", "up_right": "Idle_UpRight"
	},
	"walk": {
		"up": "Walk_Up", "up_left": "Walk_UpLeft", "left": "Walk_Left",
		"down_left": "Walk_DownLeft", "down": "Walk_Down", "down_right": "Walk_DownRight",
		"right": "Walk_Right", "up_right": "Walk_UpRight"
	},
	"run": {
		"up": "Run_Up", "up_left": "Run_UpLeft", "left": "Run_Left",
		"down_left": "Run_DownLeft", "down": "Run_Down", "down_right": "Run_DownRight",
		"right": "Run_Right", "up_right": "Run_UpRight"
	},
	"jump": {
		"up": "Jump_Up", "up_left": "Jump_UpLeft", "left": "Jump_Left",
		"down_left": "Jump_DownLeft", "down": "Jump_Down", "down_right": "Jump_DownRight",
		"right": "Jump_Right", "up_right": "Jump_UpRight"
	},
	"run_jump": {
		"up": "RunJump_Up", "up_left": "RunJump_UpLeft", "left": "RunJump_Left",
		"down_left": "RunJump_DownLeft", "down": "RunJump_Down", "down_right": "RunJump_DownRight",
		"right": "RunJump_Right", "up_right": "RunJump_UpRight"
	}
}

func _ready() -> void:
	animated_sprite.stop()
	animated_sprite.frame = 0
	previous_position = global_position
	base_y_position = global_position.y
	y_sort_enabled = true
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Initialize cached state
	prev_state = state.duplicate()

func _physics_process(delta: float) -> void:
	# Cache previous state for comparison
	prev_state = state.duplicate()
	var start_position = global_position
	
	# Handle jump input
	if not Input.is_action_pressed("ui_accept"):
		jump_key_released = true
	
	if Input.is_action_pressed("ui_accept") and not state.is_jumping and jump_key_released:
		_start_jump()
		jump_key_released = false
	
	# Update jump physics
	if state.is_jumping:
		_process_jump_physics(delta)
	
	# Process horizontal movement
	_process_movement(delta)
	
	# Determine if player actually moved
	var distance_moved = global_position.distance_to(start_position)
	state.is_moving = distance_moved >= MOVEMENT_THRESHOLD
	
	# Update sprite vertical offset for jump
	animated_sprite.position.y = -y_offset
	
	# Update state and animation if anything changed
	_update_state()
	_update_animation()

func _process_movement(_delta: float) -> void:
	# Get input direction
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var is_shift_pressed = Input.is_action_pressed("ui_run")
	
	# Update input state
	state.has_input = input_dir.length() > 0.1
	
	# Update facing direction when there's input
	if state.has_input:
		var new_direction = _get_direction_name(input_dir.normalized())
		if new_direction != "":
			state.facing_direction = new_direction
	
	# Calculate velocity
	if state.is_jumping:
		# Use preserved jump momentum
		velocity = jump_momentum
	else:
		# Normal movement
		var speed = SPEED * RUN_SPEED_MULTIPLIER if is_shift_pressed else SPEED
		velocity = input_dir.normalized() * speed if state.has_input else Vector2.ZERO
	
	# Move the character
	move_and_slide()

func _process_jump_physics(delta: float) -> void:
	# Apply gravity
	vertical_velocity -= GRAVITY * delta
	vertical_velocity = max(vertical_velocity, -MAX_FALL_SPEED)
	
	# Update vertical offset
	y_offset += vertical_velocity * delta
	
	# Check for landing
	if y_offset <= 0.0:
		_land_from_jump()

func _start_jump() -> void:
	was_running_when_jumped = state.is_running
	jump_momentum = velocity
	vertical_velocity = JUMP_STRENGTH
	state.is_jumping = true

func _land_from_jump() -> void:
	y_offset = 0.0
	vertical_velocity = 0.0
	state.is_jumping = false
	jump_momentum = Vector2.ZERO
	was_running_when_jumped = false

func _update_state() -> void:
	# Determine animation type based on current state
	if state.is_jumping:
		state.animation_type = "run_jump" if was_running_when_jumped else "jump"
		state.is_running = false
	elif state.is_moving:
		# Only show run/walk animations if actually moving
		if state.has_input and Input.is_action_pressed("ui_run"):
			state.animation_type = "run"
			state.is_running = true
		elif state.has_input:
			state.animation_type = "walk"
			state.is_running = false
		else:
			# Moving but no input (sliding/momentum)
			state.animation_type = "idle"
			state.is_running = false
	else:
		# Not moving at all
		state.animation_type = "idle"
		state.is_running = false

func _update_animation() -> void:
	# Only update animation if state actually changed
	if not _state_changed():
		return
	
	var anim_type = state.animation_type
	var direction = state.facing_direction
	
	# Get animation name from mapping
	if anim_type in animations and direction in animations[anim_type]:
		var anim_name = animations[anim_type][direction]
		
		# Only change animation if it's different
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name, ANIM_SPEED)
			animated_sprite.frame = 0
		elif not animated_sprite.is_playing():
			# Restart animation if it stopped (but not for jump animations)
			if not state.is_jumping:
				animated_sprite.play(anim_name, ANIM_SPEED)

func _get_direction_name(direction: Vector2) -> String:
	if direction.length() < 0.1:
		return ""
	
	var angle = direction.angle()
	var degrees = rad_to_deg(angle)
	
	# Normalize to 0-360
	if degrees < 0:
		degrees += 360
	
	# Map to 8 directions
	if degrees >= 337.5 or degrees < 22.5:
		return "right"
	elif degrees >= 22.5 and degrees < 67.5:
		return "down_right"
	elif degrees >= 67.5 and degrees < 112.5:
		return "down"
	elif degrees >= 112.5 and degrees < 157.5:
		return "down_left"
	elif degrees >= 157.5 and degrees < 202.5:
		return "left"
	elif degrees >= 202.5 and degrees < 247.5:
		return "up_left"
	elif degrees >= 247.5 and degrees < 292.5:
		return "up"
	else:
		return "up_right"

func _state_changed() -> bool:
	# Check if any state property changed
	for key in state:
		if state[key] != prev_state.get(key):
			return true
	return false

func _on_animation_finished() -> void:
	# Handle jump animation completion if needed
	pass

# Debug helper - call this to see current state
func print_state() -> void:
	print("=== Player State ===")
	print("Position: ", global_position)
	print("Is Moving: ", state.is_moving)
	print("Has Input: ", state.has_input)
	print("Is Running: ", state.is_running)
	print("Is Jumping: ", state.is_jumping)
	print("Direction: ", state.facing_direction)
	print("Animation: ", state.animation_type)
	print("Current Anim: ", animated_sprite.animation)
	print("==================")
