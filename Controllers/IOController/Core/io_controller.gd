extends Node
class_name IOController

## IOController - Central Input/Output Management System
##
## Atomized input handling that separates concerns and uses signals
## for loose coupling with other game systems.
##
## Architecture:
## - Mouse input handled by MouseInputHandler component
## - Keyboard input handled by KeyboardInputHandler component
## - Camera input handled by CameraInputHandler component
## - Each component emits specific signals that this controller relays
##
## Usage:
## Connect to the signals below from other controllers/systems
## to respond to user input events.

# ============================================================================
# SIGNALS - Mouse Input Events
# ============================================================================

## Emitted when user left-clicks on a world position
signal world_position_left_clicked(world_pos: Vector2)

## Emitted when user left-clicks and a hex cell is found at that position
signal hex_cell_left_clicked(cell: HexCell)

## Emitted when user clicks a hex cell that is not navigable (rejected click)
signal hex_cell_click_rejected(cell: HexCell)

## Emitted when mouse hovers over a different hex cell
signal hex_cell_hovered(cell: HexCell)

## Emitted when mouse is no longer hovering over any hex cell
signal hex_cell_hover_ended()

# ============================================================================
# SIGNALS - Camera Input Events
# ============================================================================

## Emitted when user scrolls mouse wheel up (zoom in)
signal camera_zoom_in_requested()

## Emitted when user scrolls mouse wheel down (zoom out)
signal camera_zoom_out_requested()

# ============================================================================
# SIGNALS - Keyboard Input Events
# ============================================================================

## Emitted when user presses Space or Enter (end current agent turn)
signal end_turn_requested()

## Emitted when controller is fully initialized
signal controller_ready()

# ============================================================================
# COMPONENT REFERENCES
# ============================================================================

var mouse_handler: Node
var keyboard_handler: Node
var camera_handler: Node

# ============================================================================
# DEPENDENCIES
# ============================================================================

## Reference to camera for mouse position calculations
var camera: Camera2D

## Reference to viewport for mouse position calculations
var viewport: Viewport

## Reference to hex grid for cell lookups
var hex_grid: HexGrid

## Reference to session controller for navigability checks
var session_controller: SessionController

# ============================================================================
# HOVER STATE
# ============================================================================

## Currently hovered cell
var _hovered_cell: HexCell = null

## Controller state
var is_initialized: bool = false

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Components will be added as children and auto-initialize
	_connect_component_signals()

func _connect_component_signals() -> void:
	# Connect to child component signals
	# Wait for children to be ready
	await get_tree().process_frame

	# Find and connect mouse handler
	mouse_handler = get_node_or_null("MouseInputHandler")
	if mouse_handler:
		mouse_handler.left_click_at_position.connect(_on_mouse_left_click)
		# Propagate any already-set dependencies
		if camera and mouse_handler.has_method("set_camera"):
			mouse_handler.set_camera(camera)
		if viewport and mouse_handler.has_method("set_viewport"):
			mouse_handler.set_viewport(viewport)

	# Find and connect keyboard handler
	keyboard_handler = get_node_or_null("KeyboardInputHandler")
	if keyboard_handler:
		keyboard_handler.end_turn_requested.connect(func(): end_turn_requested.emit())

	# Find and connect camera handler
	camera_handler = get_node_or_null("CameraInputHandler")
	if camera_handler:
		camera_handler.zoom_in_requested.connect(func(): camera_zoom_in_requested.emit())
		camera_handler.zoom_out_requested.connect(func(): camera_zoom_out_requested.emit())

# ============================================================================
# CONFIGURATION
# ============================================================================

func set_camera(new_camera: Camera2D) -> void:
	# Set the camera reference for mouse position calculations
	camera = new_camera
	if mouse_handler and mouse_handler.has_method("set_camera"):
		mouse_handler.set_camera(new_camera)

func set_viewport(new_viewport: Viewport) -> void:
	# Set the viewport reference for mouse position calculations
	viewport = new_viewport
	if mouse_handler and mouse_handler.has_method("set_viewport"):
		mouse_handler.set_viewport(new_viewport)

func set_hex_grid(grid: HexGrid) -> void:
	# Set the hex grid reference for cell lookups
	hex_grid = grid
	if mouse_handler and mouse_handler.has_method("set_hex_grid"):
		mouse_handler.set_hex_grid(grid)

func set_session_controller(controller: SessionController) -> void:
	# Set the session controller reference for navigability checks
	session_controller = controller

func verify_dependencies() -> bool:
	# Verify all dependencies are properly set
	var all_ok = true

	if not camera:
		push_error("[IOController] CRITICAL: Camera not set!")
		all_ok = false

	if not viewport:
		push_error("[IOController] CRITICAL: Viewport not set!")
		all_ok = false

	if not hex_grid:
		push_warning("[IOController] HexGrid not set - hover will not work")

	if not mouse_handler:
		push_error("[IOController] CRITICAL: MouseInputHandler not found!")
		all_ok = false

	if not keyboard_handler:
		push_error("[IOController] CRITICAL: KeyboardInputHandler not found!")
		all_ok = false

	if all_ok:
		is_initialized = true
		controller_ready.emit()

	return all_ok

# ============================================================================
# SIGNAL HANDLERS - Route component signals to IOController signals
# ============================================================================

func _on_mouse_left_click(world_pos: Vector2) -> void:
	# Handle left click from mouse handler
	world_position_left_clicked.emit(world_pos)

	# Check if position intersects with a hex cell
	if hex_grid:
		var cell = hex_grid.get_cell_at_world_position(world_pos)
		if cell:
			# Validate cell is clickable before emitting signal
			if _is_cell_clickable(cell):
				hex_cell_left_clicked.emit(cell)
			else:
				# Emit rejection signal for visual feedback
				hex_cell_click_rejected.emit(cell)

# ============================================================================
# HOVER DETECTION
# ============================================================================

func _process(_delta: float) -> void:
	# Track mouse hover over hex cells
	if not hex_grid or not camera or not viewport:
		return

	# Get current mouse position in world coordinates
	var mouse_pos = viewport.get_mouse_position()
	var canvas_transform = camera.get_canvas_transform()
	var world_pos = canvas_transform.affine_inverse() * mouse_pos

	# Get the cell at current mouse position
	var cell = hex_grid.get_cell_at_world_position(world_pos)

	# Check if hovered cell changed
	if cell != _hovered_cell:
		if _hovered_cell != null:
			hex_cell_hover_ended.emit()

		_hovered_cell = cell

		if _hovered_cell != null:
			hex_cell_hovered.emit(_hovered_cell)

# ============================================================================
# VALIDATION HELPERS
# ============================================================================

func _is_cell_clickable(cell: HexCell) -> bool:
	## Validates if a hex cell can be clicked and selected.
	## Returns true only if the cell is navigable within the current agent's range.

	# 1. Cell must exist and be valid
	if not cell or not is_instance_valid(cell):
		return false

	# 2. Cell must be enabled (base traversability)
	if not cell.enabled:
		return false

	# 3. Cell must be navigable (within agent's movement range)
	if not session_controller:
		# Graceful degradation: if no session context, allow enabled cells
		return cell.enabled

	# Edge case: No navigable cells means nothing is clickable
	if session_controller.get_navigable_cells().is_empty():
		return false

	# Normal case: Check if cell is in the navigable cells array
	return session_controller.is_cell_navigable(cell)
