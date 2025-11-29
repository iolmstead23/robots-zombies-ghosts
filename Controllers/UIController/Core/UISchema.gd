class_name UISchema
extends RefCounted

## UI Schema Base Class - Defines structure for static content presentation
## Ensures proper boundaries and prevents text overflow by managing content structure

# ============================================================================
# SCHEMA CONFIGURATION
# ============================================================================

## Maximum number of lines allowed in the content area
@export var max_lines: int = 15

## Maximum characters per line (for estimation, actual wrapping handled by Label)
@export var max_chars_per_line: int = 50

## Enable automatic truncation when content exceeds limits
@export var auto_truncate: bool = true

## Truncation indicator (shown when content is truncated)
@export var truncation_indicator: String = "..."

## Enable scrolling (requires ScrollContainer in UI)
@export var enable_scrolling: bool = false

# ============================================================================
# CONTENT SECTIONS - Override in child classes
# ============================================================================

class ContentSection:
	var title: String = ""
	var lines: Array[String] = []
	var max_lines: int = -1  # -1 means no limit for this section
	var priority: int = 0  # Higher priority sections shown first
	var is_collapsible: bool = false
	var is_collapsed: bool = false

	func _init(p_title: String = "", p_max_lines: int = -1, p_priority: int = 0):
		title = p_title
		max_lines = p_max_lines
		priority = p_priority

	func add_line(line: String) -> void:
		lines.append(line)

	func clear() -> void:
		lines.clear()

	func get_display_lines() -> Array[String]:
		if is_collapsed:
			return [title + " (collapsed)"]

		var result: Array[String] = []
		if title != "":
			result.append(title)

		var section_lines = lines
		if max_lines > 0 and section_lines.size() > max_lines:
			section_lines = section_lines.slice(0, max_lines)
			section_lines.append("... (%d more)" % (lines.size() - max_lines))

		result.append_array(section_lines)
		return result

var sections: Array[ContentSection] = []

# ============================================================================
# LIFECYCLE
# ============================================================================

func _init():
	_initialize_sections()

# Override this in child classes to define sections
func _initialize_sections() -> void:
	pass

# ============================================================================
# SECTION MANAGEMENT
# ============================================================================

func add_section(title: String, max_lines: int = -1, priority: int = 0) -> ContentSection:
	"""Create and add a new content section"""
	var section = ContentSection.new(title, max_lines, priority)
	sections.append(section)
	return section

func get_section(title: String) -> ContentSection:
	"""Get a section by title"""
	for section in sections:
		if section.title == title:
			return section
	return null

func clear_all_sections() -> void:
	"""Clear content from all sections"""
	for section in sections:
		section.clear()

# ============================================================================
# CONTENT GENERATION
# ============================================================================

func generate_display_text() -> String:
	"""Generate the final display text respecting boundaries"""
	var all_lines: Array[String] = []

	# Sort sections by priority
	var sorted_sections = sections.duplicate()
	sorted_sections.sort_custom(func(a, b): return a.priority > b.priority)

	# Collect lines from all sections
	for section in sorted_sections:
		var section_lines = section.get_display_lines()
		all_lines.append_array(section_lines)

	# Apply global line limit
	if auto_truncate and max_lines > 0 and all_lines.size() > max_lines:
		all_lines = all_lines.slice(0, max_lines - 1)
		all_lines.append(truncation_indicator)

	return "\n".join(all_lines)

func get_content_line_count() -> int:
	"""Get total number of lines that would be displayed"""
	var count = 0
	for section in sections:
		count += section.get_display_lines().size()
	return count

func is_content_exceeding_limits() -> bool:
	"""Check if content exceeds defined limits"""
	return get_content_line_count() > max_lines

# ============================================================================
# UTILITY METHODS
# ============================================================================

func format_key_value(key: String, value: Variant, key_width: int = 15) -> String:
	"""Format a key-value pair with consistent spacing"""
	var key_padded = key.rpad(key_width)
	return "%s: %s" % [key_padded, str(value)]

func format_vector2(vec: Vector2, precision: int = 0) -> String:
	"""Format Vector2 for display"""
	if precision == 0:
		return "(%.0f, %.0f)" % [vec.x, vec.y]
	else:
		var format_str = "(%%.%df, %%.%df)" % [precision, precision]
		return format_str % [vec.x, vec.y]

func format_bool(value: bool) -> String:
	"""Format boolean for display"""
	return "Yes" if value else "No"

func truncate_string(text: String, max_length: int) -> String:
	"""Truncate a string to max length with indicator"""
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length - 3) + "..."
