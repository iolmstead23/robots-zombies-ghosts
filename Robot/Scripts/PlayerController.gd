# Robot/Scripts/PlayerController.gd
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
@onready var turn_based_controller: TurnBasedMovementController = TurnBasedMovementController.new()
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# CRITICAL FIX: Use @onready to get the NavigationAgent2D when the node is ready
@onready var nav_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")

# Movement mode: "direct", "pathfinding", or "hexnav"
var movement_mode: String = "hexnav"  # Default to hex navigation

# Hex Navigation Integration
var session_controller: SessionController
var current_navigation_target := Vector2.ZERO
var has_navigation_target := false

# Movement parameters for hex navigation
@export var hex_nav_speed := 200.0
@export var hex_nav_acceleration := 800.0

var use_turn_based: bool = true

# Signals for external systems
signal player_moved(position: Vector2)
signal player_jumped()
signal player_landed()
signal player_shot(direction: String)
signal state_changed(new_state: Dictionary)

func get_remaining_movement() -> float:
	"""Get remaining movement distance for this turn"""
	if use_turn_based:
		return turn_based_controller.pathfinder.MAX_MOVEMENT_DISTANCE - \
			   turn_based_controller.movement_used_this_turn
	else:
		return INF  # Unlimited in real-time mode
		
func _ready() -> void:
	# Initialize components with references they need
	_setup_components()
	_connect_signals()
	
	# Set up input handler according to initial movement mode
	set_movement_mode(movement_mode)
	
	# FIXED: Find SessionController in the scene tree (not as child of player)
	session_controller = _find_session_controller()
	
	if session_controller:
		print("PlayerController: SessionController found and connected!")
		session_controller.navigation_started.connect(_on_navigation_started)
		session_controller.waypoint_reached.connect(_on_waypoint_reached)
		session_controller.navigation_completed.connect(_on_navigation_completed)
		session_controller.navigation_cancelled.connect(_on_navigation_cancelled)
	else:
		push_warning("PlayerController: SessionController not found - hex navigation disabled")
	
	# Initialize turn-based controller
	add_child(turn_based_controller)
	turn_based_controller.initialize(self, movement_component, state_manager)
	
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
		push_warning("PlayerController: NavigationAgent2D not found - classic pathfinding disabled")

func _find_session_controller() -> SessionController:
	"""Find SessionController in the scene tree"""
	# Try common paths
	var paths := [
		"/root/Game/SessionController",
		"../SessionController",
		"/root/SessionController"
	]
	
	for path in paths:
		var controller = get_node_or_null(path)
		if controller and controller is SessionController:
			return controller
	
	# Search scene tree if not found
	return _find_node_by_type(get_tree().root, SessionController)

func _find_node_by_type(node: Node, type) -> Node:
	"""Recursively search for a node of specific type"""
	if is_instance_of(node, type):
		return node
	
	for child in node.get_children():
		var result = _find_node_by_type(child, type)
		if result:
			return result
	
	return null

# ============================================================================
# HEX NAVIGATION SIGNAL HANDLERS
# ============================================================================

func _on_navigation_started(target: Vector2) -> void:
	"""Called when hex navigation starts"""
	print("PlayerController: Hex navigation started to ", target)
	if session_controller:
		current_navigation_target = session_controller.get_current_waypoint()
		has_navigation_target = true
		
		# Update state
		state_manager.set_state_value("hex_navigating", true)

func _on_waypoint_reached(index: int, total: int) -> void:
	"""Called when reaching a waypoint in hex navigation"""
	print("PlayerController: Reached waypoint %d/%d" % [index + 1, total])
	if session_controller:
		current_navigation_target = session_controller.get_current_waypoint()
		
		# Emit player moved signal
		player_moved.emit(global_position)

func _on_navigation_completed() -> void:
	"""Called when hex navigation completes"""
	print("PlayerController: Hex navigation completed")
	has_navigation_target = false
	current_navigation_target = Vector2.ZERO
	state_manager.set_state_value("hex_navigating", false)
	
	# Return to idle
	state_manager.set_state_value("is_moving", false)

