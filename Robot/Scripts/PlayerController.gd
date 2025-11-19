# Controllers/PlayerController.gd
extends CharacterBody2D
class_name PlayerController

## Robot player controller that integrates hex grid navigation
## Handles movement using NavigationAgent2D with hex grid waypoints

# Movement parameters
@export var movement_speed := 150.0
@export var rotation_speed := 5.0
@export var acceleration := 500.0
@export var stopping_distance := 5.0

# Navigation components
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var session_controller: SessionController = get_node_or_null("/root/Node2D/SessionController")

# State tracking
var current_target := Vector2.ZERO
var is_moving := false
var velocity_direction := Vector2.ZERO
var navigation_active := false

# Debug
@export var debug_mode := true
@export var draw_target := true
@export var target_color := Color.GREEN
@export var target_radius := 5.0

signal movement_started()
signal movement_stopped()
signal target_reached()

func _ready() -> void:
	# Ensure we have a NavigationAgent2D
	if not navigation_agent:
		navigation_agent = get_node_or_null("NavigationAgent2D")
		if not navigation_agent:
			push_error("PlayerController: NavigationAgent2D not found!")
			return
	
	# Configure NavigationAgent2D for hex grid navigation
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = stopping_distance
	navigation_agent.path_max_distance = 8.0
	navigation_agent.navigation_layers = 1
	navigation_agent.avoidance_enabled = true
	navigation_agent.radius = 8.0  # Adjust based on robot size
	navigation_agent.max_speed = movement_speed
	
	# Connect signals
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	navigation_agent.navigation_finished.connect(_on_navigation_finished)
	navigation_agent.target_reached.connect(_on_target_reached)
	
	if debug_mode:
		print("PlayerController: NavigationAgent2D found and connected!")
	
	# Connect to SessionController if available
	if session_controller:
		if debug_mode:
			print("PlayerController: SessionController found and connected!")

func _physics_process(delta: float) -> void:
	if not navigation_active or not navigation_agent:
		return
	
	# Check if we've reached the target
	var distance_to_target = global_position.distance_to(current_target)
	if distance_to_target < stopping_distance:
		stop_navigation()
		return
	
	# Get the next navigation point
	var next_path_position: Vector2 = navigation_agent.get_next_path_position()
	
	# Calculate velocity toward the next point
	var direction = (next_path_position - global_position).normalized()
	velocity_direction = direction
	
	# Set desired velocity for avoidance system
	var desired_velocity = direction * movement_speed
	
	if navigation_agent.avoidance_enabled:
		navigation_agent.set_velocity(desired_velocity)
	else:
		velocity = velocity.move_toward(desired_velocity, acceleration * delta)
		_apply_movement()
	
	# Rotate to face movement direction
	if velocity.length() > 10:
		var target_rotation = velocity.angle() + PI/2  # Adjust based on sprite orientation
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
	
	# Debug visualization
	if debug_mode and draw_target:
		queue_redraw()

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	# This is called when NavigationAgent2D computes a safe velocity avoiding obstacles
	velocity = safe_velocity
	_apply_movement()
	
	if debug_mode and randf() < 0.05:  # Only log 5% of the time to reduce spam
		print("PlayerController: Moving with velocity: ", velocity)

func _apply_movement() -> void:
	# Apply the movement
	move_and_slide()
	
	# Track if we're actually moving
	var was_moving = is_moving
	is_moving = velocity.length() > 10
	
	if is_moving and not was_moving:
		movement_started.emit()
	elif not is_moving and was_moving:
		movement_stopped.emit()

## Set navigation target (called by SessionController)
func set_navigation_target(target: Vector2) -> void:
	if not navigation_agent:
		push_error("PlayerController: Cannot set target - NavigationAgent2D not found")
		return
	
	current_target = target
	navigation_active = true
	
	# Set the NavigationAgent2D target
	navigation_agent.target_position = target
	
	if debug_mode:
		print("PlayerController: Navigation target set to ", target)
		print("  Distance to target: %.1f" % global_position.distance_to(target))

## Alternative method name for compatibility
func set_destination(target: Vector2) -> void:
	set_navigation_target(target)

## Stop navigation
func stop_navigation() -> void:
	navigation_active = false
	velocity = Vector2.ZERO
	is_moving = false
	
	if debug_mode:
		print("PlayerController: Navigation stopped")
	
	movement_stopped.emit()
	target_reached.emit()

## Cancel pathfinding (called by SessionController)
func cancel_pathfinding() -> void:
	stop_navigation()
	current_target = Vector2.ZERO
	
	if debug_mode:
		print("PlayerController: Pathfinding cancelled")

func _on_navigation_finished() -> void:
	if debug_mode:
		print("PlayerController: NavigationAgent2D reports navigation finished")
	stop_navigation()

func _on_target_reached() -> void:
	if debug_mode:
		print("PlayerController: NavigationAgent2D reports target reached")
	target_reached.emit()

func _draw() -> void:
	if not draw_target or not navigation_active:
		return
	
	# Draw target position
	var local_target = to_local(current_target)
	draw_circle(local_target, target_radius, target_color)
	draw_circle(local_target, target_radius * 0.5, Color.WHITE)
	
	# Draw line to target
	draw_line(Vector2.ZERO, local_target, target_color.darkened(0.3), 2.0)
	
	# Draw next navigation point
	if navigation_agent:
		var next_point = to_local(navigation_agent.get_next_path_position())
		draw_circle(next_point, target_radius * 0.7, Color.YELLOW)

## Get current movement state
func is_navigating() -> bool:
	return navigation_active

## Get distance to current target
func get_distance_to_target() -> float:
	if not navigation_active:
		return 0.0
	return global_position.distance_to(current_target)

## Force stop with deceleration
func force_stop() -> void:
	navigation_active = false
	velocity = velocity.move_toward(Vector2.ZERO, acceleration * get_physics_process_delta_time())
	move_and_slide()

## Emergency stop (immediate)
func emergency_stop() -> void:
	navigation_active = false
	velocity = Vector2.ZERO
	is_moving = false
	movement_stopped.emit()

## Update navigation configuration
func configure_navigation(config: Dictionary) -> void:
	if not navigation_agent:
		return
	
	if config.has("path_desired_distance"):
		navigation_agent.path_desired_distance = config["path_desired_distance"]
	if config.has("target_desired_distance"):
		navigation_agent.target_desired_distance = config["target_desired_distance"]
	if config.has("avoidance_enabled"):
		navigation_agent.avoidance_enabled = config["avoidance_enabled"]
	if config.has("max_speed"):
		navigation_agent.max_speed = config["max_speed"]
		movement_speed = config["max_speed"]
