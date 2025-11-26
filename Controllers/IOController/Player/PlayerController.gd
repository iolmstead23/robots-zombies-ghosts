extends CharacterBody2D
class_name PlayerController

## Main player controller for turn-based hex navigation

# Components
@onready var movement_component: MovementComponent = MovementComponent.new()
@onready var jump_component: JumpComponent = JumpComponent.new()
@onready var combat_component: CombatComponent = CombatComponent.new()
@onready var state_manager: StateManager = StateManager.new()
@onready var animation_controller: AnimationController = AnimationController.new()
@onready var turn_based_controller: TurnBasedMovementController = TurnBasedMovementController.new()
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Hex navigation (set from main.gd)
var hex_grid: HexGrid
var hex_pathfinder: HexPathfinder

signal player_moved(position: Vector2)
signal player_jumped()
signal player_landed()
signal player_shot(direction: String)
signal state_changed(new_state: Dictionary)

func _ready() -> void:
	_setup_components()
	_connect_signals()
	_init_turn_based_controller()
	_init_sprite()

	if OS.is_debug_build():
		print("PlayerController: Initialized for hex navigation")

func _setup_components() -> void:
	add_child(movement_component)
	add_child(jump_component)
	add_child(combat_component)
	add_child(state_manager)
	add_child(animation_controller)

	movement_component.initialize(self, state_manager)
	jump_component.initialize(self, state_manager, animated_sprite)
	combat_component.initialize(self, state_manager, null)
	animation_controller.initialize(animated_sprite, state_manager, combat_component)

	jump_component.set_base_position(global_position.y)

func _init_turn_based_controller() -> void:
	add_child(turn_based_controller)
	turn_based_controller.initialize(self, movement_component, state_manager)

	turn_based_controller.movement_started.connect(_on_turn_movement_started)
	turn_based_controller.movement_completed.connect(_on_turn_movement_completed)
	turn_based_controller.turn_ended.connect(_on_turn_ended)

func _init_sprite() -> void:
	animated_sprite.stop()
	animated_sprite.frame = 0
	y_sort_enabled = true

func _connect_signals() -> void:
	movement_component.velocity_calculated.connect(_on_velocity_calculated)
	jump_component.jump_started.connect(_on_jump_started)
	jump_component.jump_landed.connect(_on_jump_landed)
	combat_component.weapon_fired.connect(_on_weapon_fired)
	state_manager.state_changed.connect(_on_state_changed)
	animated_sprite.animation_finished.connect(animation_controller._on_animation_finished)

func set_hex_navigation(grid: HexGrid, pathfinder: HexPathfinder) -> void:
	hex_grid = grid
	hex_pathfinder = pathfinder

	if turn_based_controller:
		turn_based_controller.set_hex_components(hex_grid, hex_pathfinder)

	if OS.is_debug_build():
		print("PlayerController: Hex navigation set")

func activate_turn_based_mode() -> void:
	turn_based_controller.activate()

	if OS.is_debug_build():
		print("PlayerController: Turn-based mode activated")

func _on_turn_movement_started() -> void:
	state_manager.set_state_value("is_moving", true)
	state_manager.set_state_value("turn_based_moving", true)

func _on_turn_movement_completed(distance: float) -> void:
	state_manager.set_state_value("is_moving", false)
	state_manager.set_state_value("turn_based_moving", false)
	animation_controller.update_animation()
	player_moved.emit(global_position)

	if OS.is_debug_build():
		print("PlayerController: Movement complete (%.1f ft)" % (distance / 32.0))

func _on_turn_ended(turn_number: int) -> void:
	state_manager.set_state_value("turn_number", turn_number)

	if OS.is_debug_build():
		print("PlayerController: Turn %d ended" % turn_number)

func _on_velocity_calculated(_vel: Vector2) -> void:
	pass

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

func print_state() -> void:
	if not OS.is_debug_build():
		return

	state_manager.print_state()
	print("Position: %s | Velocity: %s" % [global_position, velocity])
	combat_component.print_combat_state()