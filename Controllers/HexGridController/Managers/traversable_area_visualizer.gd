class_name TraversableAreaVisualizer
extends Node2D

## Visualizes all traversable (navigable) hex cells with:
## - Light green, low-opacity fill for all traversable cells
## - Dark green border edges on hex boundaries adjacent to non-traversable cells
## Active during normal gameplay (not just debug mode)

# ============================================================================
# EXPORTED PROPERTIES
# ============================================================================

@export var hex_grid: HexGrid
@export var session_controller: SessionController

@export_group("Fill Colors")
@export var traversable_fill_color: Color = Color(0.2, 0.8, 0.2, 0.08)  # Light green, 8% opacity

@export_group("Border Colors")
@export var border_color: Color = Color(0.0, 0.5, 0.0, 0.9)  # Dark green, 90% opacity
@export var border_width: float = 2.5

@export_group("String Pulling")
@export var use_string_pulling: bool = true  # Toggle between string pulling and edge detection
@export var smoothing_iterations: int = 1  # Chaikin iterations or Catmull-Rom segments (lower = tighter)
@export var curve_method: HexStringPuller.CurveMethod = HexStringPuller.CurveMethod.CHAIKIN

# ============================================================================
# STATE
# ============================================================================

var _navigable_cells: Array[HexCell] = []
var _navigable_coords_set: Dictionary = {}  # Vector2i -> bool for O(1) lookup
var _hex_corners: PackedVector2Array = []
var _visualizer_enabled: bool = true

# String pulling
var _string_puller: HexStringPuller = HexStringPuller.new()
var _boundary_curve: PackedVector2Array = []

# ============================================================================
# CONSTANTS - Direction to Edge Mapping
# ============================================================================

# Flat-top hex directions for neighbor checking
const FLAT_TOP_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),    # Direction 0 (right)
	Vector2i(1, -1),   # Direction 1 (upper-right)
	Vector2i(0, -1),   # Direction 2 (upper-left)
	Vector2i(-1, 0),   # Direction 3 (left)
	Vector2i(-1, 1),   # Direction 4 (lower-left)
	Vector2i(0, 1)     # Direction 5 (lower-right)
]

# Maps direction index to the hex corner indices that form that edge
# For flat-top hexagon with corners at 0°, 60°, 120°, 180°, 240°, 300°
# Note: Uses odd-q offset system where odd columns are shifted down
# This requires different mappings for even vs odd columns

# Direction to edge mapping for EVEN columns (q % 2 == 0)
const DIRECTION_TO_EDGE_EVEN: Array[Vector2i] = [
	Vector2i(0, 1),  # Direction 0 (+q): neighbor is lower-right -> edge 0-1
	Vector2i(5, 0),  # Direction 1 (+q-r): neighbor is upper-right -> edge 5-0
	Vector2i(4, 5),  # Direction 2 (-r): neighbor is up -> edge 4-5
	Vector2i(3, 4),  # Direction 3 (-q): neighbor is upper-left -> edge 3-4
	Vector2i(2, 3),  # Direction 4 (-q+r): neighbor is lower-left -> edge 2-3
	Vector2i(1, 2),  # Direction 5 (+r): neighbor is down -> edge 1-2
]

# Direction to edge mapping for ODD columns (q % 2 == 1)
const DIRECTION_TO_EDGE_ODD: Array[Vector2i] = [
	Vector2i(5, 0),  # Direction 0 (+q): neighbor is upper-right -> edge 5-0
	Vector2i(4, 5),  # Direction 1 (+q-r): neighbor is up -> edge 4-5
	Vector2i(3, 4),  # Direction 2 (-r): neighbor is upper-left -> edge 3-4
	Vector2i(2, 3),  # Direction 3 (-q): neighbor is lower-left -> edge 2-3
	Vector2i(1, 2),  # Direction 4 (-q+r): neighbor is down -> edge 1-2
	Vector2i(0, 1),  # Direction 5 (+r): neighbor is lower-right -> edge 0-1
]

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	z_index = -1  # Just above ground level, below objects

	if hex_grid:
		_calculate_hex_corners()

	if session_controller:
		_connect_session_signals()


func _connect_session_signals() -> void:
	if session_controller and not session_controller.navigable_cells_updated.is_connected(_on_navigable_cells_updated):
		session_controller.navigable_cells_updated.connect(_on_navigable_cells_updated)


func _calculate_hex_corners() -> void:
	# Pre-calculate corner offsets for hex drawing
	_hex_corners.clear()
	if not hex_grid:
		return

	var size := hex_grid.hex_size
	# Flat-top hexagon: corners at 0, 60, 120, 180, 240, 300 degrees
	for i in range(6):
		var angle_deg := 60.0 * i
		var angle_rad := deg_to_rad(angle_deg)
		_hex_corners.append(Vector2(size * cos(angle_rad), size * sin(angle_rad)))

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_navigable_cells_updated(cells: Array[HexCell]) -> void:
	# Called when SessionController updates navigable cells
	_navigable_cells = cells.duplicate()
	_rebuild_navigable_lookup()
	_rebuild_boundary_curve()
	queue_redraw()


