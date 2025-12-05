class_name SelectionSchema
extends ContentSchema

## Selection Overlay Schema
## Manages content structure for turn info, agent status, and selected object details

# Technical metadata keys to filter out from display
const FILTERED_METADATA_KEYS = [
	"coordinates",
	"index",
	"world_position",
	"enabled",
	"navigable",
	"q", "r",  # hex coordinate components
	"position",
	"in_scene",
	"test_status",
	"is_selectable",
]

# ============================================================================
# INITIALIZATION
# ============================================================================

func _initialize_sections() -> void:
	"""Define sections for selection overlay content"""
	# Turn Info - Highest priority, always shown
	add_section("Turn Info", 5, 100)

	# Selection Info - Medium priority
	add_section("Selection Info", 3, 90)

	# Metadata - Lower priority, can be truncated if needed
	add_section("Metadata", -1, 80)  # -1 = no per-section limit

# ============================================================================
# CONTENT UPDATES
# ============================================================================

func update_from_turn_data(turn_data: Dictionary) -> void:
	"""
	Update Turn Info section with current turn and agent data.

	Args:
		turn_data: Dictionary containing:
			- agent_index: Current agent index
			- total_agents: Total number of agents
			- agent_name: Name of active agent
			- movements_left: Remaining movement points
			- actions_left: Remaining actions
	"""
	var section = get_section("Turn Info")
	if not section:
		push_warning("SelectionSchema: 'Turn Info' section not found")
		return

	section.clear()

	# Turn number
	var turn_text = "Turn %s / %s" % [
		turn_data.get("agent_index", 0) + 1,
		turn_data.get("total_agents", 1)
	]
	section.add_line(turn_text)

	# Agent info
	section.add_line("Agent: %s" % turn_data.get("agent_name", "-"))
	section.add_line("Distance: %s m" % turn_data.get("movements_left", "-"))
	section.add_line("Actions left: %s" % turn_data.get("actions_left", "-"))

func update_from_selection_data(item_data: Dictionary) -> void:
	"""
	Update Selection Info and Metadata sections with selected object data.

	Args:
		item_data: Dictionary containing:
			- item_name: Name of selected object
			- item_type: Type of selected object
			- metadata: Dictionary of object properties
	"""
	var info_section = get_section("Selection Info")
	var meta_section = get_section("Metadata")

	if not info_section or not meta_section:
		push_warning("SelectionSchema: Selection sections not found")
		return

	# Update Selection Info
	info_section.clear()
	info_section.add_line(item_data.get("item_name", "Unknown"))
	info_section.add_line("Type: %s" % item_data.get("item_type", "Unknown"))

	# Update Metadata
	meta_section.clear()

	var metadata = item_data.get("metadata", {})
	var display_metadata = {}

	# Filter out technical/debug properties
	for key in metadata:
		if key not in FILTERED_METADATA_KEYS:
			display_metadata[key] = metadata[key]

	# Only show section if there's displayable metadata
	if display_metadata.is_empty():
		# Don't add Properties section if no properties to show
		pass
	else:
		meta_section.add_line("--- Properties ---")
		for key in display_metadata:
			var formatted_line = format_key_value(key, display_metadata[key])
			meta_section.add_line(formatted_line)

func clear_selection() -> void:
	"""Clear selection info and metadata (keep turn info)"""
	var info_section = get_section("Selection Info")
	var meta_section = get_section("Metadata")

	if info_section:
		info_section.clear()
		info_section.add_line("No Selection")

	if meta_section:
		meta_section.clear()
		meta_section.add_line("Click an object to view details")

# ============================================================================
# UTILITY
# ============================================================================

func has_selection() -> bool:
	"""Check if there is currently a selection"""
	var info_section = get_section("Selection Info")
	if not info_section:
		return false

	# If section is empty or only contains "No Selection", there's no real selection
	if info_section.lines.is_empty():
		return false

	var first_line = info_section.lines[0]
	return first_line != "No Selection"

func get_selected_name() -> String:
	"""Get the name of the currently selected object"""
	var info_section = get_section("Selection Info")
	if not info_section or info_section.lines.is_empty():
		return ""

	return info_section.lines[0]

func get_metadata_count() -> int:
	"""Get the number of metadata properties"""
	var meta_section = get_section("Metadata")
	if not meta_section:
		return 0

	# Subtract header line and empty state message
	var count = meta_section.lines.size()
	if count > 0 and (meta_section.lines[0] == "--- Properties ---" or meta_section.lines[0] == "(No properties)"):
		count -= 1

	return max(0, count)
