extends Node
class_name NavigationTypes

"""
Shared enums, types, and signal definitions for navigation components.

Design notes:
- Central location for all navigation-related types
- Provides consistent enums and type definitions
- Documents signal contracts used across navigation packages
"""

# ----------------------
# Enums
# ----------------------

## Turn-based movement state machine
enum TurnState {
	IDLE,                  ## No movement in progress
	PLANNING,              ## Calculating path
	PREVIEW,               ## Showing path preview to user
	AWAITING_CONFIRMATION, ## Waiting for user to confirm/cancel
	EXECUTING,             ## Moving along path
	COMPLETED              ## Movement finished
}

## Navigation status for real-time navigation
enum NavigationStatus {
	INACTIVE,    ## No navigation in progress
	ACTIVE,      ## Currently navigating
	COMPLETED,   ## Navigation completed successfully
	FAILED,      ## Navigation failed
	CANCELLED    ## Navigation cancelled by user
}

## Path validation result
enum PathValidation {
	VALID,              ## Path is valid and can be used
	INVALID_START,      ## Start position is invalid
	INVALID_GOAL,       ## Goal position is invalid
	NO_PATH_FOUND,      ## No path exists between start and goal
	EXCEEDS_DISTANCE,   ## Path exceeds maximum allowed distance
	BLOCKED             ## Path is blocked
}

# ----------------------
# Signal Documentation
# ----------------------

## Signals emitted by NavigationController:
## - path_found(start: HexCell, goal: HexCell, path: Array[HexCell], duration_ms: float)
## - path_not_found(start_pos: Vector2, goal_pos: Vector2, reason: String)
## - navigation_started(target: HexCell)
## - navigation_completed()
## - navigation_failed(reason: String)
## - waypoint_reached(cell: HexCell, index: int, remaining: int)
## - navigation_state_changed(active: bool, path_length: int, remaining_distance: int)

## Signals emitted by TurnBasedMovementController:
## - turn_started(turn_number: int)
## - movement_started()
## - movement_completed(distance_moved: float)
## - turn_ended(turn_number: int)

## Signals emitted by TurnBasedPathfinder:
## - path_calculated(segments: Array, total_distance: float)
## - path_confirmed()
## - path_cancelled()

# ----------------------
# Type Definitions
# ----------------------

## Request data structure for pathfinding
class PathRequest:
	var request_id: String
	var start_pos: Vector2
	var goal_pos: Vector2
	var max_distance: int = -1  # -1 means no limit

	func _init(id: String, start: Vector2, goal: Vector2, max_dist: int = -1):
		request_id = id
		start_pos = start
		goal_pos = goal
		max_distance = max_dist

## Navigation request data structure
class NavigationRequest:
	var request_id: String
	var target_pos: Vector2
	var target_cell: HexCell

	func _init(id: String, pos: Vector2, cell: HexCell = null):
		request_id = id
		target_pos = pos
		target_cell = cell

## Path result data structure
class PathResult:
	var success: bool
	var path: Array[HexCell] = []
	var world_path: Array[Vector2] = []
	var total_distance: int = 0
	var validation: PathValidation
	var message: String = ""

	func _init(succeeded: bool, validation_result: PathValidation, msg: String = ""):
		success = succeeded
		validation = validation_result
		message = msg
