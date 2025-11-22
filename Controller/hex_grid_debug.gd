class_name HexGridDebug
extends Node2D

## Debug visualization for the hexagonal grid system
## Displays hex outlines, indices, and coordinates

@export var hex_grid: HexGrid  ## Reference to the HexGrid controller
@export var debug_enabled: bool = false  ## Toggle debug visualization
@export var show_indices: bool = true  ## Show cell index numbers
@export var show_coordinates: bool = true  ## Show axial coordinates
@export var show_disabled_outlines: bool = false  ## Show outlines for disabled cells

## Visual styling
@export_group("Colors")
@export var enabled_outline_color: Color = Color.GREEN
@export var disabled_outline_color: Color = Color.RED.darkened(0.3)
@export var outline_width: float = 2.0
@export var text_color: Color = Color.WHITE
@export var disabled_text_color: Color = Color.DARK_GRAY

@export_group("Font")
@export var font_size: int = 12

## Internal state
var _debug_font: Font
var _hex_corners: PackedVector2Array

func _ready() -> void:
	# Get default font
	_debug_font = ThemeDB.fallback_font
	
	# Connect to grid signals if grid is set
	if hex_grid:
		_connect_grid_signals()
	
	# Pre-calculate hex corner positions
	_calculate_hex_corners()

func _connect_grid_signals() -> void:
	if hex_grid.grid_initialized.is_connected(_on_grid_initialized):
		return
	
	hex_grid.grid_initialized.connect(_on_grid_initialized)
	hex_grid.cell_enabled_changed.connect(_on_cell_enabled_changed)

func _calculate_hex_corners() -> void:
	"""Pre-calculate the corner positions of a hexagon"""
	_hex_corners.clear()
	
	if not hex_grid:
		return
	
	var size: float = hex_grid.hex_size
	var angle_offset: float = 0.0 if hex_grid.layout_flat_top else PI / 6.0
	
	for i in range(6):
		var angle: float = angle_offset + PI / 3.0 * i
		var corner := Vector2(
			size * cos(angle),
			size * sin(angle)
		)
		_hex_corners.append(corner)

func _draw() -> void:
	if not debug_enabled or not hex_grid:
		return
	
	_draw_hex_grid()

func _draw_hex_grid() -> void:
	"""Draw all hex cells with debug information"""
	for cell in hex_grid.cells:
		if cell.enabled or show_disabled_outlines:
			_draw_hex_cell(cell)

func _draw_hex_cell(cell: HexCell) -> void:
	"""Draw a single hex cell with debug info"""
	var pos: Vector2 = cell.world_position
	var color: Color = enabled_outline_color if cell.enabled else disabled_outline_color
	
	# Draw hex outline
	if cell.enabled or show_disabled_outlines:
		_draw_hex_outline(pos, color)
	
	# Draw text info only for enabled cells (or if configured otherwise)
	if cell.enabled:
		_draw_cell_info(cell, pos)

func _draw_hex_outline(center: Vector2, color: Color) -> void:
	"""Draw hexagon outline"""
	for i in range(6):
		var start: Vector2 = center + _hex_corners[i]
		var end: Vector2 = center + _hex_corners[(i + 1) % 6]
		draw_line(start, end, color, outline_width)

func _draw_cell_info(cell: HexCell, pos: Vector2) -> void:
	"""Draw cell index and coordinates"""
	var text_lines: Array[String] = []
	
	if show_indices:
		text_lines.append(str(cell.index))
	
	if show_coordinates:
		text_lines.append("(%d,%d)" % [cell.q, cell.r])
	
	if text_lines.is_empty():
		return
	
	var color: Color = text_color if cell.enabled else disabled_text_color
	var line_height: float = font_size + 2
	var total_height: float = text_lines.size() * line_height
	var start_y: float = pos.y - total_height / 2.0
	
	for i in range(text_lines.size()):
		var text: String = text_lines[i]
		var text_size: Vector2 = _debug_font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := Vector2(
			pos.x - text_size.x / 2.0,
			start_y + line_height * i + font_size
		)
		draw_string(_debug_font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func set_debug_enabled(enabled: bool) -> void:
	"""Toggle debug visualization on/off"""
	debug_enabled = enabled
	queue_redraw()

func toggle_debug() -> void:
	"""Toggle debug mode"""
	set_debug_enabled(not debug_enabled)

func _on_grid_initialized() -> void:
	"""Called when grid is initialized"""
	_calculate_hex_corners()
	queue_redraw()

func _on_cell_enabled_changed(_cell: HexCell, _enabled: bool) -> void:
	"""Called when a cell's enabled state changes"""
	if debug_enabled:
		queue_redraw()

func highlight_cell(cell: HexCell, color: Color = Color.YELLOW) -> void:
	"""Temporarily highlight a specific cell"""
	if not debug_enabled:
		return
	
	var pos: Vector2 = cell.world_position
	_draw_hex_outline(pos, color)

func highlight_cells(cells: Array[HexCell], color: Color = Color.YELLOW) -> void:
	"""Temporarily highlight multiple cells"""
	for cell in cells:
		highlight_cell(cell, color)

func _process(_delta: float) -> void:
	# Optional: add continuous redraw if needed
	# For now, we only redraw when things change
	pass

func _input(event: InputEvent) -> void:
	# Optional: add input handling for debug controls
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F3:
			toggle_debug()
			get_viewport().set_input_as_handled()
