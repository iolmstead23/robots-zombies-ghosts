extends Node
class_name MovementComponent

## Simplified movement component for turn-based hex navigation

const SPEED := 275.0
const MOVEMENT_THRESHOLD := 1.0

var player: CharacterBody2D
var state_manager: StateManager
var current_velocity := Vector2.ZERO

signal velocity_calculated(velocity: Vector2)

func initialize(player_ref: CharacterBody2D, state_ref: StateManager) -> void:
	player = player_ref
	state_manager = state_ref

	if OS.is_debug_build():
		print("MovementComponent: Initialized for hex navigation")

func get_velocity() -> Vector2:
	return current_velocity

func set_velocity(vel: Vector2) -> void:
	current_velocity = vel
	velocity_calculated.emit(current_velocity)

func is_moving() -> bool:
	return current_velocity.length() > MOVEMENT_THRESHOLD

func update_direction(direction: Vector2) -> void:
	"""Update movement direction (for animation/facing direction)"""
	if state_manager != null and direction.length() > 0.1:
		var direction_name := DirectionHelper.vector_to_direction_name(direction)
		if direction_name != "":
			state_manager.set_state_value("facing_direction", direction_name)