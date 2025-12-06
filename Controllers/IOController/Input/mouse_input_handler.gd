extends Node
class_name MouseInputHandler

## MouseInputHandler - Handles all mouse input events
##
## Atomized component that processes mouse button clicks and
## emits signals with world space coordinates.
##
## Responsibilities:
## - Detect left and right mouse button clicks
## - Convert screen coordinates to world coordinates
## - Emit signals for other systems to consume
##
## Does NOT:
## - Know about hex grids or cells (that's IOController's job)
## - Handle navigation logic (that's delegated via signals)

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when left mouse button is clicked
signal left_click_at_position(world_pos: Vector2)

# ============================================================================
# DEPENDENCIES
# ============================================================================

## Reference to camera for coordinate conversion
var camera: Camera2D

## Reference to viewport for mouse position
var viewport: Viewport

# ============================================================================
# CONFIGURATION
# ============================================================================

func set_camera(new_camera: Camera2D) -> void:
	"""Set the camera reference"""
	camera = new_camera

func set_viewport(new_viewport: Viewport) -> void:
	"""Set the viewport reference"""
	viewport = new_viewport

func set_hex_grid(_grid: HexGrid) -> void:
	"""Hex grid setter for compatibility - not used by this handler"""
	pass

# ============================================================================
# INPUT PROCESSING
# ============================================================================

## Use _unhandled_input so selectable objects can handle clicks first
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	if not event.pressed:
		return

	# Check if camera/viewport are set before processing
	if not camera or not viewport:
		return  # Dependencies not configured yet

	# Get world position
	var world_pos = _get_world_mouse_position()

	# Handle left mouse button click
	if event.button_index == MOUSE_BUTTON_LEFT:
		left_click_at_position.emit(world_pos)

# ============================================================================
# HELPER METHODS
# ============================================================================

func _get_world_mouse_position() -> Vector2:
	"""Convert screen mouse position to world coordinates"""
	if not camera:
		push_warning("MouseInputHandler: Camera not set")
		return Vector2.ZERO

	if not viewport:
		# Try to get viewport from tree
		viewport = get_viewport()

	if not viewport:
		push_warning("MouseInputHandler: Viewport not found")
		return Vector2.ZERO

	var viewport_pos: Vector2 = viewport.get_mouse_position()
	var canvas_transform: Transform2D = camera.get_canvas_transform()
	return canvas_transform.affine_inverse() * viewport_pos