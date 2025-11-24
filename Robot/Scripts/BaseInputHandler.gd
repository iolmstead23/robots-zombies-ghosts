extends Node
class_name BaseInputHandler

## Base input abstraction for movement input handlers

func get_movement_vector() -> Vector2:
	return Vector2.ZERO

func is_run_pressed() -> bool:
	return false
