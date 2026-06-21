extends Node
class_name AgentMovementComponent

## Velocity store and speed authority for the AgentController component system.
## AgentNavigation reads SPEED directly from this component to drive path-following calculations.

const SPEED := 275.0
const MOVEMENT_THRESHOLD := 1.0

var current_velocity := Vector2.ZERO

func initialize() -> void:
	pass

func get_velocity() -> Vector2:
	return current_velocity

func set_velocity(vel: Vector2) -> void:
	current_velocity = vel
