class_name CameraController
extends Node

## Main camera controller for the game
## Handles smooth transitions to agents, viewport calculation, and debug free roam
## All camera operations route through SessionController following signal-based architecture

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when camera transition starts
signal camera_transition_started(agent_data: AgentData)

## Emitted when camera transition completes
signal camera_transition_completed(agent_data: AgentData)

## Emitted when camera transition is cancelled
signal camera_transition_cancelled()

## Emitted when camera bounds are updated
signal camera_bounds_updated(bounds: Rect2)

## Emitted when camera mode changes
signal camera_mode_changed(mode: CameraTypes.CameraMode)

## Emitted when camera position changes (reserved for future use)
@warning_ignore("unused_signal")
signal camera_moved(new_position: Vector2)

## Emitted when camera zoom changes
signal camera_zoomed(new_zoom: Vector2)

## Emitted when controller is fully initialized
signal controller_ready()

# ============================================================================
# CONFIGURATION
# ============================================================================

@export_group("Camera Reference")
@export var camera: Camera2D

@export_group("Transition Settings")
@export var transition_enabled: bool = true
@export var transition_duration: float = 0.8  # seconds
@export var transition_easing: Tween.EaseType = Tween.EASE_IN_OUT
@export var transition_trans: Tween.TransitionType = Tween.TRANS_CUBIC

@export_group("Viewport Settings")
@export var movement_range_buffer: float = 2.5  # Multiplier for agent range (increased from 2.0 to 2.5 for more zoomed out view)
@export var min_zoom: float = 0.3
@export var max_zoom: float = 2.0
@export var auto_zoom_to_fit: bool = true

@export_group("Free Roam Settings")
@export var free_roam_pan_speed: float = 500.0  # pixels/second
@export var free_roam_zoom_speed: float = 0.1
@export var free_roam_enabled_in_debug: bool = true

@export_group("Camera Bounds")
@export var enable_camera_bounds: bool = true
@export var bounds_padding: float = 200.0  # pixels

# ============================================================================
# DEPENDENCIES
# ============================================================================

var session_controller = null
var hex_grid_controller = null
var hex_size: float = 32.0  # Actual hex size from grid (defaults to 32.0)

# ============================================================================
# INTERNAL STATE
# ============================================================================

var _camera_state: CameraState
var _transition_handler: CameraTransitionHandler
var _bounds_calculator: CameraBoundsCalculator
var _free_roam_handler: CameraFreeRoamHandler

var _current_mode: CameraTypes.CameraMode = CameraTypes.CameraMode.FOLLOW
var _is_transitioning: bool = false
var _transition_tween: Tween = null
var _camera_bounds: Rect2 = Rect2()
var is_initialized: bool = false

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Initialize state
	_camera_state = CameraState.new()

	# Initialize helpers
	_transition_handler = CameraTransitionHandler.new()
	_bounds_calculator = CameraBoundsCalculator.new()
	_free_roam_handler = CameraFreeRoamHandler.new()

	# Configure helpers
	_transition_handler.set_bounds_calculator(_bounds_calculator)
	_free_roam_handler.set_bounds_calculator(_bounds_calculator)
	_free_roam_handler.pan_speed = free_roam_pan_speed

func _process(delta: float) -> void:
	# Handle free roam camera movement
	if _current_mode == CameraTypes.CameraMode.FREE_ROAM:
		_free_roam_handler.update_input()
		_free_roam_handler.process_movement(delta)

# ============================================================================
# INITIALIZATION
# ============================================================================

func initialize(session_ctrl, cam: Camera2D) -> void:
	"""
	Initialize camera controller with dependencies.

	Args:
		session_ctrl: Reference to SessionController
		cam: Camera2D node to control
	"""
	session_controller = session_ctrl
	camera = cam

	# Configure bounds calculator
	if session_ctrl and session_ctrl.get_viewport():
		_bounds_calculator.set_viewport(session_ctrl.get_viewport())

	# Configure free roam handler
	_free_roam_handler.set_camera(camera)
	_free_roam_handler.arrow_keys_enabled = true
	_free_roam_handler.wasd_enabled = true

	is_initialized = true
	controller_ready.emit()
	print("[CameraController] Initialized with camera at ", camera.global_position)

func set_hex_grid_controller(controller) -> void:
	"""Set hex grid controller reference for bounds calculation"""
	hex_grid_controller = controller

	# Calculate initial camera bounds
	if enable_camera_bounds and hex_grid_controller:
		_update_camera_bounds()

