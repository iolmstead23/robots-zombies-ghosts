class_name HexCellSelector
extends Node2D

## Handles hex cell selection with visual feedback

signal cell_selected(cell: HexCell)
signal cell_deselected()

@export var hex_grid: HexGrid
@export var highlight_outline_color: Color = Color(0.0, 1.0, 1.0, 1.0)  # Bright cyan
@export var disabled_highlight_color: Color = Color.RED
@export var outline_width: float = 2.0
@export var pulse_enabled: bool = false

var selected_cell: HexCell = null
var pulse_time: float = 0.0
var pulse_speed: int = 2

func _ready() -> void:
	z_index = 10

func _process(delta: float) -> void:
	if pulse_enabled and selected_cell:
		pulse_time += delta * pulse_speed
		queue_redraw()

func select_cell(cell: HexCell) -> void:
	if cell == selected_cell:
		return
	
	var previous_cell := selected_cell
	selected_cell = cell
	pulse_time = 0.0
	
	if previous_cell:
		cell_deselected.emit()
	
	cell_selected.emit(cell)
	queue_redraw()
	
	if OS.is_debug_build():
		print("HexCellSelector: Cell (%d,%d) selected at %s" % [cell.q, cell.r, cell.world_position])

func deselect_cell() -> void:
	if not selected_cell:
		return
	
	selected_cell = null
	cell_deselected.emit()
	queue_redraw()

func get_selected_cell() -> HexCell:
	return selected_cell

func _draw() -> void:
	if not selected_cell or not hex_grid:
		return

	var pos := selected_cell.world_position
	var size := hex_grid.hex_size

	# Choose color based on cell enabled state
	var outline_color := highlight_outline_color if selected_cell.enabled else disabled_highlight_color

	# Draw outline only (no fill)
	HexGeometry.draw_hexagon_outline(self, pos, size * 0.95, outline_color, outline_width)
