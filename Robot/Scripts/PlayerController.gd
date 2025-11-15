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
	
	# Initialize sprite
	animated_sprite.stop()
	animated_sprite.frame = 0
	y_sort_enabled = true

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
	movement_component.initialize(self, state_manager, input_handler) # Default to direct control
	jump_component.initialize(self, state_manager, input_handler, animated_sprite)
	combat_component.initialize(self, state_manager, input_handler)
	animation_controller.initialize(animated_sprite, state_manager, combat_component)
	
	# Attach NavigationAgent2D to pathfinding_input_handler if present in scene tree
	var nav_agent = get_node_or_null("NavigationAgent2D")
	if nav_agent:
		pathfinding_input_handler.set_navigation_agent(nav_agent)

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

func _physics_process(delta: float) -> void:
	var start_position := global_position

	# Process input on the active handler
	if movement_mode == "direct":
		input_handler.update_input()
	elif movement_mode == "pathfinding":
		pathfinding_input_handler.update_input()

	# Update combat (handles cooldowns and shooting state)
	combat_component.update(delta)

	# Process jumping
	jump_component.update(delta)

	# Process movement
	movement_component.update(delta)

	# Apply movement
	if state_manager.get_state_value("is_jumping"):
		velocity = jump_component.get_jump_momentum()
	else:
		velocity = movement_component.get_velocity()
	
	move_and_collide(velocity * delta)

	# Check if actually moved
	var distance_moved := global_position.distance_to(start_position)
	state_manager.set_state_value("is_moving", distance_moved >= movement_component.MOVEMENT_THRESHOLD)

	# Update facing direction based on input
	var handler: BaseInputHandler = input_handler if movement_mode == "direct" else pathfinding_input_handler
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
	combat_component.print_combat_state()