func _on_navigation_cancelled() -> void:
	"""Called when hex navigation is cancelled"""
	print("PlayerController: Hex navigation cancelled")
	has_navigation_target = false
	current_navigation_target = Vector2.ZERO
	state_manager.set_state_value("hex_navigating", false)
	state_manager.set_state_value("is_moving", false)

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event: InputEvent) -> void:
	"""Handle click-to-move for hex navigation"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Left-click: Navigate using hex grid
			if session_controller and movement_mode == "hexnav":
				var target = get_global_mouse_position()
				print("PlayerController: Requesting hex navigation to ", target)
				var success = session_controller.request_navigation(target)
				if not success:
					print("PlayerController: Navigation request failed")
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Right-click: Cancel navigation
			if session_controller:
				session_controller.cancel_navigation()

# ============================================================================
# TURN-BASED MODE HANDLERS
# ============================================================================

func _on_turn_movement_started() -> void:
	"""Handle the start of turn-based movement execution"""
	# Disable other controls during movement
	input_handler.set_process(false)
	combat_component.set_process(false)
	
	# Update state manager
	state_manager.set_state_value("is_moving", true)
	state_manager.set_state_value("turn_based_moving", true)
	
	# Disable regular movement modes
	set_physics_process(false)  # Temporarily disable regular physics processing
	
	print("Turn-based movement started")

func _on_turn_movement_completed(distance: float) -> void:
	"""Handle the completion of turn-based movement"""
	# Re-enable controls
	input_handler.set_process(true)
	combat_component.set_process(true)
	set_physics_process(true)  # Re-enable physics processing
	
	# Update state manager
	state_manager.set_state_value("is_moving", false)
	state_manager.set_state_value("turn_based_moving", false)
	
	# Update animation to idle
	animation_controller.update_animation()
	
	print("Movement completed: %.1f feet" % (distance / 32.0))
	
	# Emit player moved signal with final position
	player_moved.emit(global_position)

func _on_turn_ended(turn_number: int) -> void:
	"""Handle the end of a turn"""
	print("Turn %d ended" % turn_number)
	
	# Reset any turn-specific states
	state_manager.set_state_value("turn_number", turn_number)
	state_manager.set_state_value("can_act", false)  # Disable actions until next turn
	
	# You can trigger enemy turns or other turn-based logic here
	# For example:
	# enemy_manager.execute_enemy_turns()
	# environment_manager.process_environmental_effects()
	
	# After all other entities have acted, start the next turn
	# This could be triggered by a game manager or after enemies finish
	call_deferred("_start_next_turn")

func _start_next_turn() -> void:
	"""Start the next player turn (called after all entities have acted)"""
	# Wait a moment for visual clarity
	await get_tree().create_timer(0.5).timeout
	
	# Re-enable player actions
	state_manager.set_state_value("can_act", true)
	
	# Start new turn in the turn-based controller
	if use_turn_based:
		turn_based_controller.start_new_turn()
		print("Player's turn %d begins" % (turn_based_controller.current_turn + 1))

# ============================================================================
# COMPONENT SETUP
# ============================================================================
		
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
		push_warning("PlayerController: Cannot set navigation agent - nav_agent is null!")

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

# ============================================================================
# PHYSICS PROCESS
# ============================================================================

func _physics_process(delta: float) -> void:
	# Skip if turn-based movement is executing
	if use_turn_based and turn_based_controller.current_state == TurnBasedMovementController.TurnState.EXECUTING:
		return
		
	var start_position := global_position

	# Handle different movement modes
	match movement_mode:
		"hexnav":
			_process_hex_navigation(delta)
		"direct":
			input_handler.update_input()
		"pathfinding":
			pathfinding_input_handler.update_input()

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
		# Get the velocity (properly calculated for mode)
		if movement_mode == "hexnav" and has_navigation_target:
			velocity = _calculate_hex_nav_velocity(delta)
		else:
			velocity = movement_component.get_velocity()
		
		# Debug: Log velocity if moving
		if velocity.length() > 1.0 and Engine.get_physics_frames() % 30 == 0:  # Log every 0.5 seconds
			print("PlayerController: Current velocity: ", velocity, " | Position: ", global_position)
	
	# CRITICAL: Actually move the character!
	move_and_slide()

	# Check if actually moved
	var distance_moved := global_position.distance_to(start_position)
	state_manager.set_state_value("is_moving", distance_moved >= movement_component.MOVEMENT_THRESHOLD)

	# Update facing direction
	_update_facing_direction()

	# Update animation based on current state
	animation_controller.update_animation()

	# Emit movement signal if position changed
	if distance_moved > 0:
		player_moved.emit(global_position)

# ============================================================================
# HEX NAVIGATION MOVEMENT
# ============================================================================

func _process_hex_navigation(_delta: float) -> void:
	"""Process hex navigation waypoint following"""
	if not has_navigation_target or not session_controller:
		return
	
	# Check if we're close enough to the current waypoint
	var _distance_to_waypoint = global_position.distance_to(current_navigation_target)
	
	# Update SessionController's distance check (it handles waypoint progression)
	# The SessionController will call _on_waypoint_reached when appropriate

func _calculate_hex_nav_velocity(delta: float) -> Vector2:
	"""Calculate velocity for hex navigation movement"""
	if not has_navigation_target:
		return velocity.move_toward(Vector2.ZERO, hex_nav_acceleration * delta)
	
	var direction = (current_navigation_target - global_position).normalized()
	var distance = global_position.distance_to(current_navigation_target)
	
	# Slow down when approaching waypoint
	var target_speed = hex_nav_speed
	if distance < 50.0:
		target_speed = hex_nav_speed * (distance / 50.0)
	
	# Apply acceleration
	return velocity.move_toward(direction * target_speed, hex_nav_acceleration * delta)

func _update_facing_direction() -> void:
	"""Update facing direction based on movement"""
	var handler: BaseInputHandler
	
	match movement_mode:
		"direct":
			handler = input_handler
		"pathfinding":
			handler = pathfinding_input_handler
		"hexnav":
			# For hex nav, use velocity direction
			if has_navigation_target and velocity.length() > 0.1:
				var direction_name := DirectionHelper.vector_to_direction_name(velocity)
				if direction_name != "":
					state_manager.set_state_value("facing_direction", direction_name)
			return
	
	if handler and handler.get_movement_vector().length() > 0.1:
		var direction_name := DirectionHelper.vector_to_direction_name(handler.get_movement_vector())
		if direction_name != "":
			state_manager.set_state_value("facing_direction", direction_name)

# ============================================================================
# MOVEMENT MODE MANAGEMENT
# ============================================================================

func _on_velocity_calculated(_vel: Vector2) -> void:
	# Movement component calculated new velocity
	pass

## Toggle between movement modes: "direct", "pathfinding", or "hexnav"
func set_movement_mode(new_mode: String) -> void:
	if new_mode == movement_mode:
		return
	
	var old_mode = movement_mode
	movement_mode = new_mode
	
	# Handle mode transitions
	match old_mode:
		"pathfinding":
			pathfinding_input_handler.cancel_pathfinding()
		"hexnav":
			if session_controller:
				session_controller.cancel_navigation()
	
	# Setup new mode
	match new_mode:
		"direct":
			print("PlayerController: Switching to direct control mode")
			movement_component.input_handler = input_handler
		"pathfinding":
			print("PlayerController: Switching to classic pathfinding mode")
			movement_component.input_handler = pathfinding_input_handler
		"hexnav":
			print("PlayerController: Switching to hex navigation mode")
			# Hex nav doesn't use the movement_component's input handler
			movement_component.input_handler = null
		"none":
			print("PlayerController: Disabling movement")
			movement_component.input_handler = null

# ============================================================================
# INPUT HANDLING (ADVANCED)
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	# Toggle turn-based mode (T key)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			toggle_turn_based_mode()
			return
		
		# Toggle movement mode (M key for example)
		if event.keycode == KEY_M:
			_cycle_movement_mode()
			return
	
	# Let turn-based controller handle input when active
	if use_turn_based and turn_based_controller.is_active:
		return
	
	# Original pathfinding code for non-turn-based mode
	if movement_mode == "pathfinding" and not use_turn_based:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var click_pos = get_global_mouse_position()
			print("PlayerController: Regular pathfinding to (%.2f, %.2f)" % [click_pos.x, click_pos.y])
			pathfinding_input_handler.set_destination(click_pos)

func _cycle_movement_mode() -> void:
	"""Cycle through movement modes for testing"""
	match movement_mode:
		"direct":
			set_movement_mode("pathfinding")
		"pathfinding":
			set_movement_mode("hexnav")
		"hexnav":
			set_movement_mode("direct")
	
	print("PlayerController: Movement mode is now: ", movement_mode)

func toggle_turn_based_mode() -> void:
	"""Toggle between turn-based and real-time movement"""
	use_turn_based = !use_turn_based
	
	if use_turn_based:
		print("=== SWITCHING TO TURN-BASED MODE ===")
		# Disable regular pathfinding and hex nav
		if movement_mode == "pathfinding":
			pathfinding_input_handler.cancel_pathfinding()
		elif movement_mode == "hexnav" and session_controller:
			session_controller.cancel_navigation()
		
		set_movement_mode("none")  # Disable normal movement
		
		# CRITICAL: Actually activate the turn-based controller
		turn_based_controller.activate()
		
		print("Turn-based mode is now ACTIVE: ", turn_based_controller.is_active)
	else:
		print("=== SWITCHING TO REAL-TIME MODE ===")
		# Deactivate turn-based controller
		turn_based_controller.deactivate()
		
		# Re-enable normal movement (hex nav by default)
		set_movement_mode("hexnav")
		
		print("Turn-based mode is now INACTIVE: ", turn_based_controller.is_active)

# ============================================================================
# COMPONENT CALLBACKS
# ============================================================================
		
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

# ============================================================================
# DEBUG FUNCTIONS
# ============================================================================

## Debug function to print current state
func print_state() -> void:
	state_manager.print_state()
	print("Position: ", global_position)
	print("Velocity: ", velocity)
	print("Movement Mode: ", movement_mode)
	
	# Hex navigation state
	if movement_mode == "hexnav":
		print("Hex Navigation:")
		print("  SessionController: ", "Found" if session_controller else "NOT FOUND!")
		print("  Has Target: ", has_navigation_target)
		if has_navigation_target:
			print("  Target Position: ", current_navigation_target)
			print("  Distance to Target: ", global_position.distance_to(current_navigation_target))
		if session_controller:
			var info = session_controller.get_navigation_info()
			print("  Navigation Active: ", info.is_navigating)
			print("  Progress: %.1f%%" % (info.progress * 100.0))
	
	# Classic navigation state
	print("Navigation Agent Status: ", "Connected" if nav_agent else "NOT FOUND!")
	if nav_agent and not nav_agent.is_navigation_finished():
		print("  Next path position: ", nav_agent.get_next_path_position())
		print("  Final position: ", nav_agent.get_final_position())
		print("  Distance to target: ", nav_agent.distance_to_target())
	
	combat_component.print_combat_state()
