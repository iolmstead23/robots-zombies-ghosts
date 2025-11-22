extends Node2D

## Hex Grid Offset Calibration Tool
## Use arrow keys to adjust grid offset until it aligns with your scene

@export var session_controller: SessionController
@export var adjustment_speed: float = 10.0  # Pixels per adjustment

var grid: HexGrid
var offset_label: Label

func _ready() -> void:
	grid = session_controller.get_terrain()
	
	# Create UI label
	offset_label = Label.new()
	offset_label.position = Vector2(10, 40)
	offset_label.add_theme_font_size_override("font_size", 16)
	add_child(offset_label)
	
	# Enable debug mode automatically
	session_controller.set_debug_mode(true)
	
	print("\n=== HEX GRID OFFSET CALIBRATION ===")
	print("Current offset: ", grid.grid_offset)
	print("\nControls:")
	print("  Arrow Keys - Adjust grid offset")
	print("  Shift + Arrows - Fine adjustment (1px)")
	print("  Ctrl + Arrows - Large adjustment (50px)")
	print("  R - Reset to NavigationRegion position")
	print("  P - Print current offset")
	print("  C - Copy offset to clipboard")
	print("====================================\n")
	
	_update_label()

func _process(_delta: float) -> void:
	var adjustment = Vector2.ZERO
	var speed = adjustment_speed
	
	# Modify speed with modifiers
	if Input.is_key_pressed(KEY_SHIFT):
		speed = 1.0  # Fine adjustment
	elif Input.is_key_pressed(KEY_CTRL):
		speed = 50.0  # Large adjustment
	
	# Arrow key input
	if Input.is_action_just_pressed("ui_left"):
		adjustment.x -= speed
	if Input.is_action_just_pressed("ui_right"):
		adjustment.x += speed
	if Input.is_action_just_pressed("ui_up"):
		adjustment.y -= speed
	if Input.is_action_just_pressed("ui_down"):
		adjustment.y += speed
	
	# Apply adjustment
	if adjustment != Vector2.ZERO:
		grid.grid_offset += adjustment
		_recalculate_cell_positions()
		_update_label()
		queue_redraw()
		
		print("Offset adjusted to: ", grid.grid_offset)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			# Reset to navigation region position
			_reset_offset()
		
		elif event.keycode == KEY_P:
			# Print current offset
			print("\n=== CURRENT GRID OFFSET ===")
			print("grid.grid_offset = Vector2(%.1f, %.1f)" % [grid.grid_offset.x, grid.grid_offset.y])
			print("===========================\n")
		
		elif event.keycode == KEY_C:
			# Copy to clipboard
			var offset_string = "grid.grid_offset = Vector2(%.1f, %.1f)" % [grid.grid_offset.x, grid.grid_offset.y]
			DisplayServer.clipboard_set(offset_string)
			print("✓ Copied to clipboard: ", offset_string)

func _reset_offset() -> void:
	"""Reset offset to NavigationRegion2D position"""
	if session_controller.navigation_region:
		grid.grid_offset = session_controller.navigation_region.global_position
		_recalculate_cell_positions()
		_update_label()
		queue_redraw()
		print("Offset reset to NavigationRegion position: ", grid.grid_offset)
	else:
		grid.grid_offset = Vector2.ZERO
		_recalculate_cell_positions()
		_update_label()
		queue_redraw()
		print("Offset reset to (0, 0)")

func _recalculate_cell_positions() -> void:
	"""Recalculate all cell world positions after offset change"""
	for cell in grid.cells:
		cell.world_position = grid._axial_to_world_position(cell.q, cell.r)
	
	# Force debug redraw
	if session_controller.hex_grid_debug:
		session_controller.hex_grid_debug.queue_redraw()

func _update_label() -> void:
	"""Update the on-screen label"""
	if offset_label:
		offset_label.text = "Grid Offset: (%.1f, %.1f)\n" % [grid.grid_offset.x, grid.grid_offset.y]
		offset_label.text += "Arrow Keys to adjust\nShift=Fine, Ctrl=Large\nR=Reset, P=Print, C=Copy"

func _draw() -> void:
	# Draw crosshair at grid offset
	var offset = grid.grid_offset
	var size = 30.0
	
	# Red crosshair
	draw_line(offset - Vector2(size, 0), offset + Vector2(size, 0), Color.RED, 4.0)
	draw_line(offset - Vector2(0, size), offset + Vector2(0, size), Color.RED, 4.0)
	draw_circle(offset, 8, Color.RED)
	
	# Draw grid bounds
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	for cell in grid.cells:
		min_pos.x = min(min_pos.x, cell.world_position.x)
		min_pos.y = min(min_pos.y, cell.world_position.y)
		max_pos.x = max(max_pos.x, cell.world_position.x)
		max_pos.y = max(max_pos.y, cell.world_position.y)
	
	# Yellow bounding box
	var bounds = Rect2(min_pos - Vector2(50, 50), max_pos - min_pos + Vector2(100, 100))
	draw_rect(bounds, Color.YELLOW, false, 3.0)
	
	# Draw first cell marker
	if grid.cells.size() > 0:
		var first_cell = grid.cells[0]
		draw_circle(first_cell.world_position, 15, Color.CYAN)
		draw_string(ThemeDB.fallback_font, first_cell.world_position + Vector2(-10, -20), 
			"FIRST (0,0)", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.CYAN)

## TESTING HELPERS

func test_click_detection() -> void:
	"""Test if cells are properly clickable"""
	print("\n=== CLICK DETECTION TEST ===")
	
	var test_positions = [
		grid.grid_offset,  # Origin
		grid.cells[0].world_position if grid.cells.size() > 0 else Vector2.ZERO,  # First cell
		grid.cells[grid.cells.size() / 2].world_position if grid.cells.size() > 0 else Vector2.ZERO,  # Middle
	]
	
	for pos in test_positions:
		var cell = grid.get_cell_at_world_position(pos)
		if cell:
			print("✓ Position %s found cell (%d, %d)" % [pos, cell.q, cell.r])
		else:
			print("✗ Position %s NO CELL FOUND" % pos)
	
	print("============================\n")
