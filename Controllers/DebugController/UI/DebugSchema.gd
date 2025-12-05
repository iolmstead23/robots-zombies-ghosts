class_name DebugSchema
extends ContentSchema

## Debug Overlay Schema
## Manages content structure for debug information including FPS, grid stats, and cell details

# ============================================================================
# INITIALIZATION
# ============================================================================

func _initialize_sections() -> void:
	"""Define sections for debug overlay content"""
	# Performance - Highest priority
	add_section("Performance", 3, 100)

	# Grid Info - High priority
	add_section("Grid Info", 4, 90)

	# Navigation - Medium priority
	add_section("Navigation", 3, 80)

	# Hovered Cell - Lower priority, can be truncated
	add_section("Hovered Cell", -1, 70)  # -1 = no per-section limit

# ============================================================================
# CONTENT UPDATES
# ============================================================================

func update_from_debug_data(debug_data: Dictionary) -> void:
	"""
	Update all sections with debug data.

	Args:
		debug_data: Dictionary containing all debug information
	"""
	_update_performance(debug_data)
	_update_grid_info(debug_data)
	_update_navigation(debug_data)
	_update_hovered_cell(debug_data)

func _update_performance(data: Dictionary) -> void:
	"""Update Performance section"""
	var section = get_section("Performance")
	if not section:
		return

	section.clear()
	var fps = data.get("fps", 0)
	if fps == null:
		fps = 0
	fps = int(fps)

	var frame_time = data.get("frame_time", 0.0)
	if frame_time == null:
		frame_time = 0.0
	frame_time = float(frame_time)

	section.add_line("FPS: %s" % [fps])
	section.add_line("Frame Time: %.2f ms" % [frame_time])

func _update_grid_info(data: Dictionary) -> void:
	"""Update Grid Info section"""
	var section = get_section("Grid Info")
	if not section:
		return

	section.clear()

	var total = data.get("total_cells", 0)
	if total == null:
		total = 0
	total = int(total)

	var enabled = data.get("enabled_cells", 0)
	if enabled == null:
		enabled = 0
	enabled = int(enabled)

	var disabled = data.get("disabled_cells", 0)
	if disabled == null:
		disabled = 0
	disabled = int(disabled)

	var navigable = data.get("navigable_cells", 0)
	if navigable == null:
		navigable = 0
	navigable = int(navigable)

	section.add_line("Grid: %d (%d/%d)" % [total, enabled, disabled])
	section.add_line("Navigable: %d cells" % [navigable])

func _update_navigation(data: Dictionary) -> void:
	"""Update Navigation section"""
	var section = get_section("Navigation")
	if not section:
		return

	section.clear()

	var agent_pos = data.get("agent_position", Vector2.ZERO)
	if agent_pos == null:
		agent_pos = Vector2.ZERO
	section.add_line("Agent at: (%d, %d)" % [agent_pos.x, agent_pos.y])

	var path_length = data.get("path_length", 0)
	if path_length == null:
		path_length = 0
	path_length = int(path_length)
	if path_length > 0:
		section.add_line("Path length: %d" % [path_length])

func _update_hovered_cell(data: Dictionary) -> void:
	"""Update Hovered Cell section"""
	var section = get_section("Hovered Cell")
	if not section:
		return

	section.clear()

	var hovered_data = data.get("hovered_cell", {})
	if hovered_data.is_empty():
		section.add_line("(No cell hovered)")
		return

	section.add_line("--- HOVERED CELL ---")

	# Coordinates
	var coords = hovered_data.get("coords", Vector2.ZERO)
	if coords == null:
		coords = Vector2.ZERO
	var index = hovered_data.get("index", -1)
	if index == null:
		index = -1
	index = int(index)
	section.add_line("Coords: (%d, %d) #%d" % [
		coords.x,
		coords.y,
		index
	])

	# State
	var state = hovered_data.get("state", "Unknown")
	section.add_line("State: %s" % state)

	# Navigable
	var navigable = hovered_data.get("navigable", false)
	section.add_line("Navigable: %s" % ("YES" if navigable else "NO"))

	# Position
	var pos = hovered_data.get("position", Vector2.ZERO)
	if pos == null:
		pos = Vector2.ZERO
	section.add_line("Pos: (%.0f, %.0f)" % [pos.x, pos.y])

	# Additional metadata
	var metadata = hovered_data.get("metadata", {})
	if not metadata.is_empty():
		for key in metadata:
			section.add_line("%s: %s" % [key, str(metadata[key])])

# ============================================================================
# UTILITY
# ============================================================================

func clear_hovered_cell() -> void:
	"""Clear hovered cell information"""
	var section = get_section("Hovered Cell")
	if section:
		section.clear()
		section.add_line("(No cell hovered)")

func has_hovered_cell() -> bool:
	"""Check if there is currently a hovered cell"""
	var section = get_section("Hovered Cell")
	if not section or section.lines.is_empty():
		return false

	var first_line = section.lines[0]
	return first_line != "(No cell hovered)"

func get_fps() -> int:
	"""Get current FPS from performance section"""
	var section = get_section("Performance")
	if not section or section.lines.is_empty():
		return 0

	# Parse "FPS: 60" format
	var fps_line = section.lines[0]
	var parts = fps_line.split(":")
	if parts.size() >= 2:
		return int(parts[1].strip_edges())

	return 0

func get_grid_cell_count() -> int:
	"""Get total grid cell count"""
	var section = get_section("Grid Info")
	if not section or section.lines.is_empty():
		return 0

	# Parse "Grid: 2800 (1051/1749)" format
	var grid_line = section.lines[0]
	var parts = grid_line.split(":")
	if parts.size() >= 2:
		var count_part = parts[1].strip_edges().split(" ")[0]
		return int(count_part)

	return 0
