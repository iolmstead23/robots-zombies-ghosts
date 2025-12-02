extends Node
class_name NavAgent2DFollower

## Makes CharacterBody2D follow NavigationAgent2D target (REAL-TIME MODE)
##
## STATUS: DISABLED - This real-time navigation component is currently disabled
## The game uses turn-based movement via TurnBasedMovementController
## This code is preserved for future use when real-time navigation may be needed
##
## To enable real-time navigation:
## 1. Enable HexAgentNavigator in NavigationController
## 2. Attach this component to agents that need real-time movement
## 3. Call activate() to enable real-time following behavior
##
## Refactored to use Core components for better organization and reusability.

@export var movement_speed: int = MovementConstants.DEFAULT_REALTIME_SPEED
@export var rotation_speed: int = MovementConstants.DEFAULT_ROTATION_SPEED
@export var arrival_distance: int = MovementConstants.ARRIVAL_DISTANCE_PIXELS

var character_body: CharacterBody2D
var nav_agent: NavigationAgent2D
var is_active: bool = false

# Core components
var _movement_physics: MovementPhysics = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	if not get_parent() is CharacterBody2D:
		push_error("NavAgent2DFollower: Must be child of CharacterBody2D")
		return

	character_body = get_parent()
	nav_agent = character_body.get_node_or_null("NavigationAgent2D")

	if not nav_agent:
		push_error("NavAgent2DFollower: No NavigationAgent2D found")
		return

	# Initialize movement physics component
	_movement_physics = MovementPhysics.new()
	_movement_physics.movement_speed = movement_speed
	_movement_physics.rotation_speed = rotation_speed
	_movement_physics.arrival_distance = arrival_distance
	add_child(_movement_physics)

	# Configure nav agent
	_movement_physics.configure_nav_agent(nav_agent)

# ============================================================================
# ACTIVATION
# ============================================================================

func activate() -> void:
	is_active = true
	set_physics_process(true)

func deactivate() -> void:
	is_active = false
	set_physics_process(false)

	if character_body and _movement_physics:
		_movement_physics.stop_movement(character_body)

# ============================================================================
# PHYSICS
# ============================================================================

func _physics_process(_delta: float) -> void:
	if not is_active or not character_body or not nav_agent or not _movement_physics:
		return

	# Use Core movement physics to follow nav agent
	_movement_physics.follow_nav_agent(character_body, nav_agent)

# ============================================================================
# PUBLIC API
# ============================================================================

func set_target(target_position: Vector2) -> void:
	if nav_agent:
		nav_agent.target_position = target_position

func is_at_target() -> bool:
	if _movement_physics and nav_agent:
		return _movement_physics.is_nav_finished(nav_agent)
	return nav_agent.is_navigation_finished() if nav_agent else true

func get_distance_to_target() -> int:
	if not nav_agent or not character_body:
		return 0

	return DistanceCalculator.distance_between(
		character_body.global_position,
		nav_agent.target_position
	)
