extends CharacterBody2D

const SPEED = 300.0
const ANIM_SPEED = 4.5
const MOVEMENT_THRESHOLD_PERCENT = 0.1  # Percentage of expected movement to consider as actual movement (10%)

@onready var animated_sprite = $AnimatedSprite2D

var previous_position: Vector2
var current_direction = "down"  # Default starting direction
var previous_direction = "down"  # Track direction changes

# State tracking with previous states for caching
var state_tags := {
	"has_input": false,      # Player is pressing movement keys
	"is_moving": false,       # Player position is actually changing
	"is_animating": false,     # Animation is currently playing
	"is_idle":true
}

var previous_state_tags := state_tags;

func _ready():
	# Start at idle frame
	animated_sprite.stop()
	animated_sprite.frame = 0
	
	previous_position = global_position
	
	# Enable Y-sorting for this node
	y_sort_enabled = true

func _physics_process(delta: float) -> void:
	# Store previous states for comparison
	previous_state_tags = state_tags.duplicate()
	var previous_pos = previous_position
	
	# Get input
	var input_2d = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var movement_direction = Vector2(input_2d.x, input_2d.y)
	
	# Update has_input state
	state_tags["has_input"] = movement_direction != Vector2.ZERO
	
	# Update direction if there's input
	if state_tags["has_input"]:
		movement_direction = movement_direction.normalized()
		var new_direction = get_direction_name(movement_direction)
		if new_direction != "":  # Only update if we got a valid direction
			previous_direction = current_direction
			current_direction = new_direction
	
	# Set velocity based on input
	velocity = movement_direction * SPEED
	
	# Move and check for actual movement
	move_and_collide(velocity * delta)
	
	# Calculate expected movement distance
	var expected_movement = velocity.length() * delta
	
	# Calculate actual movement distance
	var actual_movement = global_position.distance_to(previous_pos)
	
	# Only consider moving if actual movement is at least MOVEMENT_THRESHOLD_PERCENT of expected
	if expected_movement > 0:
		state_tags["is_moving"] = actual_movement >= (expected_movement * MOVEMENT_THRESHOLD_PERCENT)
	else:
		state_tags["is_moving"] = false
	
	# Update animation state based on actual movement and input
	# Player should animate if: has input AND is actually moving
	var should_animate = state_tags["has_input"] and state_tags["is_moving"]
	
	# Only update animation if state changed
	if should_animate != previous_state_tags["is_animating"] or \
	   (should_animate and current_direction != previous_direction):
		state_tags["is_animating"] = should_animate
		update_animation()
	else:
		state_tags["is_animating"] = should_animate
	
	# Store current position for next frame
	previous_position = global_position
	
	# Debug output (optional - remove in production)
	if state_changed():
		print_debug_state()

func state_changed() -> bool:
	# Check if any state has changed
	for key in state_tags:
		if state_tags[key] != previous_state_tags.get(key, null):
			return true
	return current_direction != previous_direction

func print_debug_state():
	var status = []
	if state_tags["has_input"]:
		status.append("Input")
	if state_tags["is_moving"]:
		status.append("Moving")
	if state_tags["is_animating"]:
		status.append("Animating")
	
	if status.size() > 0:
		print("State: ", " + ".join(status), " | Direction: ", current_direction)
	else:
		print("State: Idle")

func update_animation():
	if state_tags["is_animating"]:
		play_walking_animation()
	else:
		play_idle_animation()

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

func play_walking_animation():
	var sprite_names = {
		"up": "Walk_Up",
		"up_left": "Walk_UpLeft",
		"left": "Walk_Left",
		"down_left": "Walk_DownLeft",
		"down": "Walk_Down",
		"down_right": "Walk_DownRight",
		"right": "Walk_Right",
		"up_right": "Walk_UpRight"
	}
	
	if current_direction not in sprite_names:
		return
		
	var animate_direction = sprite_names[current_direction]

	# Only change animation if it's different or not playing
	if animated_sprite.animation != animate_direction:
		animated_sprite.play(animate_direction, ANIM_SPEED)
		animated_sprite.frame = 0
	elif not animated_sprite.is_playing():
		# If the animation was stopped, restart it
		animated_sprite.play(animate_direction, ANIM_SPEED)

func play_idle_animation():
	var sprite_names = {
		"up": "Idle_Up",
		"up_left": "Idle_UpLeft",
		"left": "Idle_Left",
		"down_left": "Idle_DownLeft",
		"down": "Idle_Down",
		"down_right": "Idle_DownRight",
		"right": "Idle_Right",
		"up_right": "Idle_UpRight"
	}
	
	if current_direction not in sprite_names:
		return
		
	var animate_direction = sprite_names[current_direction]

	# Only change animation if it's different or not playing
	if animated_sprite.animation != animate_direction:
		animated_sprite.play(animate_direction, ANIM_SPEED)
		animated_sprite.frame = 0
	elif not animated_sprite.is_playing():
		# If the animation was stopped, restart it
		animated_sprite.play(animate_direction, ANIM_SPEED)

func stop_animation():
	# Stop the animation and return to frame 0 (idle frame)
	animated_sprite.stop()
	animated_sprite.frame = 0
