class_name DebugController
extends Node

## Manages debug visualization and data for the game session
## Communicates exclusively through signals - no direct dependencies on other features

# ============================================================================
# SIGNALS - Public API
# ============================================================================

## Emitted when debug visibility changes
signal debug_visibility_changed(visible: bool)

## Emitted when specific debug info is updated
signal debug_info_updated(key: String, value: Variant)

## Emitted when hovered cell changes
signal hovered_cell_changed(cell: HexCell)

# ============================================================================
# SIGNALS - Commands (Received from SessionController or UI)
# ============================================================================

## Request to toggle debug visibility
signal toggle_debug_requested()

## Request to set debug visibility
signal set_debug_visibility_requested(visible: bool)

## Request to update specific debug information
signal update_debug_info_requested(key: String, value: Variant)

# ============================================================================
# SIGNALS - State Updates (Received from SessionController)
# ============================================================================

## Receive session state updates
signal on_session_state_changed(state_data: Dictionary)

## Receive grid state updates
signal on_grid_state_changed(grid_data: Dictionary)

## Receive navigation state updates
signal on_navigation_state_changed(nav_data: Dictionary)

# ============================================================================
# STATE
# ============================================================================

var debug_visible: bool = false  # Default to hidden to match SessionController
var debug_data: Dictionary = {}
var hovered_cell: HexCell = null

# Reference to SessionController (for checking navigability)
var session_controller = null

# Visualization components (will be set by SessionController)
var hex_grid_debug: HexGridDebug = null
var hex_path_visualizer: HexPathVisualizer = null
var hex_cell_hover_visualizer: HexCellHoverVisualizer = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	# Initialize debug data with default values
	debug_data = {
		"fps": 0,
		"entities": 0,
		"player_pos": Vector2.ZERO,
		"session_active": false,
		"grid_cells": 0,
		"enabled_cells": 0,
		"disabled_cells": 0,
		"navigation_active": false,
		"path_length": 0
	}

	# Connect to own command signals
	toggle_debug_requested.connect(_on_toggle_debug_requested)
	set_debug_visibility_requested.connect(_on_set_debug_visibility_requested)
	update_debug_info_requested.connect(_on_update_debug_info_requested)

	# Connect to state update signals
	on_session_state_changed.connect(_on_session_state_changed)
	on_grid_state_changed.connect(_on_grid_state_changed)
	on_navigation_state_changed.connect(_on_navigation_state_changed)

# ============================================================================
# COMMAND HANDLERS
# ============================================================================

func _on_toggle_debug_requested():
	set_debug_visibility(!debug_visible)

func _on_set_debug_visibility_requested(visible: bool):
	set_debug_visibility(visible)

func _on_update_debug_info_requested(key: String, value: Variant):
	update_debug_info(key, value)

# ============================================================================
# STATE UPDATE HANDLERS
# ============================================================================

func _on_session_state_changed(state_data: Dictionary):
	# Update debug data based on session state
	if state_data.has("active"):
		update_debug_info("session_active", state_data.active)
	if state_data.has("duration"):
		update_debug_info("session_duration", state_data.duration)

func _on_grid_state_changed(grid_data: Dictionary):
	# Update debug data based on grid state
	if grid_data.has("total_cells"):
		update_debug_info("grid_cells", grid_data.total_cells)
	if grid_data.has("enabled_cells"):
		update_debug_info("enabled_cells", grid_data.enabled_cells)
	if grid_data.has("disabled_cells"):
		update_debug_info("disabled_cells", grid_data.disabled_cells)

func _on_navigation_state_changed(nav_data: Dictionary):
	# Update debug data based on navigation state
	if nav_data.has("active"):
		update_debug_info("navigation_active", nav_data.active)
	if nav_data.has("path_length"):
		update_debug_info("path_length", nav_data.path_length)
	if nav_data.has("remaining_distance"):
		update_debug_info("remaining_distance", nav_data.remaining_distance)

# ============================================================================
# PUBLIC API (called internally via signals)
# ============================================================================

func set_debug_visibility(visible: bool):
	debug_visible = visible

	# Update visualization components if they exist
	if hex_grid_debug:
		hex_grid_debug.set_debug_enabled(visible)

	if hex_path_visualizer:
		hex_path_visualizer.set_debug_enabled(visible)

	# Hover visualizer is inverse - enabled when debug is OFF, disabled when debug is ON
	if hex_cell_hover_visualizer:
		hex_cell_hover_visualizer.set_hover_enabled(not visible)

	debug_visibility_changed.emit(debug_visible)

func update_debug_info(key: String, value: Variant):
	debug_data[key] = value
	debug_info_updated.emit(key, value)

func get_debug_info(key: String) -> Variant:
	return debug_data.get(key, null)

func get_all_debug_info() -> Dictionary:
	return debug_data.duplicate()

# ============================================================================
# VISUALIZATION COMPONENT MANAGEMENT
# ============================================================================

func set_hex_grid_debug(debug_node: HexGridDebug):
	hex_grid_debug = debug_node
	if hex_grid_debug:
		hex_grid_debug.set_debug_enabled(debug_visible)

func set_hex_path_visualizer(visualizer: HexPathVisualizer):
	hex_path_visualizer = visualizer
	if hex_path_visualizer:
		hex_path_visualizer.set_debug_enabled(debug_visible)

func set_hex_cell_hover_visualizer(visualizer: HexCellHoverVisualizer):
	hex_cell_hover_visualizer = visualizer
	if hex_cell_hover_visualizer:
		# Hover visualizer is enabled when debug mode is OFF
		hex_cell_hover_visualizer.set_hover_enabled(not debug_visible)

# ============================================================================
# HOVERED CELL MANAGEMENT
# ============================================================================

func set_hovered_cell(cell: HexCell) -> void:
	"""Update the currently hovered cell"""
	if hovered_cell != cell:
		hovered_cell = cell
		hovered_cell_changed.emit(cell)

		# Update hover visualizer
		if hex_cell_hover_visualizer:
			if cell:
				hex_cell_hover_visualizer.set_hovered_cell(cell)
			else:
				hex_cell_hover_visualizer.clear_hovered_cell()

		# Update debug data with cell information
		if cell:
			update_debug_info("hovered_cell_q", cell.q)
			update_debug_info("hovered_cell_r", cell.r)
			update_debug_info("hovered_cell_index", cell.index)
			update_debug_info("hovered_cell_enabled", cell.enabled)
			update_debug_info("hovered_cell_world_pos", cell.world_position)

			# Check if cell is navigable
			var is_navigable = false
			if session_controller:
				is_navigable = session_controller.is_cell_navigable(cell)
			update_debug_info("hovered_cell_navigable", is_navigable)

			# Add metadata if available
			if cell.metadata.size() > 0:
				update_debug_info("hovered_cell_metadata", cell.metadata)
		else:
			# Clear hovered cell info
			update_debug_info("hovered_cell_q", null)
			update_debug_info("hovered_cell_r", null)
			update_debug_info("hovered_cell_index", null)
			update_debug_info("hovered_cell_enabled", null)
			update_debug_info("hovered_cell_navigable", null)
			update_debug_info("hovered_cell_world_pos", null)
			update_debug_info("hovered_cell_metadata", null)

func get_hovered_cell() -> HexCell:
	"""Get the currently hovered cell"""
	return hovered_cell
