extends Object
class_name DirectionHelper

## Static utility class for 8-directional movement conversions

static func vector_to_direction_name(direction: Vector2) -> String:
	if direction.length() < 0.1:
		return ""

	var angle := direction.angle()
	var degrees := rad_to_deg(angle)

	if degrees < 0:
		degrees += 360

	# Each direction covers 45 degrees
	if degrees >= 337.5 or degrees < 22.5:
		return "right"
	elif degrees >= 22.5 and degrees < 67.5:
		return "down_right"
	elif degrees >= 67.5 and degrees < 112.5:
		return "down"
	elif degrees >= 112.5 and degrees < 157.5:
		return "down_left"
	elif degrees >= 157.5 and degrees < 202.5:
		return "left"
	elif degrees >= 202.5 and degrees < 247.5:
		return "up_left"
	elif degrees >= 247.5 and degrees < 292.5:
		return "up"
	else:
		return "up_right"

static func direction_name_to_vector(direction_name: String) -> Vector2:
	match direction_name:
		"right": return Vector2.RIGHT
		"down_right": return Vector2(1, 1).normalized()
		"down": return Vector2.DOWN
		"down_left": return Vector2(-1, 1).normalized()
		"left": return Vector2.LEFT
		"up_left": return Vector2(-1, -1).normalized()
		"up": return Vector2.UP
		"up_right": return Vector2(1, -1).normalized()
		_: return Vector2.DOWN

static func direction_name_to_degrees(direction_name: String) -> float:
	match direction_name:
		"right": return 0.0
		"down_right": return 45.0
		"down": return 90.0
		"down_left": return 135.0
		"left": return 180.0
		"up_left": return 225.0
		"up": return 270.0
		"up_right": return 315.0
		_: return 90.0

static func direction_name_to_radians(direction_name: String) -> float:
	return deg_to_rad(direction_name_to_degrees(direction_name))

static func get_opposite_direction(direction_name: String) -> String:
	match direction_name:
		"right": return "left"
		"down_right": return "up_left"
		"down": return "up"
		"down_left": return "up_right"
		"left": return "right"
		"up_left": return "down_right"
		"up": return "down"
		"up_right": return "down_left"
		_: return "up"

static func get_adjacent_directions(direction_name: String) -> Array:
	match direction_name:
		"right": return ["up_right", "down_right"]
		"down_right": return ["right", "down"]
		"down": return ["down_right", "down_left"]
		"down_left": return ["down", "left"]
		"left": return ["down_left", "up_left"]
		"up_left": return ["left", "up"]
		"up": return ["up_left", "up_right"]
		"up_right": return ["up", "right"]
		_: return []

static func are_directions_adjacent(dir1: String, dir2: String) -> bool:
	return dir2 in get_adjacent_directions(dir1)

static func get_direction_between_points(from: Vector2, to: Vector2) -> String:
	return vector_to_direction_name((to - from).normalized())

static func rotate_direction_clockwise(direction_name: String, steps: int = 1) -> String:
	const DIRECTIONS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
	var index := DIRECTIONS.find(direction_name)
	if index == -1:
		return direction_name
	return DIRECTIONS[(index + steps) % 8]

static func rotate_direction_counter_clockwise(direction_name: String, steps: int = 1) -> String:
	return rotate_direction_clockwise(direction_name, -steps)

static func get_all_directions() -> Array:
	return ["up", "up_right", "right", "down_right", "down", "down_left", "left", "up_left"]

static func get_cardinal_directions() -> Array:
	return ["up", "down", "left", "right"]

static func get_diagonal_directions() -> Array:
	return ["up_right", "down_right", "down_left", "up_left"]

static func is_cardinal_direction(direction_name: String) -> bool:
	return direction_name in get_cardinal_directions()

static func is_diagonal_direction(direction_name: String) -> bool:
	return direction_name in get_diagonal_directions()

static func snap_to_8_direction(vector: Vector2) -> Vector2:
	return direction_name_to_vector(vector_to_direction_name(vector))

static func get_angle_between_directions(dir1: String, dir2: String) -> float:
	var angle1 := direction_name_to_degrees(dir1)
	var angle2 := direction_name_to_degrees(dir2)
	var diff: int = abs(angle2 - angle1)
	return diff if diff <= 180 else 360 - diff
