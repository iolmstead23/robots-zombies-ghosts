class_name HexGridDebug
extends Node2D

## Debug visualization for hexagonal grid
## Shows navigable cells (within movement range) in green
## Shows non-navigable cells (outside movement range) in red
## Does not show disabled cells

@export var hex_grid: HexGrid
@export var session_controller: SessionController
@export var debug_enabled: bool = false

@export_group("Colors")
@export var navigable_outline_color: Color = Color(0.0, 0.8, 0.0, 1.0)  # Neutral green
@export var not_navigable_outline_color: Color = Color(0.8, 0.0, 0.0, 1.0)  # Neutral red
@export var outline_width: float = 1.0

var _hex_corners: PackedVector2Array

func _ready() -> void:
	z_index = -1  # Hex grid visualization above floor, below objects
	if hex_grid:
		_connect_grid_signals()
		_calculate_hex_corners()
	if session_controller:
		_connect_session_signals()

func _connect_grid_signals() -> void:
	if not hex_grid.grid_initialized.is_connected(_on_grid_initialized):
		hex_grid.grid_initialized.connect(_on_grid_initialized)
		hex_grid.cell_enabled_changed.connect(_on_cell_enabled_changed)

func _connect_session_signals() -> void:
	if not session_controller.navigable_cells_updated.is_connected(_on_navigable_cells_updated):
		session_controller.navigable_cells_updated.connect(_on_navigable_cells_updated)

func _calculate_hex_corners() -> void:
	_hex_corners.clear()
	if not hex_grid:
		return
	
	var size := hex_grid.hex_size
	var angle_offset := 0.0 if hex_grid.layout_flat_top else PI / 6.0
	
	for i in range(6):
		var angle := angle_offset + PI / 3.0 * i
		_hex_corners.append(Vector2(size * cos(angle), size * sin(angle)))

func _draw() -> void:
	if not debug_enabled or not hex_grid:
		return

	# Only draw enabled cells
	for cell in hex_grid.enabled_cells:
		_draw_hex_cell(cell)

func _draw_hex_cell(cell: HexCell) -> void:
	# Skip disabled cells entirely
	if not cell.enabled:
		return

	var pos := cell.world_position

	# Check if cell is navigable using SessionController
	var is_navigable := false
	if session_controller:
		is_navigable = session_controller.is_cell_navigable(cell)

	# Choose color based on navigability
	var color := navigable_outline_color if is_navigable else not_navigable_outline_color
	_draw_hex_outline(pos, color)

func _draw_hex_outline(center: Vector2, color: Color) -> void:
	for i in range(6):
		var next_i := (i + 1) % 6
		draw_line(center + _hex_corners[i], center + _hex_corners[next_i], color, outline_width)

func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled
	queue_redraw()

func _on_grid_initialized() -> void:
	_calculate_hex_corners()
	queue_redraw()

func _on_cell_enabled_changed(_cell: HexCell, _enabled: bool) -> void:
	if debug_enabled:
		queue_redraw()

func _on_navigable_cells_updated(_cells: Array[HexCell]) -> void:
	if debug_enabled:
		queue_redraw()