func set_hex_size(size: float) -> void:
	"""
	Set the actual hex size from the grid.
	Must be called after grid initialization.

	Args:
		size: Actual hex size in pixels from grid initialization
	"""
	hex_size = size

	# Update bounds calculator with new hex size
	if _bounds_calculator:
		_bounds_calculator.set_hex_size(hex_size)

	# Recalculate camera bounds with new hex size
	if enable_camera_bounds and hex_grid_controller:
		_update_camera_bounds()

	if OS.is_debug_build():
		print("[CameraController] hex_size updated to: ", hex_size)

# ============================================================================
# CAMERA TRANSITIONS
# ============================================================================

func move_camera_to_agent(agent_data: AgentData) -> void:
	"""
	Start smooth camera transition to an agent.

	Args:
		agent_data: Agent to focus camera on
	"""
	if not transition_enabled or _current_mode == CameraTypes.CameraMode.FREE_ROAM:
		return

	if not camera or not agent_data:
		push_warning("[CameraController] Cannot move camera: missing camera or agent_data")
		return

	_start_transition_to_agent(agent_data)

func _start_transition_to_agent(agent_data: AgentData) -> void:
	"""
	Internal method to start camera transition.

	Args:
		agent_data: Agent to transition to
	"""
	# Cancel any ongoing transition
	if _is_transitioning and _transition_tween:
		_transition_tween.kill()
		camera_transition_cancelled.emit()

	# Calculate target position and zoom
	var grid = hex_grid_controller.get_hex_grid() if hex_grid_controller else null
	var target = _calculate_target_position_and_zoom(agent_data, grid)
	var target_position: Vector2 = target.position
	var target_zoom: float = target.zoom

	# Check if already at target (skip transition if within threshold)
	if _transition_handler.should_skip_transition(
		camera.global_position,
		target_position,
		camera.zoom.x,
		target_zoom
	):
		# Already at target, skip transition
		return

	# Apply bounds to target position
	if enable_camera_bounds and _camera_bounds.has_area():
		target_position = _bounds_calculator.apply_bounds_to_position(
			target_position,
			target_zoom,
			_camera_bounds
		)

	# Emit start signal
	_is_transitioning = true
	_camera_state.is_transitioning = true
	_camera_state.target_agent = agent_data
	camera_transition_started.emit(agent_data)

	# Create tween for smooth transition
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)  # Position and zoom simultaneously
	_transition_tween.set_ease(transition_easing)
	_transition_tween.set_trans(transition_trans)

	# Animate position
	_transition_tween.tween_property(
		camera,
		"global_position",
		target_position,
		transition_duration
	)

	# Animate zoom
	_transition_tween.tween_property(
		camera,
		"zoom",
		Vector2(target_zoom, target_zoom),
		transition_duration
	)

	# Connect completion callback
	_transition_tween.finished.connect(
		func():
			_is_transitioning = false
			_camera_state.is_transitioning = false
			camera_transition_completed.emit(agent_data)
	)

func _cancel_current_transition() -> void:
	"""Cancel any ongoing camera transition"""
	if _is_transitioning and _transition_tween:
		_transition_tween.kill()
		_is_transitioning = false
		_camera_state.is_transitioning = false
		camera_transition_cancelled.emit()

func _calculate_target_position_and_zoom(agent_data: AgentData, grid) -> Dictionary:
	"""
	Calculate target camera position and zoom for an agent.

	Args:
		agent_data: Agent to focus on
		grid: Hex grid (optional, for bounds)

	Returns:
		Dictionary with 'position' and 'zoom' keys
	"""
	var target = _transition_handler.calculate_target_for_agent(agent_data, grid)

	# Override zoom if auto_zoom_to_fit is enabled
	if auto_zoom_to_fit:
		target.zoom = _bounds_calculator.calculate_zoom_for_agent_range(
			agent_data,
			movement_range_buffer
		)

	return target

# ============================================================================
# FREE ROAM MODE
# ============================================================================

func enable_free_roam() -> void:
	"""Enable free roam camera control (debug mode)"""
	if not free_roam_enabled_in_debug:
		return

	# Cancel any ongoing transition
	_cancel_current_transition()

	# Save current zoom as FOLLOW mode zoom
	if camera:
		_camera_state.follow_mode_zoom = camera.zoom.x

	# Switch to free roam mode
	_current_mode = CameraTypes.CameraMode.FREE_ROAM
	_camera_state.current_mode = _current_mode
	_camera_state.free_roam_enabled = true

	# Restore FREE_ROAM mode zoom
	if camera:
		var target_zoom = _camera_state.free_roam_zoom
		target_zoom = clamp(target_zoom, min_zoom, max_zoom)
		camera.zoom = Vector2(target_zoom, target_zoom)
		_camera_state.last_zoom = target_zoom

	# Enable free roam handler
	_free_roam_handler.enable()

	# Update bounds for free roam
	if enable_camera_bounds:
		_free_roam_handler.set_bounds(_camera_bounds)

	camera_mode_changed.emit(_current_mode)

