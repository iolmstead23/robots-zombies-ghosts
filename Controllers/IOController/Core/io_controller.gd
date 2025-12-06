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

# ============================================================================
# HOVER STATE
# ============================================================================

## Currently hovered cell
var _hovered_cell: HexCell = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Components will be added as children and auto-initialize
	_connect_component_signals()

	print("IOController initialized")

func _connect_component_signals() -> void:
	"""Connect to child component signals"""
	# Wait for children to be ready
	await get_tree().process_frame

	# Find and connect mouse handler
	mouse_handler = get_node_or_null("MouseInputHandler")
	if mouse_handler:
		mouse_handler.left_click_at_position.connect(_on_mouse_left_click)
		print("IOController: MouseInputHandler connected")

	# Find and connect keyboard handler
	keyboard_handler = get_node_or_null("KeyboardInputHandler")
	if keyboard_handler:
		keyboard_handler.end_turn_requested.connect(func(): end_turn_requested.emit())
		print("IOController: KeyboardInputHandler connected")

	# Find and connect camera handler
	camera_handler = get_node_or_null("CameraInputHandler")
	if camera_handler:
		camera_handler.zoom_in_requested.connect(func(): camera_zoom_in_requested.emit())
		camera_handler.zoom_out_requested.connect(func(): camera_zoom_out_requested.emit())
		print("IOController: CameraInputHandler connected")

# ============================================================================
# CONFIGURATION
# ============================================================================

func set_camera(new_camera: Camera2D) -> void:
	"""Set the camera reference for mouse position calculations"""
	camera = new_camera
	if mouse_handler and mouse_handler.has_method("set_camera"):
		mouse_handler.set_camera(new_camera)

func set_viewport(new_viewport: Viewport) -> void:
	"""Set the viewport reference for mouse position calculations"""
	viewport = new_viewport
	if mouse_handler and mouse_handler.has_method("set_viewport"):
		mouse_handler.set_viewport(new_viewport)

func set_hex_grid(grid: HexGrid) -> void:
	"""Set the hex grid reference for cell lookups"""
	hex_grid = grid
	if mouse_handler and mouse_handler.has_method("set_hex_grid"):
		mouse_handler.set_hex_grid(grid)

# ============================================================================
# SIGNAL HANDLERS - Route component signals to IOController signals
# ============================================================================

func _on_mouse_left_click(world_pos: Vector2) -> void:
	"""Handle left click from mouse handler"""
	world_position_left_clicked.emit(world_pos)

	# Check if position intersects with a hex cell
	if hex_grid:
		var cell = hex_grid.get_cell_at_world_position(world_pos)
		if cell:
			hex_cell_left_clicked.emit(cell)

# ============================================================================
# HOVER DETECTION
# ============================================================================

func _process(_delta: float) -> void:
	"""Track mouse hover over hex cells"""
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
