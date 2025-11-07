extends CharacterBody2D

const SPEED = 300.0
const ANIM_SPEED = 4.5
const MOVEMENT_THRESHOLD_PERCENT = 0.1  # Percentage of expected movement to consider as actual movement (10%)

@onready var animated_sprite = $AnimatedSprite2D

var previous_position: Vector2
var jump_key_released = true  # Track if spacebar was released since last jump

# Comprehensive state tracking with facing direction included
var state_tags := {
	"has_input": false,      # Player is pressing movement keys
	"is_moving": false,      # Player position is actually changing
	"is_idle": true,         # Player is idle (no input and not moving)
	"is_walking": false,     # Player is walking (has input and moving)
	"is_jumping": false,     # Player is currently jumping
	"is_standing": true,     # Player is standing on the ground
	"facing_direction": "down",  # Current facing direction
	"animation_type": "idle",     # Current animation type (idle, walk, jump)
	"animation_name": "Idle_Down" # Current animation being played
}

# Previous state for comparison and caching
var previous_state_tags := {}

# Animation mappings organized by type
var animation_map := {
	"idle": {
		"up": "Idle_Up",
		"up_left": "Idle_UpLeft",
		"left": "Idle_Left",
		"down_left": "Idle_DownLeft",
		"down": "Idle_Down",
		"down_right": "Idle_DownRight",
		"right": "Idle_Right",
		"up_right": "Idle_UpRight"
	},
	"walk": {
		"up": "Walk_Up",
		"up_left": "Walk_UpLeft",
		"left": "Walk_Left",
		"down_left": "Walk_DownLeft",
		"down": "Walk_Down",
		"down_right": "Walk_DownRight",
		"right": "Walk_Right",
		"up_right": "Walk_UpRight"
	},
	"jump": {
		"up": "Jump_Up",
		"up_left": "Jump_UpLeft",
		"left": "Jump_Left",
		"down_left": "Jump_DownLeft",
		"down": "Jump_Down",
		"down_right": "Jump_DownRight",
		"right": "Jump_Right",
		"up_right": "Jump_UpRight"
	}
}

func _ready():
	# Start at idle frame
	animated_sprite.stop()
	animated_sprite.frame = 0
	
	previous_position = global_position
	previous_state_tags = state_tags.duplicate()
	
	# Enable Y-sorting for this node
	y_sort_enabled = true
	
	# Connect to animation finished signal for jump handling
	animated_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	# Store previous states for comparison
	previous_state_tags = state_tags.duplicate()
	var previous_pos = previous_position
	
	# Track spacebar release for jump input
	if not Input.is_action_pressed("ui_accept"):
		jump_key_released = true
	
	# Handle jump input (spacebar) - only when standing and key was released
	if Input.is_action_pressed("ui_accept") and state_tags["is_standing"] and jump_key_released:
		start_jump()
		jump_key_released = false  # Prevent holding spacebar
	
	# Process movement (skip if jumping to prevent movement during jump)
	if not state_tags["is_jumping"]:
		process_movement(delta, previous_pos)
	else:
		# Still update position tracking even when jumping
		previous_position = global_position
	
	# Determine current animation type based on state
	update_animation_type()
	
	# ALWAYS update animation every frame (continuous animation)
	update_animation()
	
	# Debug output when state changes
	if state_changed():
		print_debug_state()

func process_movement(delta: float, previous_pos: Vector2) -> void:
	# Get input
	var input_2d = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var movement_direction = Vector2(input_2d.x, input_2d.y)
	
	# Update has_input state
	state_tags["has_input"] = movement_direction != Vector2.ZERO
	
	# Update facing direction if there's input
	if state_tags["has_input"]:
		movement_direction = movement_direction.normalized()
		var new_direction = get_direction_name(movement_direction)
		if new_direction != "":  # Only update if we got a valid direction
			state_tags["facing_direction"] = new_direction
	
	# Set velocity based on input
	velocity = movement_direction * SPEED
	
	# Move and check for actual movement
	move_and_collide(velocity * delta)
	
	# Calculate expected vs actual movement
	var expected_movement = velocity.length() * delta
	var actual_movement = global_position.distance_to(previous_pos)
	
	# Determine if actually moving (with threshold)
	if expected_movement > 0:
		state_tags["is_moving"] = actual_movement >= (expected_movement * MOVEMENT_THRESHOLD_PERCENT)
	else:
		state_tags["is_moving"] = false
	
	# Update idle and walking states based on input and movement
	state_tags["is_walking"] = state_tags["has_input"] and state_tags["is_moving"]
	state_tags["is_idle"] = not state_tags["has_input"] and not state_tags["is_moving"]
	
	# Store current position for next frame
	previous_position = global_position

