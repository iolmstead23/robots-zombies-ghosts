class_name CameraState
extends RefCounted

## Camera state data class
## Stores current camera mode, transition state, and tracking information

# ============================================================================
# STATE PROPERTIES
# ============================================================================

## Current camera operating mode
var current_mode: CameraTypes.CameraMode = CameraTypes.CameraMode.FOLLOW

## Whether a transition is currently in progress
var is_transitioning: bool = false

## Agent being targeted by camera
var target_agent: AgentData = null

## Last camera position (for tracking)
var last_position: Vector2 = Vector2.ZERO

## Last camera zoom level (for tracking)
var last_zoom: float = 1.0

## Zoom level for FOLLOW mode (agent-following)
var follow_mode_zoom: float = 1.0

## Zoom level for FREE_ROAM mode (debug free camera)
var free_roam_zoom: float = 1.0

## Current camera movement bounds
var camera_bounds: Rect2 = Rect2()

## Whether free roam mode is enabled
var free_roam_enabled: bool = false

# ============================================================================
# METHODS
# ============================================================================

## Create a duplicate of this state
func duplicate() -> CameraState:
	var state = CameraState.new()
	state.current_mode = current_mode
	state.is_transitioning = is_transitioning
	state.target_agent = target_agent
	state.last_position = last_position
	state.last_zoom = last_zoom
	state.follow_mode_zoom = follow_mode_zoom
	state.free_roam_zoom = free_roam_zoom
	state.camera_bounds = camera_bounds
	state.free_roam_enabled = free_roam_enabled
	return state

## Reset state to defaults
func reset() -> void:
	current_mode = CameraTypes.CameraMode.FOLLOW
	is_transitioning = false
	target_agent = null
	last_position = Vector2.ZERO
	last_zoom = 1.0
	follow_mode_zoom = 1.0
	free_roam_zoom = 1.0
	camera_bounds = Rect2()
	free_roam_enabled = false
