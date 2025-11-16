extends CharacterBody2D
class_name PlayerController

## Main player controller that orchestrates all component systems
## This is the main script that should be attached to your player scene

# Component references
@onready var movement_component: MovementComponent = MovementComponent.new()
@onready var jump_component: JumpComponent = JumpComponent.new()
@onready var combat_component: CombatComponent = CombatComponent.new()
@onready var input_handler: InputHandler = InputHandler.new()
@onready var pathfinding_input_handler: PathfindingInputHandler = PathfindingInputHandler.new()
@onready var state_manager: StateManager = StateManager.new()
@onready var animation_controller: AnimationController = AnimationController.new()
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# CRITICAL FIX: Use @onready to get the NavigationAgent2D when the node is ready
@onready var nav_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")

# Movement mode: "direct" or "pathfinding"
var movement_mode: String = "pathfinding"

# Signals for external systems
signal player_moved(position: Vector2)
signal player_jumped()
signal player_landed()
signal player_shot(direction: String)
signal state_changed(new_state: Dictionary)

func _ready() -> void:
	# Initialize components with references they need
	_setup_components()
	_connect_signals()
	
	# Set up input handler according to initial movement mode
	set_movement_mode(movement_mode)
	
	# Initialize sprite
	animated_sprite.stop()
	animated_sprite.frame = 0
	y_sort_enabled = true
	
	# Debug: Verify NavigationAgent2D is found
	if nav_agent:
		print("PlayerController: NavigationAgent2D found and connected!")
		# Configure NavigationAgent2D settings
		nav_agent.path_desired_distance = 4.0
		nav_agent.target_desired_distance = 4.0
		nav_agent.avoidance_enabled = true
		nav_agent.max_speed = 275.0  # Match MovementComponent's SPEED
	else:
		push_error("PlayerController: NavigationAgent2D not found! Make sure it's a child of the player node.")

func _setup_components() -> void:
	# Add components as children for processing
	add_child(movement_component)
	add_child(jump_component)
	add_child(combat_component)
	add_child(input_handler)
	add_child(pathfinding_input_handler)
	add_child(state_manager)
	add_child(animation_controller)
	
	# Initialize components with necessary references
	movement_component.initialize(self, state_manager, input_handler)
	jump_component.initialize(self, state_manager, input_handler, animated_sprite)
	combat_component.initialize(self, state_manager, input_handler)
	animation_controller.initialize(animated_sprite, state_manager, combat_component)
	
	# Attach NavigationAgent2D to pathfinding_input_handler if present in scene tree
	if nav_agent:
		pathfinding_input_handler.set_navigation_agent(nav_agent)
		# Connect the velocity_computed signal
		if not nav_agent.velocity_computed.is_connected(_on_navigation_agent_velocity_computed):
			nav_agent.velocity_computed.connect(_on_navigation_agent_velocity_computed)
			print("PlayerController: Connected to NavigationAgent2D.velocity_computed signal")
	else:
		push_error("PlayerController: Cannot set navigation agent - nav_agent is null!")

	# Set initial position for jump component
	jump_component.set_base_position(global_position.y)

func _connect_signals() -> void:
	# Connect component signals
	movement_component.velocity_calculated.connect(_on_velocity_calculated)
	jump_component.jump_started.connect(_on_jump_started)
	jump_component.jump_landed.connect(_on_jump_landed)
	combat_component.weapon_fired.connect(_on_weapon_fired)
	state_manager.state_changed.connect(_on_state_changed)
	
	# Connect animation finished signal
	animated_sprite.animation_finished.connect(animation_controller._on_animation_finished)

func _on_navigation_agent_velocity_computed(safe_velocity: Vector2) -> void:
	# Debug output to verify this is being called
	if safe_velocity.length() > 0:
		print("PlayerController: Received safe velocity: ", safe_velocity)
	
	# When in pathfinding mode, pass the safe velocity to the movement component
	if movement_mode == "pathfinding":
		movement_component.set_safe_velocity(safe_velocity)

