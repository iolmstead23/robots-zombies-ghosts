class_name HexGridDebug
extends Node2D

## Debug visualization for the hexagonal grid system

# --- Exported Properties ---
@export var hex_grid: HexGrid                         # Reference to HexGrid controller
@export var debug_enabled: bool = false               # Toggle debug visualization
@export var show_indices: bool = true                 # Show cell index numbers
@export var show_coordinates: bool = true             # Show axial coordinates
@export var show_disabled_outlines: bool = false      # Show outlines for disabled cells

# --- Visual Styling ---
@export_group("Colors")
@export var enabled_outline_color: Color = Color.GREEN
@export var disabled_outline_color: Color = Color.RED.darkened(0.3)
@export var outline_width: float = 2.0
@export var text_color: Color = Color.WHITE
@export var disabled_text_color: Color = Color.DARK_GRAY
@export_group("Font")
@export var font_size: int = 12

# --- Internal State ---
var _debug_font: Font
var _hex_corners: PackedVector2Array

# --- Ready / Initialization ---
func _ready() -> void:
	_debug_font = ThemeDB.fallback_font
	if hex_grid:
		_connect_grid_signals()
		_calculate_hex_corners()

func _connect_grid_signals() -> void:
	if not hex_grid.grid_initialized.is_connected(_on_grid_initialized):
		hex_grid.grid_initialized.connect(_on_grid_initialized)
		hex_grid.cell_enabled_changed.connect(_on_cell_enabled_changed)

func _calculate_hex_corners() -> void:
	"""Pre-calculate corners for drawing hexes"""
	_hex_corners.clear()
	if not hex_grid: return
	var size := hex_grid.hex_size
	var angle_offset := 0.0 if hex_grid.layout_flat_top else PI / 6.0
	for i in range(6):
		var angle := angle_offset + PI / 3.0 * i
		_hex_corners.append(Vector2(size * cos(angle), size * sin(angle)))

# --- Main Draw Loop ---
func _draw() -> void:
	if debug_enabled and hex_grid:
		_draw_hex_grid()

func _draw_hex_grid() -> void:
	"""Draw all hex cells"""
	for cell in hex_grid.cells:
		if cell.enabled or show_disabled_outlines:
			_draw_hex_cell(cell)

func _draw_hex_cell(cell: HexCell) -> void:
	"""Draw outline & info for one cell"""
	var pos := cell.world_position
	var outline_color := enabled_outline_color if cell.enabled else disabled_outline_color
	_draw_hex_outline(pos, outline_color)
	if cell.enabled:
		_draw_cell_info(cell, pos)

func _draw_hex_outline(center: Vector2, color: Color) -> void:
	"""Draw hex outline"""
	for i in range(6):
		draw_line(center + _hex_corners[i], center + _hex_corners[(i + 1) % 6], color, outline_width)

func _draw_cell_info(cell: HexCell, pos: Vector2) -> void:
	"""Draw cell index and/or coordinates"""
	var lines := []
	if show_indices: lines.append(str(cell.index))
	if show_coordinates: lines.append("(%d,%d)" % [cell.q, cell.r])
	if lines.is_empty(): return

	var fg := text_color if cell.enabled else disabled_text_color
	var line_height := font_size + 2
	var start_y := pos.y - (lines.size() * line_height) / 2.0

	for i in range(lines.size()):
		var text: String = lines[i]
		var tw := _debug_font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := Vector2(pos.x - tw.x / 2.0, start_y + line_height * i + font_size)
		draw_string(_debug_font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg)

# --- Debug Toggling ---
func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled
	queue_redraw()

func toggle_debug() -> void:
	set_debug_enabled(not debug_enabled)

# --- Signal Callbacks ---
func _on_grid_initialized() -> void:
	_calculate_hex_corners()
	queue_redraw()

func _on_cell_enabled_changed(_cell: HexCell, _enabled: bool) -> void:
	if debug_enabled: queue_redraw()

# --- Debug Tooling ---
func highlight_cell(cell: HexCell, color: Color = Color.YELLOW) -> void:
	"""Highlight a specific cell temporarily"""
	if debug_enabled:
		_draw_hex_outline(cell.world_position, color)

func highlight_cells(cells: Array[HexCell], color: Color = Color.YELLOW) -> void:
	for cell in cells:
		highlight_cell(cell, color)

# --- Input For Debug ---
func _input(event: InputEvent) -> void:
	# Toggle debug mode with F3 key
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		toggle_debug()
		get_viewport().set_input_as_handled()

# --- (Optional) Update Loop Stub ---
func _process(_delta: float) -> void:
	# No continuous redraw (for performance); use breakpoints/logs for step debugging if needed.
	pass
