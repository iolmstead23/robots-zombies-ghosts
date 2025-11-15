extends Node
class_name BaseInputHandler

# Minimal input abstraction for both direct and pathfinding input handlers (for movement only)

func get_movement_vector() -> Vector2:
    return Vector2.ZERO

func is_run_pressed() -> bool:
    return false