func _rebuild_navigable_lookup() -> void:
	# Rebuild O(1) lookup dictionary for navigable coordinates
	_navigable_coords_set.clear()
	for cell in _navigable_cells:
		_navigable_coords_set[Vector2i(cell.q, cell.r)] = true


func _rebuild_boundary_curve() -> void:
	# Rebuild the smooth boundary curve using string pulling
	_string_puller.smoothing_iterations = smoothing_iterations
	_string_puller.curve_method = curve_method
	_boundary_curve = _string_puller.pull_string(_navigable_cells, _navigable_coords_set)

# ============================================================================
# PUBLIC API
# ============================================================================

func set_visualizer_enabled(enabled: bool) -> void:
	# Enable or disable the visualizer
	if _visualizer_enabled == enabled:
		return
	_visualizer_enabled = enabled
	queue_redraw()


func is_visualizer_enabled() -> bool:
	return _visualizer_enabled


func refresh() -> void:
	# Force a redraw of the visualizer
	queue_redraw()


func set_use_string_pulling(enabled: bool) -> void:
	# Toggle between string pulling and edge detection for borders
	if use_string_pulling == enabled:
		return
	use_string_pulling = enabled
	queue_redraw()


func get_boundary_curve() -> PackedVector2Array:
	# Get the current boundary curve points
	return _boundary_curve


func get_string_puller() -> HexStringPuller:
	# Get the string puller instance for external use
	return _string_puller


func set_curve_method(method: HexStringPuller.CurveMethod) -> void:
	# Set the curve generation method
	if curve_method == method:
		return
	curve_method = method
	_rebuild_boundary_curve()
	queue_redraw()


func get_curve_method() -> HexStringPuller.CurveMethod:
	# Get the current curve generation method
	return curve_method


func set_smoothing_iterations(iterations: int) -> void:
	# Set the number of smoothing iterations
	if smoothing_iterations == iterations:
		return
	smoothing_iterations = iterations
	_rebuild_boundary_curve()
	queue_redraw()


func get_smoothing_iterations() -> int:
	# Get the current number of smoothing iterations
	return smoothing_iterations

# ============================================================================
# DRAWING
# ============================================================================

func _draw() -> void:
	if not _visualizer_enabled or not hex_grid or _hex_corners.is_empty():
		return

	if _navigable_cells.is_empty():
		return

	# Draw cell fills
	for cell in _navigable_cells:
		_draw_cell_fill(cell)

	# Draw border using selected method
	if use_string_pulling:
		_draw_string_pulled_border()
	else:
		# Use edge detection (kept for future use)
		for cell in _navigable_cells:
			_draw_border_edges(cell)


func _draw_cell_fill(cell: HexCell) -> void:
	# Draw the low-opacity fill for a traversable cell
	var center := cell.world_position
	var points := PackedVector2Array()

	for corner in _hex_corners:
		points.append(center + corner)

	draw_colored_polygon(points, traversable_fill_color)


func _draw_string_pulled_border() -> void:
	# Draw smooth curved border using string pulling
	if _boundary_curve.size() < 2:
		return

	# Draw the curve as connected line segments
	for i in range(_boundary_curve.size() - 1):
		draw_line(_boundary_curve[i], _boundary_curve[i + 1], border_color, border_width)


func _draw_border_edges(cell: HexCell) -> void:
	# Draw dark border on edges adjacent to non-traversable cells
	var center := cell.world_position
	var cell_coords := Vector2i(cell.q, cell.r)

	# Select the appropriate edge mapping based on column parity (odd-q offset system)
	var edge_mapping: Array[Vector2i] = DIRECTION_TO_EDGE_EVEN if (cell.q % 2 == 0) else DIRECTION_TO_EDGE_ODD

	# Check each of the 6 directions
	for dir_index in range(6):
		var neighbor_coords := cell_coords + FLAT_TOP_DIRECTIONS[dir_index]

		# Draw border edge if neighbor is NOT navigable
		if not _is_coord_navigable(neighbor_coords):
			var edge := edge_mapping[dir_index]
			var corner_a := center + _hex_corners[edge.x]
			var corner_b := center + _hex_corners[edge.y]
			draw_line(corner_a, corner_b, border_color, border_width)


func _is_coord_navigable(coords: Vector2i) -> bool:
	# Check if coordinates are in the navigable set (O(1) lookup)
	return _navigable_coords_set.has(coords)
