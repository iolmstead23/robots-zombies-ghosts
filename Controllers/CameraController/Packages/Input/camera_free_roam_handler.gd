class_name CameraFreeRoamHandler
extends RefCounted

## Handles free roam camera control with arrow keys and WASD
## Provides manual camera panning in debug mode

# ============================================================================
# CONFIGURATION
# ============================================================================

var pan_speed: float = 500.0  # pixels per second
var arrow_keys_enabled: bool = true
var wasd_enabled: bool = true

# ============================================================================
# DEPENDENCIES
# ============================================================================

var _camera: Camera2D = null
var _bounds: Rect2 = Rect2()
var _bounds_calculator: CameraBoundsCalculator = null

# ============================================================================
# STATE
# ============================================================================

var _enabled: bool = false
var _input_vector: Vector2 = Vector2.ZERO

# ============================================================================
# SETUP
# ============================================================================

func set_camera(cam: Camera2D) -> void:
	"""Set the camera to control"""
	_camera = cam

func set_bounds(bounds: Rect2) -> void:
	"""Set camera movement bounds"""
	_bounds = bounds

func set_bounds_calculator(calculator: CameraBoundsCalculator) -> void:
	"""Set bounds calculator for dynamic bounds checking"""
	_bounds_calculator = calculator

# ============================================================================
# ENABLE/DISABLE
# ============================================================================

func enable() -> void:
	"""Enable free roam camera control"""
	_enabled = true
	_input_vector = Vector2.ZERO

func disable() -> void:
	"""Disable free roam camera control"""
	_enabled = false
	_input_vector = Vector2.ZERO

func is_enabled() -> bool:
	"""Check if free roam is currently enabled"""
	return _enabled

# ============================================================================
# INPUT HANDLING
# ============================================================================

func update_input() -> void:
	"""
	Update input vector from arrow keys and WASD.
	Should be called every frame when enabled.
	"""
	if not _enabled:
		_input_vector = Vector2.ZERO
		return

	_input_vector = Vector2.ZERO

	# Arrow keys
	if arrow_keys_enabled:
		if Input.is_action_pressed("ui_left"):
			_input_vector.x -= 1.0
		if Input.is_action_pressed("ui_right"):
			_input_vector.x += 1.0
		if Input.is_action_pressed("ui_up"):
			_input_vector.y -= 1.0
		if Input.is_action_pressed("ui_down"):
			_input_vector.y += 1.0

	# WASD alternative
	if wasd_enabled:
		if Input.is_key_pressed(KEY_A):
			_input_vector.x -= 1.0
		if Input.is_key_pressed(KEY_D):
			_input_vector.x += 1.0
		if Input.is_key_pressed(KEY_W):
			_input_vector.y -= 1.0
		if Input.is_key_pressed(KEY_S):
			_input_vector.y += 1.0

	_input_vector = _input_vector.normalized()

# ============================================================================
# CAMERA MOVEMENT
# ============================================================================

func process_movement(delta: float) -> void:
	"""
	Apply camera movement based on current input.
	Should be called every frame.

	Args:
		delta: Frame time in seconds
	"""
	if not _enabled or not _camera or _input_vector.is_zero_approx():
		return

	# Calculate movement (accounting for zoom)
	var move_delta = _input_vector * pan_speed * delta / _camera.zoom.x

	# Apply to camera
	var new_position = _camera.global_position + move_delta

	# Apply bounds if set
	if _bounds.has_area():
		new_position = _apply_bounds(new_position)
	elif _bounds_calculator:
		# Use bounds calculator for dynamic bounds
		new_position = _bounds_calculator.apply_bounds_to_position(
			new_position,
			_camera.zoom.x,
			_bounds
		)

	_camera.global_position = new_position

# ============================================================================
# HELPER METHODS
# ============================================================================

func _apply_bounds(position: Vector2) -> Vector2:
	"""
	Clamp position to bounds.

	Args:
		position: Desired camera position

	Returns:
		Clamped position within bounds
	"""
	if not _bounds.has_area() or not _camera:
		return position

	# Simple clamping - more sophisticated bounds checking
	# is done by bounds_calculator if available
	var clamped_x = clamp(
		position.x,
		_bounds.position.x,
		_bounds.position.x + _bounds.size.x
	)
	var clamped_y = clamp(
		position.y,
		_bounds.position.y,
		_bounds.position.y + _bounds.size.y
	)

	return Vector2(clamped_x, clamped_y)
