class_name PathSmootherBase
extends RefCounted

# Abstract base class for curve smoothing algorithms
# Defines the interface for all smoothing implementations (Chaikin, Catmull-Rom, etc.)

# Enum for curve method types (moved from HexStringPuller for reusability)
enum CurveMethod {
	CATMULL_ROM,  # Smooth spline interpolation - can overshoot
	CHAIKIN       # Corner-cutting subdivision - stable, never overshoots
}

# Number of smoothing iterations or segments
var smoothing_iterations: int = 2


# Main smoothing interface - must be implemented by subclasses
# positions: Array of Vector2 points to smooth
# closed: Whether the curve should form a closed loop
# Returns: Smoothed curve as PackedVector2Array
func smooth_curve(positions: Array[Vector2], closed: bool) -> PackedVector2Array:
	push_error("smooth_curve() must be implemented by subclass")
	return PackedVector2Array()


# Set the number of smoothing iterations
# For Chaikin: Number of subdivision iterations (typically 1-3)
# For Catmull-Rom: Number of segments between control points
func set_smoothing_iterations(iterations: int) -> void:
	smoothing_iterations = max(1, iterations)


# Get current smoothing iterations
func get_smoothing_iterations() -> int:
	return smoothing_iterations


# Utility: Check if positions array is valid for smoothing
func _is_valid_positions(positions: Array[Vector2]) -> bool:
	return positions.size() >= 2


# Utility: Convert Array[Vector2] to PackedVector2Array
func _to_packed(arr: Array[Vector2]) -> PackedVector2Array:
	var packed := PackedVector2Array()
	for v in arr:
		packed.append(v)
	return packed
