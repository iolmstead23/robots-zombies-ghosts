class_name HexPathVisualizer
extends Node2D

## Visualizes paths on hexagonal grid with arrows and highlights

signal path_drawn(path: Array[HexCell])
signal path_cleared()

@export var hex_grid: HexGrid
@export var path_color: Color = Color(0.0, 0.8, 1.0, 0.6)
@export var path_outline_color: Color = Color(0.0, 0.6, 1.0, 1.0)
@export var line_width: float = 5.0
@export var show_arrows: bool = true
@export var arrow_size: float = 10.0
@export var show_cell_numbers: bool = true
@export var number_color: Color = Color.WHITE

var current_path: Array[HexCell] = []
var path_statistics: Dictionary = {}

func _ready() -> void:
	z_index = 5

func set_path(path: Array[HexCell]) -> void:
	current_path = path.duplicate()
	
	if path.size() > 0:
		_calculate_statistics()
		path_drawn.emit(path)
		queue_redraw()
		
		if OS.is_debug_build():
			_print_path_info()
	else:
		clear_path()

func clear_path() -> void:
	current_path.clear()
	path_statistics.clear()
	path_cleared.emit()
	queue_redraw()

func get_current_path() -> Array[HexCell]:
	return current_path

func get_path_length() -> int:
	return current_path.size()

func get_path_distance() -> int:
	return max(0, current_path.size() - 1)

func get_statistics() -> Dictionary:
	return path_statistics

func _calculate_statistics() -> void:
	path_statistics.clear()
	
	if current_path.size() == 0:
		return
	
	var start_cell := current_path[0]
	var end_cell := current_path[current_path.size() - 1]
	var movement_cost := current_path.size() - 1
	var straight_distance := start_cell.distance_to(end_cell)
	
	path_statistics = {
		"path_length": current_path.size(),
		"movement_cost": movement_cost,
		"start_coords": Vector2i(start_cell.q, start_cell.r),
		"end_coords": Vector2i(end_cell.q, end_cell.r),
		"start_position": start_cell.world_position,
		"end_position": end_cell.world_position,
		"straight_line_distance": straight_distance,
		"path_efficiency": 0.0,
		"total_pixel_distance": _calculate_pixel_distance()
	}
	
	if movement_cost > 0:
		path_statistics["path_efficiency"] = float(straight_distance) / float(movement_cost)

func _calculate_pixel_distance() -> float:
	var total := 0.0
	for i in range(current_path.size() - 1):
		total += current_path[i].world_position.distance_to(current_path[i + 1].world_position)
	return total

func _print_path_info() -> void:
	print("\n=== Path Visualization ===")
	print("Length: %d cells | Cost: %d moves" % [path_statistics["path_length"], path_statistics["movement_cost"]])
	print("Route: (%d,%d) -> (%d,%d)" % [
		path_statistics["start_coords"].x, path_statistics["start_coords"].y,
		path_statistics["end_coords"].x, path_statistics["end_coords"].y
	])
	print("Direct: %d cells | Efficiency: %.1f%% | Pixels: %.1f" % [
		path_statistics["straight_line_distance"],
		path_statistics["path_efficiency"] * 100.0,
		path_statistics["total_pixel_distance"]
	])

func _draw() -> void:
	if current_path.size() < 2:
		return
	
	_draw_path_lines()
	_draw_cell_highlights()

func _draw_path_lines() -> void:
	for i in range(current_path.size() - 1):
		var start_pos := current_path[i].world_position
		var end_pos := current_path[i + 1].world_position
		
		draw_line(start_pos, end_pos, path_color, line_width)
		
		if show_arrows:
			_draw_arrow(start_pos, end_pos)

func _draw_cell_highlights() -> void:
	for i in range(current_path.size()):
		var cell := current_path[i]
		var pos := cell.world_position
		
		# Highlight
		if hex_grid:
			var radius := hex_grid.hex_size * 0.7
			var highlight := Color(path_color.r, path_color.g, path_color.b, 0.2)
			draw_circle(pos, radius, highlight)
		
		# Cell numbers
		if show_cell_numbers:
			_draw_cell_number(pos, i)

func _draw_cell_number(pos: Vector2, index: int) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 16
	var text := str(index)
	var string_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := pos - string_size / 2
	
	# Background
	draw_circle(pos, string_size.x * 0.6, Color(0, 0, 0, 0.7))
	
	# Text
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, number_color)

func _draw_arrow(from: Vector2, to: Vector2) -> void:
	var direction := (to - from).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var arrow_base := to - direction * arrow_size
	var wing1 := arrow_base - direction * arrow_size + perpendicular * arrow_size * 0.5
	var wing2 := arrow_base - direction * arrow_size - perpendicular * arrow_size * 0.5
	
	var arrow_points := PackedVector2Array([to, wing1, wing2])
	draw_colored_polygon(arrow_points, path_outline_color)

func export_path_data() -> Dictionary:
	var export_data := path_statistics.duplicate()
	export_data["timestamp"] = Time.get_datetime_string_from_system()
	export_data["cells"] = []
	
	for cell in current_path:
		export_data["cells"].append({
			"q": cell.q,
			"r": cell.r,
			"world_pos": cell.world_position,
			"enabled": cell.enabled
		})
	
	return export_data