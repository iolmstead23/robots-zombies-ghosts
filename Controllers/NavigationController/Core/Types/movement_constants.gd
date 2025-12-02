extends Node
class_name MovementConstants

"""
Shared movement and navigation constants used across all navigation components.

Design notes:
- Central location for all movement-related constants
- Provides consistent values for distance calculations, thresholds, and conversions
- Used by all navigation packages to ensure consistency
"""

# ----------------------
# Distance & Conversion
# ----------------------

## Conversion factor: meters to pixels (32 pixels = 1 meter)
## NOTE: This is only used for rendering/visualization. Distance calculations use hex cells.
const PIXELS_PER_METER: int = 32

## Maximum movement distance per turn (in meters/hex cells)
const MAX_MOVEMENT_DISTANCE: int = 10 # 10 meters = 10 hex cells

# ----------------------
# Movement Thresholds
# ----------------------

## Distance threshold for arrival detection (in pixels)
const ARRIVAL_DISTANCE_PIXELS: int = 5

## Distance threshold for reaching a specific target point (in pixels)
const TARGET_POINT_THRESHOLD_PIXELS: int = 1

## Progress value considered "near finish" (0.0 to 1.0)
const NEAR_FINISH_PROGRESS: float = 0.99

## Progress increment when reaching a waypoint (0.0 to 1.0)
const PROGRESS_BUMP_ON_POINT_REACHED: float = 0.05

# ----------------------
# Movement Speed
# ----------------------

## Default movement speed for turn-based execution (pixels/second)
const DEFAULT_MOVEMENT_SPEED: int = 400

## Default movement speed for real-time navigation (pixels/second)
const DEFAULT_REALTIME_SPEED: int = 200

## Default rotation speed (radians/second)
const DEFAULT_ROTATION_SPEED: int = 10

# ----------------------
# Timeout & Detection
# ----------------------

## Timeout for waypoint arrival detection (milliseconds)
const WAYPOINT_TIMEOUT: int = 5000

## Distance threshold for waypoint advancement (pixels)
const WAYPOINT_ADVANCEMENT_DISTANCE: int = 10

# ----------------------
# Helper Functions
# ----------------------

## Convert meters to pixels
static func meters_to_pixels(meters: int) -> int:
	return meters * PIXELS_PER_METER

## Convert pixels to meters (with decimal precision)
static func pixels_to_meters(pixels: float) -> float:
	return pixels / float(PIXELS_PER_METER)
