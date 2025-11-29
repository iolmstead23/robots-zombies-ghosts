class_name SelectionUISchema
extends UISchema

## Selection UI Schema - Structured presentation of selected item information
## Manages sections: Turn Info, Item Info, Metadata

# ============================================================================
# SECTION DEFINITIONS
# ============================================================================

var turn_section: ContentSection
var item_info_section: ContentSection
var metadata_section: ContentSection

# Cache for formatted content
var cached_turn_text: String = ""
var cached_title_text: String = ""
var cached_type_text: String = ""

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	# Configure schema limits (compact version)
	max_lines = 8
	max_chars_per_line = 45
	auto_truncate = true
	enable_scrolling = false

	# Initialize sections
	super._init()

func _initialize_sections() -> void:
	"""Define the selection UI sections (simplified)"""
	# Turn info (priority 100 - always shown first) - compact: name, turn, distance only
	turn_section = add_section("", 3, 100)

	# Item info (priority 90) - only name and type
	item_info_section = add_section("", 2, 90)

	# Metadata section removed - not used in simple mode
	metadata_section = add_section("", 0, 80)  # Keep for compatibility but don't use

# ============================================================================
# UPDATE METHODS - Called from SelectionOverlay
# ============================================================================

func update_turn_info(turn_data: Dictionary) -> void:
	"""Update turn information section (simplified: name, turn, distance only)"""
	turn_section.clear()

	var agent_num = turn_data.get("agent_index", 0) + 1
	var total_agents = turn_data.get("total_agents", 1)
	var distance_left = turn_data.get("movements_left", "-")

	# Format turn info compactly - only 3 lines
	turn_section.add_line("Turn %s / %s" % [str(agent_num), str(total_agents)])
	turn_section.add_line("Agent: %s" % str(turn_data.get("agent_name", "-")))
	turn_section.add_line("Distance: %s m" % str(distance_left))

	# Cache for direct label access
	cached_turn_text = "\n".join(turn_section.lines)

func update_selection_info(item_data: Dictionary) -> void:
	"""Update item selection information (simplified: name and type only)"""
	item_info_section.clear()
	metadata_section.clear()

	var has_selection = item_data.get("has_selection", false)

	if not has_selection:
		_show_empty_state()
		return

	# Item header - only name and type (no metadata)
	var item_name = item_data.get("item_name", "Unknown")
	var item_type = item_data.get("item_type", "Unknown")

	item_info_section.add_line(item_name)
	item_info_section.add_line("Type: %s" % item_type)

	# Cache for direct label access
	cached_title_text = item_name
	cached_type_text = "Type: %s" % item_type

	# Metadata disabled in simple mode - no properties shown

func _show_empty_state() -> void:
	"""Display empty state when no object is selected"""
	item_info_section.add_line("No Selection")
	item_info_section.add_line("Click to select")

	cached_title_text = "No Selection"
	cached_type_text = "Click to select"

# _format_metadata removed - not used in simple mode

# ============================================================================
# ACCESSOR METHODS - For backward compatibility with direct label updates
# ============================================================================

func get_turn_label_text() -> String:
	"""Get formatted text for turn label (for direct label updates)"""
	return cached_turn_text

func get_title_label_text() -> String:
	"""Get formatted text for title label"""
	return cached_title_text

func get_type_label_text() -> String:
	"""Get formatted text for type label"""
	return cached_type_text

func get_metadata_label_text() -> String:
	"""Get formatted text for metadata label (disabled in simple mode)"""
	return ""  # No metadata shown in simple mode

# ============================================================================
# UTILITY METHODS
# ============================================================================

func get_full_display_text() -> String:
	"""Generate the complete display text for all sections"""
	return generate_display_text()

func is_overflowing() -> bool:
	"""Check if content is exceeding the display limits"""
	return is_content_exceeding_limits()

func get_section_count() -> int:
	"""Get the number of active sections"""
	var count = 0
	for section in sections:
		if section.lines.size() > 0:
			count += 1
	return count