func update_animation_type() -> void:
	# Determine animation type based on priority
	# Jump has highest priority, then walk, then idle
	if state_tags["is_jumping"]:
		state_tags["animation_type"] = "jump"
	elif state_tags["is_walking"]:
		state_tags["animation_type"] = "walk"
	else:
		state_tags["animation_type"] = "idle"

func update_animation() -> void:
	# Get the animation name based on current type and direction
	var anim_type = state_tags["animation_type"]
	var direction = state_tags["facing_direction"]
	
	# Check if we have the animation for this type and direction
	if anim_type in animation_map and direction in animation_map[anim_type]:
		var animation_name = animation_map[anim_type][direction]
		
		# Update the animation name in state for tracking
		state_tags["animation_name"] = animation_name
		
		# Apply animation atomically - same pattern for all animation types
		apply_animation(animation_name)

func apply_animation(animation_name: String) -> void:
	# Unified animation application logic
	# This ensures all animations follow the same atomic design pattern
	
	# Check if we need to change the animation
	if animated_sprite.animation != animation_name:
		# Different animation needed - start it
		animated_sprite.play(animation_name, ANIM_SPEED)
		animated_sprite.frame = 0
	elif not animated_sprite.is_playing():
		# Animation stopped - only restart if it's NOT a jump animation
		# Jump animations should play once and stop (handled by _on_animation_finished)
		if state_tags["animation_type"] != "jump":
			# Restart looping animations (idle, walk)
			animated_sprite.play(animation_name, ANIM_SPEED)
		# For jump animations, let them stay stopped until state changes

func start_jump() -> void:
	# IMPORTANT: Jump animations MUST be set to non-looping in AnimatedSprite2D resource
	# Otherwise the animation will repeat and never trigger animation_finished signal
	
	# Update jump states
	state_tags["is_jumping"] = true
	state_tags["is_standing"] = false
	state_tags["is_idle"] = false
	state_tags["is_walking"] = false
	
	# Animation type will be updated in update_animation_type()
	# and the jump animation will be played in update_animation()
	
	print("Jump started - Direction: ", state_tags["facing_direction"])
	print("Jump animation loop setting should be FALSE for: Jump_", state_tags["facing_direction"])

func _on_animation_finished() -> void:
	# Debug: Show which animation finished
	print("Animation finished: ", animated_sprite.animation)
	
	# Only handle if we're in jumping state
	if state_tags["is_jumping"]:
		print("Jump animation finished, returning to standing")
		
		# Jump is complete, return to standing state
		state_tags["is_jumping"] = false
		state_tags["is_standing"] = true
		
		# Force an immediate animation update to transition out of jump
		update_animation_type()
		update_animation()
		
		print("Jump complete - Transitioned to: ", state_tags["animation_type"])

func get_direction_name(direction: Vector2) -> String:
	# Return empty string if no direction
	if direction.length() < 0.1:
		return ""
	
	# Convert the direction vector to one of 8 directions
	var angle = direction.angle()
	
	# Convert angle to degrees for easier understanding
	var degrees = rad_to_deg(angle)
	
	# Normalize to 0-360 range
	if degrees < 0:
		degrees += 360
	
	# Determine which of the 8 directions we're closest to
	# Each direction has a 45-degree range (360/8 = 45)
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
	else:  # 292.5 to 337.5
		return "up_right"

func state_changed() -> bool:
	# Check if any state has changed
	for key in state_tags:
		if state_tags[key] != previous_state_tags.get(key, null):
			return true
	return false

func print_debug_state() -> void:
	# Comprehensive state output for debugging and inspection
	var status = []
	
	# Build status array
	if state_tags["has_input"]:
		status.append("Input")
	if state_tags["is_moving"]:
		status.append("Moving")
	if state_tags["is_walking"]:
		status.append("Walking")
	if state_tags["is_jumping"]:
		status.append("Jumping")
	if state_tags["is_standing"]:
		status.append("Standing")
	if state_tags["is_idle"]:
		status.append("Idle")
	
	# Print comprehensive state information
	print("=== STATE DEBUG ===")
	print("Status: ", " + ".join(status) if status.size() > 0 else "None")
	print("Direction: ", state_tags["facing_direction"])
	print("Animation Type: ", state_tags["animation_type"])
	print("Animation Name: ", state_tags["animation_name"])
	print("Full State: ", state_tags)
	print("==================")

# Optional: Get current state as dictionary for external inspection
func get_current_state() -> Dictionary:
	# Return a copy of the current state for external systems to inspect
	return state_tags.duplicate()

# Optional: Get state history (if you want to track changes over time)
func get_state_diff() -> Dictionary:
	# Return what changed between previous and current state
	var diff = {}
	for key in state_tags:
		if state_tags[key] != previous_state_tags.get(key, null):
			diff[key] = {
				"previous": previous_state_tags.get(key, null),
				"current": state_tags[key]
			}
	return diff
