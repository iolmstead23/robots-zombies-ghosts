class_name IsoTransform
extends RefCounted

# 30° isometric transformation with diagonal axis rotation
# Provides classic isometric perspective with equal hex distances

# Rotation angle
const ROTATION_DEG: float = 30.0
const ROTATION_RAD: float = 0.523599  # PI/6

# Trigonometric constants
const COS_30: float = 0.866025403784  # sqrt(3)/2
const SIN_30: float = 0.5

# Y-scale for equal hex distances (optimized from 0.577 to reduce variance)
const DISTANCE_SCALE: float = 1.0

# Transformation matrix [a b; c d]
const MATRIX_A: float = 0.866025  # cos(30°)
const MATRIX_B: float = -0.5      # -sin(30°)
const MATRIX_C: float = 0.5       # sin(30°) × DISTANCE_SCALE
const MATRIX_D: float = 0.866025  # cos(30°) × DISTANCE_SCALE

# Inverse matrix components
const DET: float = 1.0  # determinant
const INV_SCALE: float = 1.0  # 1/det

# Transform standard world position to 30° isometric space
static func to_isometric(world_pos: Vector2) -> Vector2:
	var x := world_pos.x
	var y := world_pos.y
	return Vector2(
		x * MATRIX_A + y * MATRIX_B,
		x * MATRIX_C + y * MATRIX_D
	)

# Transform isometric position back to standard world space
static func from_isometric(iso_pos: Vector2) -> Vector2:
	var ix := iso_pos.x
	var iy := iso_pos.y
	return Vector2(
		(ix * MATRIX_D - iy * MATRIX_B) * INV_SCALE,
		(-ix * MATRIX_C + iy * MATRIX_A) * INV_SCALE
	)

# Get isometric spacing parameters for flat-top hexagons
static func get_isometric_spacing(hex_size: float) -> Dictionary:
	var standard_h := hex_size * 1.5
	var standard_v := hex_size * sqrt(3.0)
	var standard_vec_h := Vector2(standard_h, 0.0)
	var standard_vec_v := Vector2(0.0, standard_v)
	var iso_h := to_isometric(standard_vec_h).length()
	var iso_v := to_isometric(standard_vec_v).length()
	return {
		"horizontal": iso_h,
		"vertical": iso_v,
		"ratio": iso_h / iso_v
	}

# Calculate isometric position from axial coordinates (flat-top, odd-Q)
static func axial_to_isometric(q: int, r: int, hex_size: float, grid_offset: Vector2) -> Vector2:
	var standard_x := hex_size * (1.5 * q)
	var standard_y := hex_size * (sqrt(3.0) * (r + 0.5 * (q & 1)))
	var result := to_isometric(Vector2(standard_x, standard_y) + grid_offset)
	return result

# Calculate axial coordinates from isometric world position (flat-top, odd-Q)
static func isometric_to_axial(iso_pos: Vector2, hex_size: float, grid_offset: Vector2) -> Vector2i:
	var world_pos := from_isometric(iso_pos)
	var p := world_pos - grid_offset
	var q := (2.0 / 3.0 * p.x) / hex_size
	var col_offset := 0.5 * (int(round(q)) & 1)
	var r := (p.y / (hex_size * sqrt(3.0))) - col_offset
	return _hex_round(q, r)

# Hex coordinate rounding (cube coordinate method)
static func _hex_round(q: float, r: float) -> Vector2i:
	var x := q
	var z := r
	var y := -x - z
	var rx := roundi(x)
	var ry := roundi(y)
	var rz := roundi(z)
	var dx: float = abs(rx - x)
	var dy: float = abs(ry - y)
	var dz: float = abs(rz - z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(rx, rz)
