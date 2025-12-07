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
@export var traversable_fill_color: Color = Color(0.2, 0.8, 0.2, 0.35)  # Light green, 35% opacity

@export_group("Border Colors")
@export var border_color: Color = Color(0.0, 0.5, 0.0, 0.9)  # Dark green, 90% opacity
@export var border_width: float = 2.5

@export_group("Rendering Mode")
@export var use_filled_edges: bool = true  # Fill boundary hexes with dark green
@export var use_string_pulling: bool = false  # Use smooth boundary curve

@export_group("String Pulling")
@export var smoothing_iterations: int = 1  # Chaikin iterations or Catmull-Rom segments (lower = tighter)
@export var curve_method: HexStringPuller.CurveMethod = HexStringPuller.CurveMethod.CHAIKIN

@export_group("Edge Fill Colors")
@export var edge_fill_color: Color = Color(0.0, 0.4, 0.0, 0.8)  # Dark green for boundary cells

@export_group("Selection Colors")
@export var selected_cell_color: Color = Color(0.0, 0.2, 0.8, 0.8)  # Dark blue for selected cell

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

# Boundary cells (cells with at least one non-navigable neighbor)
var _boundary_cells: Array[HexCell] = []
var _boundary_cells_set: Dictionary = {}  # Vector2i -> bool for O(1) lookup

# Selected cell for navigation
var _selected_cell: HexCell = null

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
	_identify_boundary_cells()
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


func _identify_boundary_cells() -> void:
	# Find all cells that have at least one non-navigable neighbor
	_boundary_cells.clear()
	_boundary_cells_set.clear()

	for cell in _navigable_cells:
		var cell_coords := Vector2i(cell.q, cell.r)
		var is_boundary := false

		# Check each of the 6 directions - if ANY neighbor is not navigable, mark as boundary
		for dir in FLAT_TOP_DIRECTIONS:
			var neighbor_coords := cell_coords + dir

			# A cell is on the boundary if its neighbor is:
			# 1. Not in the navigable set (disabled or non-existent)
			# 2. OR if we can't find it in the navigable set at all
			if not _navigable_coords_set.has(neighbor_coords):
				is_boundary = true
				break

		# Double-check: If cell is enabled but has fewer than 6 navigable neighbors, it's definitely boundary
		if not is_boundary and hex_grid:
			var navigable_neighbor_count := 0
			for dir in FLAT_TOP_DIRECTIONS:
				var neighbor_coords := cell_coords + dir
				if _navigable_coords_set.has(neighbor_coords):
					navigable_neighbor_count += 1

			# If we don't have all 6 neighbors as navigable, this is a boundary cell
			if navigable_neighbor_count < 6:
				is_boundary = true

		if is_boundary:
			_boundary_cells.append(cell)
			_boundary_cells_set[cell_coords] = true

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


func set_selected_cell(cell: HexCell) -> void:
	# Set the currently selected navigation cell
	if _selected_cell != cell:
		_selected_cell = cell
		queue_redraw()


func clear_selected_cell() -> void:
	# Clear the selected navigation cell
	if _selected_cell != null:
		_selected_cell = null
		queue_redraw()

# ============================================================================
# DRAWING
# ============================================================================

func _draw() -> void:
	if not _visualizer_enabled or not hex_grid or _hex_corners.is_empty():
		return

	if _navigable_cells.is_empty():
		return

	# Draw interior cells with light green
	for cell in _navigable_cells:
		var cell_coords := Vector2i(cell.q, cell.r)
		if not _boundary_cells_set.has(cell_coords):
			_draw_cell_fill(cell)

	# Draw boundary cells with dark green
	if use_filled_edges:
		for cell in _boundary_cells:
			_draw_boundary_cell_fill(cell)

	# Draw selected cell with dark blue (on top of everything)
	if _selected_cell:
		_draw_selected_cell_fill(_selected_cell)

	# Draw border using selected method
	if use_string_pulling:
		_draw_string_pulled_border()


func _draw_cell_fill(cell: HexCell) -> void:
	# Draw the low-opacity fill for a traversable cell
	var center := cell.world_position
	var points := PackedVector2Array()

	for corner in _hex_corners:
		points.append(center + corner)

	draw_colored_polygon(points, traversable_fill_color)


func _draw_boundary_cell_fill(cell: HexCell) -> void:
	# Draw dark green fill for boundary cells
	var center := cell.world_position
	var points := PackedVector2Array()

	for corner in _hex_corners:
		points.append(center + corner)

	draw_colored_polygon(points, edge_fill_color)


func _draw_selected_cell_fill(cell: HexCell) -> void:
	# Draw dark blue fill for selected navigation cell
	var center := cell.world_position
	var points := PackedVector2Array()

	for corner in _hex_corners:
		points.append(center + corner)

	draw_colored_polygon(points, selected_cell_color)


func _draw_string_pulled_border() -> void:
	# Draw smooth curved border using string pulling
	if _boundary_curve.size() < 2:
		return

	# Draw the curve as connected line segments
	for i in range(_boundary_curve.size() - 1):
		draw_line(_boundary_curve[i], _boundary_curve[i + 1], border_color, border_width)


func _is_coord_navigable(coords: Vector2i) -> bool:
	# Check if coordinates are in the navigable set (O(1) lookup)
	return _navigable_coords_set.has(coords)
