extends BaseInputHandler
class_name PathfindingInputHandler

## Handles click-to-move pathfinding, producing movement vectors from NavigationAgent2D
## Only supports walking (no running/jumping/combat)

var agent: NavigationAgent2D      # Reference to NavigationAgent2D
var movement_vector := Vector2.ZERO      # Output movement vector (similar to InputHandler)
var destination: Vector2 = Vector2.ZERO  # Target point
var safe_movement_vector: Vector2 = Vector2.ZERO  # Store the final safe velocity once computed
var velocity_submitted := false  # Track if we've submitted velocity this frame

func _ready() -> void:
	# Find NavigationAgent2D if not assigned
	if agent == null:
		agent = get_parent().get_node_or_null("NavigationAgent2D")
		if agent:
			print("PathfindingInputHandler: Found NavigationAgent2D")
		else:
			push_error("PathfindingInputHandler: NavigationAgent2D not found as child of parent!")
	
	set_process(true)

	# Connect arrival signal if agent present
	if agent:
		if agent.has_signal("navigation_finished"):
			if not agent.navigation_finished.is_connected(_on_navigation_finished):
				agent.navigation_finished.connect(_on_navigation_finished)
				print("PathfindingInputHandler: Connected to navigation_finished signal")
		
		if not agent.velocity_computed.is_connected(_on_velocity_computed):
			agent.velocity_computed.connect(_on_velocity_computed)
			print("PathfindingInputHandler: Connected to velocity_computed signal")

func set_navigation_agent(a: NavigationAgent2D) -> void:
	agent = a
	print("PathfindingInputHandler: NavigationAgent2D set externally")
	
	# Re-connect signals if needed
	if agent:
		if agent.has_signal("navigation_finished") and not agent.navigation_finished.is_connected(_on_navigation_finished):
			agent.navigation_finished.connect(_on_navigation_finished)
		if not agent.velocity_computed.is_connected(_on_velocity_computed):
			agent.velocity_computed.connect(_on_velocity_computed)

func set_destination(point: Vector2) -> void:
	var was_active = agent and not agent.is_navigation_finished()
	destination = point
	print("PathfindingInputHandler: Player set new target to (%.2f, %.2f)" % [point.x, point.y])
	
	if agent:
		agent.set_target_position(destination)
		print("PathfindingInputHandler: NavigationAgent2D target set to (%.2f, %.2f)" % [destination.x, destination.y])
		
		# Debug: Check if navigation is actually starting
		if not agent.is_navigation_finished():
			print("PathfindingInputHandler: Navigation is active, path calculation started")
			print("  Current position: ", get_parent().global_position)
			print("  Distance to target: ", agent.distance_to_target())
		else:
			print("PathfindingInputHandler: WARNING - Navigation finished immediately (target might be too close or unreachable)")
		
		if was_active:
			print("PathfindingInputHandler: Path recalculated to (%.2f, %.2f)" % [destination.x, destination.y])
	else:
		push_error("PathfindingInputHandler: Cannot set destination - agent is null!")

func _process(_delta: float) -> void:
	# Update movement vector for direction calculation
	if agent and not agent.is_navigation_finished():
		var next_pos = agent.get_next_path_position()
		var curr_pos = get_parent().global_position
		var dir = next_pos - curr_pos
		
		if dir.length() > 0.1:
			movement_vector = dir.normalized()
		else:
			movement_vector = Vector2.ZERO
	else:
		movement_vector = Vector2.ZERO

## Called when NavigationAgent2D arrives at its target
func _on_navigation_finished() -> void:
	print("PathfindingInputHandler: Arrived at target (%.2f, %.2f)" % [destination.x, destination.y])
	movement_vector = Vector2.ZERO
	safe_movement_vector = Vector2.ZERO

## Cancel pathfinding (if called from game logic)
func cancel_pathfinding() -> void:
	if agent:
		agent.set_target_position(agent.global_position)
		print("PathfindingInputHandler: Pathfinding cancelled by player")
	destination = agent.global_position if agent else Vector2.ZERO
	movement_vector = Vector2.ZERO
	safe_movement_vector = Vector2.ZERO

## --- API: match InputHandler for walking movement only ---

func get_movement_vector() -> Vector2:
	return movement_vector

func is_run_pressed() -> bool:
	return false

func update_input() -> void:
	if not agent:
		push_error("PathfindingInputHandler: update_input called but agent is null!")
		return
	
	velocity_submitted = false
	
	if not agent.is_navigation_finished():
		var next_pos = agent.get_next_path_position()
		var curr_pos = get_parent().global_position
		var dir = curr_pos.direction_to(next_pos)
		
		# Use a base speed (this will be modified by MovementComponent based on states)
		var speed = 275.0  # Match the SPEED constant in MovementComponent
		var desired_velocity = dir * speed

		# CRITICAL: Submit your desired velocity to the NavigationAgent2D
		# It will process this and emit a 'velocity_computed' signal with a safe velocity.
		agent.set_velocity(desired_velocity)
		velocity_submitted = true
		
		# Debug output every second
		if Engine.get_physics_frames() % 60 == 0:
			print("PathfindingInputHandler: Submitting velocity: ", desired_velocity, 
				  " | Next pos: ", next_pos,
				  " | Distance: ", agent.distance_to_target())

		# Also update the movement_vector for direction purposes
		movement_vector = dir
	else:
		movement_vector = Vector2.ZERO
		safe_movement_vector = Vector2.ZERO
		# Clear agent velocity when not moving to stop RVO calculations
		if agent:
			agent.set_velocity(Vector2.ZERO)

# Callback to receive the safe velocity from NavigationAgent2D
func _on_velocity_computed(safe_velocity: Vector2) -> void:
	safe_movement_vector = safe_velocity
	
	# Debug output when velocity is computed
	if safe_velocity.length() > 0 and Engine.get_physics_frames() % 60 == 0:
		print("PathfindingInputHandler: Safe velocity computed: ", safe_velocity)
	
	# Note: We don't update movement_vector here because we want to keep
	# the normalized direction for facing/animation purposes