func disable_free_roam() -> void:
	"""Disable free roam camera control"""
	# Save current zoom as FREE_ROAM mode zoom
	if camera:
		_camera_state.free_roam_zoom = camera.zoom.x

	# Disable free roam handler
	_free_roam_handler.disable()

	# Switch back to follow mode
	_current_mode = CameraTypes.CameraMode.FOLLOW
	_camera_state.current_mode = _current_mode
	_camera_state.free_roam_enabled = false

	# Restore FOLLOW mode zoom
	if camera:
		var target_zoom = _camera_state.follow_mode_zoom
		target_zoom = clamp(target_zoom, min_zoom, max_zoom)
		camera.zoom = Vector2(target_zoom, target_zoom)
		_camera_state.last_zoom = target_zoom

	camera_mode_changed.emit(_current_mode)

	# Transition back to active agent if available
	if session_controller and session_controller.has_method("get_current_turn_agent"):
		var active_agent = session_controller.get_current_turn_agent()
		if active_agent:
			move_camera_to_agent(active_agent)

# ============================================================================
# ZOOM CONTROL
# ============================================================================

func zoom_in() -> void:
	"""Zoom camera in"""
	if not camera:
		return

	# Cancel transition if user manually zooms
	if _is_transitioning:
		_cancel_current_transition()

	var new_zoom = camera.zoom.x + free_roam_zoom_speed
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	camera.zoom = Vector2(new_zoom, new_zoom)

	_update_zoom_tracking(new_zoom)
	camera_zoomed.emit(camera.zoom)

func zoom_out() -> void:
	"""Zoom camera out"""
	if not camera:
		return

	# Cancel transition if user manually zooms
	if _is_transitioning:
		_cancel_current_transition()

	var new_zoom = camera.zoom.x - free_roam_zoom_speed
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	camera.zoom = Vector2(new_zoom, new_zoom)

	_update_zoom_tracking(new_zoom)
	camera_zoomed.emit(camera.zoom)

func set_zoom_level(zoom: float) -> void:
	"""Set camera zoom to specific level"""
	if not camera:
		return

	zoom = clamp(zoom, min_zoom, max_zoom)
	camera.zoom = Vector2(zoom, zoom)

	_update_zoom_tracking(zoom)
	camera_zoomed.emit(camera.zoom)

func _update_zoom_tracking(zoom_level: float) -> void:
	"""Update zoom tracking for current mode"""
	_camera_state.last_zoom = zoom_level

	# Track zoom for current mode
	if _current_mode == CameraTypes.CameraMode.FREE_ROAM:
		_camera_state.free_roam_zoom = zoom_level
	else:  # FOLLOW or LOCKED
		_camera_state.follow_mode_zoom = zoom_level

# ============================================================================
# CAMERA BOUNDS
# ============================================================================

func _update_camera_bounds() -> void:
	"""Recalculate camera bounds from hex grid"""
	if not hex_grid_controller:
		return

	var grid = hex_grid_controller.get_hex_grid()
	if not grid:
		return

	_camera_bounds = _bounds_calculator.calculate_camera_bounds(grid, bounds_padding)
	_camera_state.camera_bounds = _camera_bounds

	camera_bounds_updated.emit(_camera_bounds)

# ============================================================================
# UTILITY METHODS
# ============================================================================

func get_current_mode() -> CameraTypes.CameraMode:
	"""Get current camera mode"""
	return _current_mode

func is_transitioning() -> bool:
	"""Check if camera is currently transitioning"""
	return _is_transitioning

func get_camera_state() -> CameraState:
	"""Get current camera state (duplicate)"""
	return _camera_state.duplicate()

func get_zoom_level() -> float:
	"""Get current camera zoom level"""
	return camera.zoom.x if camera else 1.0

func get_follow_mode_zoom() -> float:
	"""Get stored zoom level for FOLLOW mode"""
	return _camera_state.follow_mode_zoom

func get_free_roam_zoom() -> float:
	"""Get stored zoom level for FREE_ROAM mode"""
	return _camera_state.free_roam_zoom

func get_zoom_range() -> Vector2:
	"""Get min and max zoom limits as Vector2(min, max)"""
	return Vector2(min_zoom, max_zoom)
