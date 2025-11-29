class_name DebugUISchema
extends UISchema

## Debug UI Schema - Structured presentation of debug information
## Manages sections: Header, Performance, Grid Stats, Hovered Cell

# ============================================================================
# SECTION DEFINITIONS
# ============================================================================

var header_section: ContentSection
var performance_section: ContentSection
var grid_section: ContentSection
var hovered_cell_section: ContentSection

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	# Configure schema limits
	max_lines = 20
	max_chars_per_line = 45
	auto_truncate = true
	enable_scrolling = false

	# Initialize sections
	super._init()

func _initialize_sections() -> void:
	"""Define the debug UI sections"""
	# Header (priority 100 - always shown first)
	header_section = add_section("=== DEBUG INFO ===", 1, 100)

	# Performance metrics (priority 90)
	performance_section = add_section("", 3, 90)

	# Grid statistics (priority 80)
	grid_section = add_section("", 3, 80)

	# Hovered cell info (priority 70)
	hovered_cell_section = add_section("--- HOVERED CELL ---", 10, 70)

# ============================================================================
# UPDATE METHODS - Called from DebugUI
# ============================================================================

func update_from_debug_data(debug_data: Dictionary) -> void:
	"""Update all sections from debug controller data"""
	clear_all_sections()

	_update_performance_section(debug_data)
	_update_grid_section(debug_data)
	_update_hovered_cell_section(debug_data)

func _update_performance_section(debug_data: Dictionary) -> void:
	"""Update FPS and performance metrics"""
	var fps = debug_data.get("fps")
	if fps != null:
		performance_section.add_line("FPS: %d" % fps)

func _update_grid_section(debug_data: Dictionary) -> void:
	"""Update grid statistics"""
	var grid_cells = debug_data.get("grid_cells")
	var enabled_cells = debug_data.get("enabled_cells")
	var disabled_cells = debug_data.get("disabled_cells")

	if grid_cells != null:
		grid_section.add_line("Grid: %d (%d/%d)" % [
			grid_cells,
			enabled_cells if enabled_cells != null else 0,
			disabled_cells if disabled_cells != null else 0
		])

	# Navigation path info (compact)
	var path_length = debug_data.get("path_length")
	if path_length != null and path_length > 0:
		grid_section.add_line("Path: %d cells" % path_length)

func _update_hovered_cell_section(debug_data: Dictionary) -> void:
	"""Update hovered cell information"""
	var cell_q = debug_data.get("hovered_cell_q")
	var cell_r = debug_data.get("hovered_cell_r")
	var cell_index = debug_data.get("hovered_cell_index")
	var cell_enabled = debug_data.get("hovered_cell_enabled")

	if cell_q != null and cell_r != null and cell_index != null and cell_enabled != null:
		hovered_cell_section.add_line("Coords: (%d, %d) #%d" % [cell_q, cell_r, cell_index])
		hovered_cell_section.add_line("State: %s" % ("Enabled" if cell_enabled else "Disabled"))

		var world_pos = debug_data.get("hovered_cell_world_pos")
		if world_pos != null:
			hovered_cell_section.add_line("Pos: %s" % format_vector2(world_pos, 0))

		# Show metadata (limited to prevent overflow)
		var metadata = debug_data.get("hovered_cell_metadata")
		if metadata != null and metadata.size() > 0:
			var meta_count = 0
			for key in metadata:
				if meta_count >= 5:  # Limit metadata entries
					hovered_cell_section.add_line("... (%d more)" % (metadata.size() - meta_count))
					break
				hovered_cell_section.add_line("%s: %s" % [key, truncate_string(str(metadata[key]), 30)])
				meta_count += 1
	else:
		hovered_cell_section.add_line("None")

# ============================================================================
# UTILITY METHODS
# ============================================================================

func get_display_text() -> String:
	"""Generate the final display text for the debug UI"""
	return generate_display_text()

func is_overflowing() -> bool:
	"""Check if content is exceeding the display limits"""
	return is_content_exceeding_limits()
