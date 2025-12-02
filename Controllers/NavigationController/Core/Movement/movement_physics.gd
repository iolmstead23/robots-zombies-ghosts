extends Node
class_name MovementPhysics

"""
Handles physics-based movement for CharacterBody2D.

Design notes:
- Applies velocity and handles move_and_slide
- Provides smooth movement toward targets
- Configurable speed and arrival behavior
"""

# ----------------------
# Signals
# ----------------------

signal arrived_at_target()

# ----------------------
# Configuration
# ----------------------

var movement_speed: int = MovementConstants.DEFAULT_REALTIME_SPEED
var rotation_speed: int = MovementConstants.DEFAULT_ROTATION_SPEED
var arrival_distance: int = MovementConstants.ARRIVAL_DISTANCE_PIXELS

# ----------------------
# Movement Application
# ----------------------

## Move character body toward target position
func move_toward(body: CharacterBody2D, target: Vector2, delta: float, use_slowdown: bool = false) -> bool:
	if not body:
		return false

	var current_pos := body.global_position
	var distance := int(current_pos.distance_to(target))

	# Check arrival
	if distance < arrival_distance:
		stop_movement(body)
		arrived_at_target.emit()
		return true # Arrived

	# Calculate velocity
	var velocity: Vector2
	if use_slowdown:
		velocity = DirectionUtils.velocity_with_slowdown(current_pos, target, movement_speed, arrival_distance * 10.0)
	else:
		velocity = DirectionUtils.velocity_toward(current_pos, target, movement_speed)

	# Apply movement
	body.velocity = velocity
	body.move_and_slide()

	return false # Not arrived

## Move along NavigationAgent2D path
func follow_nav_agent(body: CharacterBody2D, nav_agent: NavigationAgent2D) -> bool:
	if not body or not nav_agent:
		return false

	if nav_agent.is_navigation_finished():
		stop_movement(body)
		arrived_at_target.emit()
		return true # Arrived

	var next_pos := nav_agent.get_next_path_position()
	var current_pos := body.global_position
	var direction := DirectionUtils.direction_to(current_pos, next_pos)

	body.velocity = direction * movement_speed
	body.move_and_slide()

	return false # Not arrived

## Stop movement
func stop_movement(body: CharacterBody2D) -> void:
	if not body:
		return

	body.velocity = Vector2.ZERO

# ----------------------
# Velocity Calculations
# ----------------------

## Calculate velocity toward target
func calculate_velocity_to_target(from: Vector2, to: Vector2, use_slowdown: bool = false) -> Vector2:
	if use_slowdown:
		return DirectionUtils.velocity_with_slowdown(from, to, movement_speed, arrival_distance * 10.0)
	else:
		return DirectionUtils.velocity_toward(from, to, movement_speed)

## Calculate direction to target
func calculate_direction_to_target(from: Vector2, to: Vector2) -> Vector2:
	return DirectionUtils.direction_to_with_threshold(from, to, arrival_distance)

# ----------------------
# Arrival Checks
# ----------------------

## Check if body is near target
func is_near_target(body: CharacterBody2D, target: Vector2) -> bool:
	if not body:
		return false

	return DistanceCalculator.is_near_arrival(body.global_position, target, arrival_distance)

## Check if NavigationAgent2D finished
func is_nav_finished(nav_agent: NavigationAgent2D) -> bool:
	return nav_agent.is_navigation_finished() if nav_agent else true

# ----------------------
# Configuration
# ----------------------

## Configure NavigationAgent2D for movement
func configure_nav_agent(nav_agent: NavigationAgent2D) -> void:
	if not nav_agent:
		return

	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = arrival_distance

## Set movement speed
func set_speed(speed: int) -> void:
	movement_speed = speed

## Set arrival distance
func set_arrival_distance(distance: int) -> void:
	arrival_distance = distance

# ----------------------
# Debug
# ----------------------

func get_physics_info() -> Dictionary:
	return {
		"movement_speed": movement_speed,
		"rotation_speed": rotation_speed,
		"arrival_distance": arrival_distance
	}
