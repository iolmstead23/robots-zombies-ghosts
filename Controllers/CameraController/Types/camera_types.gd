class_name CameraTypes
extends RefCounted

## Camera controller type definitions and constants
## Used throughout the camera system for consistent state management

# ============================================================================
# ENUMS
# ============================================================================

enum CameraMode {
	FOLLOW,      ## Auto-follow active agent
	FREE_ROAM,   ## Debug mode free camera
	LOCKED       ## No camera movement
}

enum TransitionState {
	IDLE,
	TRANSITIONING,
	CANCELLED
}

# ============================================================================
# CAMERA MOVEMENT CONSTANTS
# ============================================================================

## Default zoom level for camera
const DEFAULT_ZOOM: float = 1.0

## Minimum allowed zoom level
const MIN_ZOOM: float = 0.3

## Maximum allowed zoom level
const MAX_ZOOM: float = 2.0

## Zoom increment/decrement for mouse wheel
const ZOOM_STEP: float = 0.1

## Default transition duration in seconds
const DEFAULT_TRANSITION_DURATION: float = 0.8

## Distance threshold to skip transition (pixels)
const SKIP_TRANSITION_DISTANCE_THRESHOLD: float = 10.0

## Zoom difference threshold to skip transition
const SKIP_TRANSITION_ZOOM_THRESHOLD: float = 0.05

# ============================================================================
# HEX GRID CONSTANTS
# ============================================================================

## Default hex size in pixels (used as fallback only)
## NOTE: Actual hex_size is dynamically calculated (8-12 pixels) based on navmesh
## and passed from SessionController to CameraController.
## This constant should NOT be used for calculations - it's a fallback default only.
const HEX_SIZE: float = 32.0

## Maximum movement distance per turn in hex cells
const MAX_MOVEMENT_DISTANCE: int = 10

## Default pixels per meter (1 hex = 1 meter)
## NOTE: This is a fallback value. Actual conversions use dynamic hex_size
## passed from the grid initialization.
const PIXELS_PER_METER: int = 32
