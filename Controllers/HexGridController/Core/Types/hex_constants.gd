class_name HexConstants
extends RefCounted

# Central location for all hex grid constants
# Ensures single source of truth for hex geometry values

# Core hex geometry
const HEX_SIZE: float = 32.0

# Neighbor distances
const NEIGHBOR_DISTANCE_LOGICAL: int = 1  # Hex cells (always 1 for adjacent cells)

# Isometric pixel distance between adjacent hex cells
# This value is derived from the isometric transformation with HEX_Y_SCALE=1.5 and 30° rotation
# Calculation for hex_size=32.0:
#   - Flat-top hex neighbors at distance 1 have varying standard distances
#   - After Y-scaling (×1.5) and 30° rotation, all 6 neighbors become equidistant
#   - The resulting visual distance is approximately 0.5625 × hex_size
#   - For hex_size=32.0: 32.0 × 0.5625 = 18.0 pixels
# This can be verified using IsoDistanceCalculator.verify_equal_distances(hex_size)
const NEIGHBOR_DISTANCE_PIXELS: float = 18.0

# Distance calculation settings
const DISTANCE_TOLERANCE: float = 1.05  # 5% tolerance for floating-point precision in circular range filtering

# Movement distance calculation
# Based on MAX_MOVEMENT_DISTANCE from MovementConstants (10 hex cells)
# Calculated as: 10 cells × 18 pixels/cell = 180 pixels
# Note: This is the default budget, actual value may be configured per-agent
const DEFAULT_MAX_DISTANCE_PIXELS: float = 180.0

# Calculate actual neighbor distance for a given hex size
# Uses IsoDistanceCalculator to measure the visual distance after isometric transformation
# This accounts for HEX_Y_SCALE and 30° rotation
# Returns the average distance to all 6 neighbors (should be equal if transformation is correct)
static func calculate_neighbor_distance(hex_size: float) -> float:
	var metrics := IsoDistanceCalculator.verify_equal_distances(hex_size)
	if not metrics.are_equal:
		push_warning("[HexConstants] Neighbor distances not equal (variance: %.4f)" % metrics.variance)
	return metrics.average

# Verify that NEIGHBOR_DISTANCE_PIXELS matches the calculated value for HEX_SIZE
# Returns true if within 0.1 pixel tolerance
static func verify_neighbor_distance() -> bool:
	var calculated := calculate_neighbor_distance(HEX_SIZE)
	var difference: float = abs(calculated - NEIGHBOR_DISTANCE_PIXELS)
	if difference > 0.1:
		push_warning("[HexConstants] NEIGHBOR_DISTANCE_PIXELS mismatch: expected %.2f, calculated %.2f (diff: %.2f)" % [
			NEIGHBOR_DISTANCE_PIXELS,
			calculated,
			difference
		])
		return false
	return true

# Get the ratio of neighbor distance to hex size
# For HEX_SIZE=32.0 and NEIGHBOR_DISTANCE_PIXELS=18.0, this returns 0.5625
static func get_neighbor_distance_ratio() -> float:
	return NEIGHBOR_DISTANCE_PIXELS / HEX_SIZE

# Helper function to validate hex size
static func is_valid_hex_size(hex_size: float) -> bool:
	return hex_size > 0.0 and hex_size < 1000.0

# Calculate maximum distance in pixels from hex cell count
static func hex_cells_to_pixels(hex_cells: int) -> float:
	return float(hex_cells) * NEIGHBOR_DISTANCE_PIXELS

# Calculate hex cell count from pixel distance
static func pixels_to_hex_cells(pixels: float) -> float:
	return pixels / NEIGHBOR_DISTANCE_PIXELS
