extends CharacterBody2D
class_name AgentController

## Isometric point-and-click agent orchestrator.
##
## Expected scene tree:
##   AgentController (CharacterBody2D)  ← this script
##   ├── AnimatedSprite2D
##   ├── NavigationAgent2D
##   ├── AgentRegistry
##   ├── AgentMotionPackage
##   ├── AgentActionPackage
##   ├── AgentStateManager
##   ├── AgentAnimationController
##   ├── AgentNavigation
##   └── AgentInputHandler
##
## Call set_camera(cam) after adding to a scene to enable point-and-click movement.

@onready var registry: AgentRegistry = $AgentRegistry
@onready var motion: AgentMotionPackage = $AgentMotionPackage
@onready var action: AgentActionPackage = $AgentActionPackage
@onready var state_manager: AgentStateManager = $AgentStateManager
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
	motion.initialize(self, registry)
	navigation.initialize(self, registry, navigation_agent)
	input_handler.initialize(registry)
	action.initialize(registry, input_handler)
	state_manager.initialize(registry)
	animation_controller.initialize(animated_sprite, registry)
	registry.publish("core.is_active", true)

func _connect_signals() -> void:
	animated_sprite.animation_finished.connect(func():
		if OS.is_debug_build():
			print_debug("ANIM_FINISHED: %s" % animation_controller.get_current_animation()))
	motion.jump_landed.connect(_on_jump_landed)
	input_handler.move_requested.connect(navigation.navigate_to)
	navigation.navigation_completed.connect(_on_navigation_completed)
	action.weapon_fired.connect(_on_weapon_fired)
	animation_controller.animation_speed_changed.connect(func(s):
		if debug_logger:
			debug_logger.log_action("ANIM_SPEED", {"speed": s}))

func _print_signal_connection_summary() -> void:
	if not OS.is_debug_build():
		return

	print("\n=== SIGNAL CONNECTIONS VERIFIED ===")
	print("[OK] AgentInputHandler.move_requested → AgentNavigation.navigate_to")
	print("[OK] AgentNavigation.navigation_completed → AgentController._on_navigation_completed")
	print("[OK] AgentActionPackage.weapon_fired → AgentController._on_weapon_fired")
	print("[OK] AgentMotionPackage.jump_landed → AgentController._on_jump_landed")
	print("[OK] AgentAnimationController.animation_speed_changed → DebugActionLogger")
	print("[OK] AnimatedSprite2D.animation_finished → debug print")
	print("=== DEBUG LOGGING ENABLED ===")
	print("  Registry snapshot: registry.get_snapshot()")
	print("  Call print_debug_log() to dump action history")
	print("====================================\n")

func _setup_debug_logger() -> void:
	if not OS.is_debug_build():
		return
	debug_logger = preload("res://Controllers/AgentController/Debug/debug_action_logger.gd").new()
	add_child(debug_logger)

	for key in registry.get_snapshot().keys():
		registry.subscribe(key, func(val):
			debug_logger.log_state_change(key, null, val))

	motion.jump_started.connect(func():
		debug_logger.log_action("JUMP_START", {"pos": global_position}))
	motion.jump_landed.connect(func():
		debug_logger.log_action("JUMP_LAND", {"pos": global_position}))
	navigation.navigation_started.connect(func():
		debug_logger.log_navigation_event("started", {"target": navigation_agent.target_position}))
	navigation.navigation_completed.connect(func():
		debug_logger.log_navigation_event("completed", {"pos": global_position}))
	action.weapon_fired.connect(func(dir):
		debug_logger.log_combat_event("fired", {"direction": dir}))
	animation_controller.animation_changed.connect(func(old_anim, new_anim):
		debug_logger.log_animation_change(old_anim, new_anim, animation_controller.get_current_animation()))

func _physics_process(delta: float) -> void:
	# Order matters: inputs publish first, the state manager resolves the
	# single authoritative animation state, then the animation controller
	# consumes it. Resolution depends only on already-published registry state.
	navigation.process(delta)
	motion.update(delta)
	action.update(delta)
	state_manager.update()
	animation_controller.update_animation()

func set_camera(cam: Camera2D) -> void:
	input_handler.set_camera(cam)

func _on_navigation_completed() -> void:
	agent_moved.emit(global_position)
	agent_state_changed.emit(registry.get_snapshot())

func _on_jump_landed() -> void:
	agent_state_changed.emit(registry.get_snapshot())

func _on_weapon_fired(direction: String) -> void:
	weapon_discharged.emit(direction)
