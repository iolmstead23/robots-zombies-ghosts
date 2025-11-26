class_name HexCellSelector
extends Node2D

## Handles hex cell selection with visual feedback

signal cell_selected(cell: HexCell)
signal cell_deselected()

@export var hex_grid: HexGrid
@export var highlight_color: Color = Color(1.0, 1.0, 0.0, 0.5)
@export var highlight_outline_color: Color = Color(1.0, 0.8, 0.0, 1.0)
@export var outline_width: float = 3.0
@export var pulse_enabled: bool = true
@export var pulse_speed: float = 2.0
@export var pulse_min_alpha: float = 0.3
@export var pulse_max_alpha: float = 0.7

var selected_cell: HexCell = null
var pulse_time: float = 0.0

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
	var alpha_multiplier := _calculate_pulse_alpha()
	
	# Draw filled hexagon with pulsing transparency
	var fill_color := highlight_color
	fill_color.a = highlight_color.a * alpha_multiplier
	_draw_hexagon(pos, size * 0.9, fill_color, true)
	
	# Draw outline (no pulse)
	_draw_hexagon(pos, size * 0.95, highlight_outline_color, false)

func _calculate_pulse_alpha() -> float:
	if not pulse_enabled:
		return 1.0
	
	var pulse_value := (sin(pulse_time) + 1.0) / 2.0
	return lerp(pulse_min_alpha, pulse_max_alpha, pulse_value)

func _draw_hexagon(center: Vector2, radius: float, color: Color, filled: bool) -> void:
	var points := PackedVector2Array()
	
	for i in range(6):
		var angle_deg := 60.0 * i
		var angle_rad := deg_to_rad(angle_deg)
		var x := center.x + radius * cos(angle_rad)
		var y := center.y + radius * sin(angle_rad)
		points.append(Vector2(x, y))
	
	if filled:
		draw_colored_polygon(points, color)
	else:
		for i in range(6):
			var next_i := (i + 1) % 6
			draw_line(points[i], points[next_i], color, outline_width)
