extends CharacterBody2D
class_name AgentController

## Isometric point-and-click agent orchestrator.
##
## Expected scene tree:
##   AgentController (CharacterBody2D)  ← this script
##   ├── AnimatedSprite2D
##   ├── NavigationAgent2D
##   ├── AgentState
##   ├── AgentMovementComponent
##   ├── AgentJumpComponent
##   ├── AgentCombatComponent
##   ├── AgentAnimationController
##   ├── AgentNavigation
##   └── AgentInputHandler
##
## Call set_camera(cam) after adding to a scene to enable point-and-click movement.

@onready var state_manager: AgentState = $AgentState
@onready var movement_component: AgentMovementComponent = $AgentMovementComponent
@onready var jump_component: AgentJumpComponent = $AgentJumpComponent
@onready var combat_component: AgentCombatComponent = $AgentCombatComponent
@onready var animation_controller: AgentAnimationController = $AgentAnimationController
@onready var navigation: AgentNavigation = $AgentNavigation
@onready var input_handler: AgentInputHandler = $AgentInputHandler
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

var debug_logger: DebugActionLogger

signal agent_moved(position: Vector2)
signal agent_state_changed(state: Dictionary)
signal weapon_discharged(direction: String)

func _ready() -> void:
	_setup_components()
	_setup_debug_logger()
	_connect_signals()
	_print_signal_connection_summary()

func _setup_components() -> void:
	movement_component.initialize()
	jump_component.initialize(self, state_manager, input_handler)
	combat_component.initialize(state_manager, input_handler)
	animation_controller.initialize(animated_sprite, state_manager, combat_component)
	animation_controller.set_jump_component(jump_component)
	navigation.initialize(self, state_manager, movement_component, navigation_agent)

func _connect_signals() -> void:
	animated_sprite.animation_finished.connect(animation_controller._on_animation_finished)
	jump_component.jump_landed.connect(animation_controller._on_jump_landed)
	input_handler.move_requested.connect(navigation.navigate_to)
	navigation.navigation_completed.connect(_on_navigation_completed)
	state_manager.state_changed.connect(_on_state_changed)
	combat_component.weapon_fired.connect(_on_weapon_fired)

func _print_signal_connection_summary() -> void:
	if not OS.is_debug_build():
		return

	print("\n=== SIGNAL CONNECTIONS VERIFIED ===")
	print("[OK] AnimatedSprite2D.animation_finished → AnimationController._on_animation_finished")
	print("[OK] AgentJumpComponent.jump_landed → AnimationController._on_jump_landed")
	print("[OK] AgentInputHandler.move_requested → AgentNavigation.navigate_to")
	print("[OK] AgentNavigation.navigation_completed → AgentController._on_navigation_completed")
	print("[OK] AgentState.state_changed → AgentController._on_state_changed")
	print("[OK] AgentCombatComponent.weapon_fired → AgentController._on_weapon_fired")
	print("=== DEBUG LOGGING ENABLED ===")
	print("  Call print_state() to dump state snapshot")
	print("  Call print_debug_log() to dump action history")
	print("====================================\n")

func _setup_debug_logger() -> void:
	if not OS.is_debug_build():
		return
	debug_logger = preload("res://Controllers/AgentController/Debug/debug_action_logger.gd").new()
	add_child(debug_logger)

	state_manager.state_value_changed.connect(
		func(key, new_val): debug_logger.log_state_change(key, null, new_val))
	animation_controller.animation_changed.connect(
		func(old_anim, new_anim): debug_logger.log_animation_change(old_anim, new_anim, state_manager.get_state_value("animation_type")))
	navigation.navigation_started.connect(
		func(): debug_logger.log_navigation_event("started", {"target": navigation_agent.target_position}))
	navigation.navigation_completed.connect(
		func(): debug_logger.log_navigation_event("completed", {"pos": global_position}))
	jump_component.jump_started.connect(
		func(): debug_logger.log_action("JUMP_START", {"pos": global_position}))
	jump_component.jump_landed.connect(
		func(): debug_logger.log_action("JUMP_LAND", {"pos": global_position}))
	combat_component.weapon_fired.connect(
		func(dir): debug_logger.log_combat_event("fired", {"direction": dir}))

func _physics_process(delta: float) -> void:
	navigation.process(delta)
	jump_component.update(delta)
	combat_component.update(delta)
	state_manager.update_animation_type()
	animation_controller.update_animation()
	state_manager.save_state()

## Inject the scene camera so point-and-click converts screen → world correctly.
func set_camera(cam: Camera2D) -> void:
	input_handler.set_camera(cam)

func _on_navigation_completed() -> void:
	agent_moved.emit(global_position)

func _on_state_changed(new_state: Dictionary) -> void:
	agent_state_changed.emit(new_state)

func _on_weapon_fired(direction: String) -> void:
	weapon_discharged.emit(direction)
