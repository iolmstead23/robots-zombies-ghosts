extends Node
class_name DirectionUtils

"""
Utility functions for direction calculations and normalization.

Design notes:
- Pure static utility functions for direction handling
- No state, no dependencies
- Used by movement and navigation components
"""

# ----------------------
# Direction Calculations
# ----------------------

## Calculate normalized direction from one point to another
static func direction_to(from: Vector2, to: Vector2) -> Vector2:
	var diff: Vector2 = to - from
	if diff.length_squared() < 0.0001: # Avoid division by zero
		return Vector2.ZERO
	return diff.normalized()

## Calculate direction with minimum distance threshold
static func direction_to_with_threshold(from: Vector2, to: Vector2, threshold: int = 1) -> Vector2:
	var diff: Vector2 = to - from
	if diff.length_squared() < threshold * threshold:
		return Vector2.ZERO
	return diff.normalized()

## Get angle in radians from one point to another
static func angle_to(from: Vector2, to: Vector2) -> float:
	return (to - from).angle()

## Get angle difference between two directions (returns smallest angle)
static func angle_difference(angle_a: float, angle_b: float) -> float:
	var diff: float = fmod(angle_b - angle_a, TAU)
	if diff > PI:
		diff -= TAU
	elif diff < -PI:
		diff += TAU
	return diff

# ----------------------
# Direction Normalization
# ----------------------

## Normalize a direction vector (safe, returns ZERO if invalid)
static func normalize_safe(direction: Vector2) -> Vector2:
	if direction.length_squared() < 0.0001:
		return Vector2.ZERO
	return direction.normalized()

## Clamp direction magnitude to a maximum value
static func clamp_magnitude(direction: Vector2, max_magnitude: float) -> Vector2:
	if direction.length_squared() > max_magnitude * max_magnitude:
		return direction.normalized() * max_magnitude
	return direction

# ----------------------
# Velocity Calculations
# ----------------------

## Calculate velocity vector toward a target at a given speed
static func velocity_toward(from: Vector2, to: Vector2, speed: int) -> Vector2:
	var dir: Vector2 = direction_to(from, to)
	return dir * speed

## Calculate velocity with arrival slowdown (slows down near target)
static func velocity_with_slowdown(from: Vector2, to: Vector2, speed: int, slowdown_distance: int = 50) -> Vector2:
	var distance: int = int(from.distance_to(to))
	var dir: Vector2 = direction_to(from, to)

	if distance < slowdown_distance:
		var slowdown_factor: float = float(distance) / float(slowdown_distance)
		return dir * speed * slowdown_factor

	return dir * speed

# ----------------------
# Rotation Utilities
# ----------------------

## Smoothly rotate from current angle toward target angle
static func rotate_toward(current_angle: float, target_angle: float, max_delta: float) -> float:
	var diff: float = angle_difference(current_angle, target_angle)

	if abs(diff) <= max_delta:
		return target_angle

	return current_angle + sign(diff) * max_delta

## Get the rotation needed to face a direction
static func rotation_to_direction(direction: Vector2) -> float:
	if direction.length_squared() < 0.0001:
		return 0.0
	return direction.angle()
