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
@export var rejection_pulse_width: float = 4.0  # Thicker outline for pulse
@export var rejection_pulse_duration: float = 0.3  # Duration of rejection pulse in seconds

var hovered_cell: HexCell = null
var hover_enabled: bool = true
var io_controller: IOController = null
var _rejection_pulse_active: bool = false
var _rejection_pulse_cell: HexCell = null

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

## Set IO controller and connect to rejection signal
func set_io_controller(controller: IOController) -> void:
	io_controller = controller
	if io_controller and io_controller.has_signal("hex_cell_click_rejected"):
		if not io_controller.hex_cell_click_rejected.is_connected(_on_cell_click_rejected):
			io_controller.hex_cell_click_rejected.connect(_on_cell_click_rejected)

## Handle rejected click with visual pulse feedback
func _on_cell_click_rejected(cell: HexCell) -> void:
	if not cell:
		return

	# Store the rejected cell and activate pulse
	_rejection_pulse_cell = cell
	_rejection_pulse_active = true
	queue_redraw()

	# Create tween to fade out the pulse
	var tween = create_tween()
	tween.tween_callback(_clear_rejection_pulse).set_delay(rejection_pulse_duration)

## Clear the rejection pulse feedback
func _clear_rejection_pulse() -> void:
	_rejection_pulse_active = false
	_rejection_pulse_cell = null
	queue_redraw()

func _draw() -> void:
	if not hex_grid:
		return

	# Draw rejection pulse first (behind hover outline)
	if _rejection_pulse_active and _rejection_pulse_cell:
		var pos := _rejection_pulse_cell.world_position
		var size := hex_grid.hex_size
		# Draw thicker red outline for rejection pulse
		if hex_grid.use_isometric_transform:
			HexGeometry.draw_isometric_hexagon_outline(self, pos, size * 0.95, not_navigable_color, rejection_pulse_width)
		else:
			HexGeometry.draw_hexagon_outline(self, pos, size * 0.95, not_navigable_color, rejection_pulse_width)

	# Draw normal hover outline
	if not hover_enabled or not hovered_cell:
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
	if hex_grid.use_isometric_transform:
		HexGeometry.draw_isometric_hexagon_outline(self, pos, size * 0.95, outline_color, outline_width)
	else:
		HexGeometry.draw_hexagon_outline(self, pos, size * 0.95, outline_color, outline_width)