func _physics_process(delta: float) -> void:
	var start_position := global_position

	# Process input on the active handler
	if movement_mode == "direct":
		input_handler.update_input()
	elif movement_mode == "pathfinding":
		# This calls update_input in the handler, which calls agent.set_velocity()
		pathfinding_input_handler.update_input()
		# The agent calculates the safe velocity asynchronously,
		# which triggers _on_navigation_agent_velocity_computed()

	# Update combat (handles cooldowns and shooting state)
	combat_component.update(delta)

	# Process jumping
	jump_component.update(delta)

	# Process movement - this will now properly handle pathfinding mode
	movement_component.update(delta) 

	# Apply movement
	if state_manager.get_state_value("is_jumping"):
		velocity = jump_component.get_jump_momentum()
	else:
		# Get the velocity (properly calculated for both modes)
		velocity = movement_component.get_velocity()
		
		# Debug: Log velocity if moving
		if velocity.length() > 1.0 and Engine.get_physics_frames() % 30 == 0:  # Log every 0.5 seconds
			print("PlayerController: Current velocity: ", velocity, " | Position: ", global_position)
	
	# CRITICAL: Actually move the character!
	move_and_slide()

	# Check if actually moved
	var distance_moved := global_position.distance_to(start_position)
	state_manager.set_state_value("is_moving", distance_moved >= movement_component.MOVEMENT_THRESHOLD)

	# Update facing direction based on input
	var handler: BaseInputHandler
	
	if movement_mode == "direct":
		handler = input_handler
	else:
		handler = pathfinding_input_handler
		
	if handler.get_movement_vector().length() > 0.1:
		var direction_name := DirectionHelper.vector_to_direction_name(handler.get_movement_vector())
		if direction_name != "":
			state_manager.set_state_value("facing_direction", direction_name)

	# Update animation based on current state
	animation_controller.update_animation()

	# Emit movement signal if position changed
	if distance_moved > 0:
		player_moved.emit(global_position)

func _on_velocity_calculated(_vel: Vector2) -> void:
	# Movement component calculated new velocity
	pass

## Toggle between direct and pathfinding mode
func set_movement_mode(new_mode: String) -> void:
	if new_mode == movement_mode:
		return
	if new_mode == "direct":
		print("PlayerController: Exiting pathfinding mode, entering direct control mode")
		movement_component.input_handler = input_handler
		movement_mode = "direct"
		# Cancel any ongoing pathfinding
		pathfinding_input_handler.cancel_pathfinding()
	elif new_mode == "pathfinding":
		print("PlayerController: Entering pathfinding mode")
		movement_component.input_handler = pathfinding_input_handler
		movement_mode = "pathfinding"

## Mouse input: set destination in pathfinding mode
func _unhandled_input(event: InputEvent) -> void:
	if movement_mode == "pathfinding" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = get_global_mouse_position()
		print("PlayerController: Player requested pathfinding to (%.2f, %.2f)" % [click_pos.x, click_pos.y])
		pathfinding_input_handler.set_destination(click_pos)

func _on_jump_started() -> void:
	player_jumped.emit()
	state_manager.set_state_value("is_jumping", true)

func _on_jump_landed() -> void:
	player_landed.emit()
	state_manager.set_state_value("is_jumping", false)

func _on_weapon_fired(direction: String) -> void:
	player_shot.emit(direction)

func _on_state_changed(new_state: Dictionary) -> void:
	state_changed.emit(new_state)

## Debug function to print current state
func print_state() -> void:
	state_manager.print_state()
	print("Position: ", global_position)
	print("Velocity: ", velocity)
	print("Navigation Agent Status: ", "Connected" if nav_agent else "NOT FOUND!")
	if nav_agent and not nav_agent.is_navigation_finished():
		print("  Next path position: ", nav_agent.get_next_path_position())
		print("  Final position: ", nav_agent.get_final_position())
		print("  Distance to target: ", nav_agent.distance_to_target())
	combat_component.print_combat_state()
