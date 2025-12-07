class_name HexPathVisualizer
extends Node2D

# Visualizes paths on hexagonal grid with arrows and highlights

signal path_drawn(path: Array[HexCell])
signal path_cleared()

@export var hex_grid: HexGrid
@export var path_stroke_color: Color = Color(0.0, 0.2, 0.8, 1.0)  # Dark blue
@export var path_stroke_width: float = 3.0
@export_range(0.0, 1.0, 0.1) var string_pulling_tension: float = 0.5  # 0.0 = tight, 1.0 = loose
@export_range(1, 3, 1) var interpolation_layers: int = 1  # 1-3 layers of midpoint interpolation
@export var show_distance: bool = true
@export var distance_color: Color = Color.WHITE
@export var distance_background_color: Color = Color(0, 0, 0, 0.7)

var current_path: Array[HexCell] = []
var path_statistics: Dictionary = {}
var debug_enabled: bool = false

# String pulling
var _string_puller: HexStringPuller = null
var _smooth_path: PackedVector2Array = []

func _ready() -> void:
	z_index = -1  # Path visualization at hex cell level - matches traversable_area_visualizer
	_string_puller = HexStringPuller.new()
	_string_puller.smoothing_iterations = 3  # Moderate smoothing - 3 points per segment
	_string_puller.curve_method = HexStringPuller.CurveMethod.CATMULL_ROM
	_string_puller.interpolation_layers = interpolation_layers
	_string_puller.enable_string_pulling = true

func set_path(path: Array[HexCell]) -> void:
	current_path = path.duplicate()

	if path.size() > 0:
		_calculate_statistics()

		# Generate smooth pull string path with midpoint interpolation
		var hex_size_value := hex_grid.hex_size if hex_grid else 32.0
		_smooth_path = _string_puller.pull_string_through_path(
			current_path,
			string_pulling_tension,
			interpolation_layers,
			hex_size_value
		)

		path_drawn.emit(path)
		queue_redraw()
	else:
		clear_path()

func clear_path() -> void:
	current_path.clear()
	path_statistics.clear()
	_smooth_path.clear()
	path_cleared.emit()

	# Always redraw to clear any existing visualization
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
	# Path info logging disabled
	pass

func _draw() -> void:
	# Draw path visualization - always visible in both debug and normal gameplay
	if current_path.size() < 2:
		return

	_draw_smooth_path()

	if show_distance and current_path.size() > 0:
		_draw_distance_on_last_cell()

func _draw_smooth_path() -> void:
	# Draw smooth pull string path with dark blue stroke
	if _smooth_path.size() < 2:
		return

	# Draw connected line segments
	for i in range(_smooth_path.size() - 1):
		draw_line(_smooth_path[i], _smooth_path[i + 1], path_stroke_color, path_stroke_width)

func _draw_distance_on_last_cell() -> void:
	# Draw total distance number on the last hex cell
	var last_cell := current_path[current_path.size() - 1]
	var distance := get_path_distance()
	var pos := last_cell.world_position

	# Position text above the cell
	var offset := Vector2(0, -hex_grid.hex_size * 0.8) if hex_grid else Vector2(0, -25)
	var text_pos := pos + offset

	var font := ThemeDB.fallback_font
	var font_size := 20
	var text := str(distance)
	var string_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

	# Text only - no background circle
	var draw_pos := text_pos - string_size / 2
	draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, distance_color)

func set_debug_enabled(enabled: bool) -> void:
	# Kept for backwards compatibility - path is now always visible
	debug_enabled = enabled
	queue_redraw()

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

# ============================================================================
# INTERPOLATION LAYER CONTROL
# ============================================================================

func set_interpolation_layers(layers: int) -> void:
	# Set midpoint interpolation layers (1-3) for path smoothing
	interpolation_layers = clampi(layers, 1, 3)
	if _string_puller:
		_string_puller.interpolation_layers = interpolation_layers

	# Regenerate path if one exists
	if current_path.size() > 0:
		set_path(current_path)


func get_interpolation_layers() -> int:
	return interpolation_layers
