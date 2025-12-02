class_name HexCellHoverVisualizer
extends Node2D

## Handles hex cell hover visualization with color-coded feedback based on navigability
## Green outline = cell is navigable (within movement range)
## Red outline = cell is not navigable (outside movement range)
## No outline = cell is disabled

@export var hex_grid: HexGrid
@export var session_controller: SessionController
@export var navigable_color: Color = Color(0.0, 0.8, 0.0, 1.0)  # Neutral green
@export var not_navigable_color: Color = Color(0.8, 0.0, 0.0, 1.0)  # Neutral red
@export var outline_width: float = 2.0

var hovered_cell: HexCell = null
var hover_enabled: bool = true

func _ready() -> void:
	z_index = 5  # Above grid debug (-1), below selector (10)

## Sets the currently hovered cell and triggers redraw
func set_hovered_cell(cell: HexCell) -> void:
	if cell == hovered_cell:
		return

	hovered_cell = cell
	queue_redraw()

## Clears the hovered cell and triggers redraw
func clear_hovered_cell() -> void:
	if not hovered_cell:
		return

	hovered_cell = null
	queue_redraw()

## Enable or disable hover visualization
func set_hover_enabled(enabled: bool) -> void:
	if hover_enabled == enabled:
		return

	hover_enabled = enabled
	queue_redraw()

func _draw() -> void:
	# Don't draw if hover is disabled or no cell is hovered
	if not hover_enabled or not hovered_cell or not hex_grid:
		return

	# Don't draw disabled cells
	if not hovered_cell.enabled:
		return

	# Check if cell is navigable using SessionController
	var is_navigable := false
	if session_controller:
		is_navigable = session_controller.is_cell_navigable(hovered_cell)

	# Choose color based on navigability
	var outline_color := navigable_color if is_navigable else not_navigable_color

	# Draw hex outline
	var pos := hovered_cell.world_position
	var size := hex_grid.hex_size
	_draw_hexagon(pos, size * 0.95, outline_color)

func _draw_hexagon(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()

	# Generate hexagon points (flat-top orientation)
	for i in range(6):
		var angle_deg := 60.0 * i
		var angle_rad := deg_to_rad(angle_deg)
		var x := center.x + radius * cos(angle_rad)
		var y := center.y + radius * sin(angle_rad)
		points.append(Vector2(x, y))

	# Draw outline
	for i in range(6):
		var next_i := (i + 1) % 6
		draw_line(points[i], points[next_i], color, outline_width)
