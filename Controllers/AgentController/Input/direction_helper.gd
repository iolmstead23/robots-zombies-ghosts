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
