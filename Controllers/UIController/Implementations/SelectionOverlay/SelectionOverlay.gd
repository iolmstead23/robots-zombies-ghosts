extends BaseOverlay

## Selection Overlay - Displays turn info, agent status, and selected object details
## Refactored to use package-based architecture with schemas and presets

# ============================================================================
# PACKAGE IMPORTS
# Note: These classes are globally available via class_name declarations
# ============================================================================

# SelectionSchema and OverlayPresets are available globally

# ============================================================================
# UI REFERENCES
# ============================================================================

@onready var turn_label: Label = $Control/Panel/MarginContainer/VBoxContainer/TurnLabel
@onready var title_display_label: Label = $Control/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var type_label: Label = $Control/Panel/MarginContainer/VBoxContainer/TypeLabel
@onready var metadata_label: Label = $Control/Panel/MarginContainer/VBoxContainer/MetadataLabel

# ============================================================================
# STATE
# ============================================================================

var selection_schema: SelectionSchema
var session_controller: Node = null
var ui_controller: Node = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Load configuration from preset
	var config = OverlayPresets.get_preset("selection")
	config.apply_to_overlay(self)

	# Initialize parent (validates title, sets up gradient, etc.)
	super._ready()

	# Apply text colors to content labels
	_apply_text_colors()

	# Initialize schema
	_initialize_schema()

	# Connect to controllers
	_connect_controllers()

	# Show initial state
	visible = true
	_show_empty_state()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _initialize_schema() -> void:
	"""Initialize SelectionSchema with overlay configuration"""
	selection_schema = SelectionSchema.new()
	selection_schema.max_lines = max_content_lines
	selection_schema.title = overlay_title
	selection_schema.strict_validation = strict_validation
	selection_schema.auto_truncate = auto_truncate
	selection_schema.truncation_indicator = "..." if show_overflow_indicator else ""

func _apply_text_colors() -> void:
	"""Apply text_color to all content labels"""
	turn_label.add_theme_color_override("font_color", text_color)
	title_display_label.add_theme_color_override("font_color", text_color)
	type_label.add_theme_color_override("font_color", text_color)
	metadata_label.add_theme_color_override("font_color", text_color)

# ============================================================================
# CONTROLLER CONNECTIONS
# ============================================================================

func _connect_controllers() -> void:
	"""Connect to SessionController and UIController for data updates"""
	session_controller = _find_in_tree("SessionController")
	if not session_controller:
		push_warning("SelectionOverlay: SessionController not found")
		return

	if not session_controller.is_session_active():
		await session_controller.session_initialized

	ui_controller = session_controller.get_ui_controller()
	if not ui_controller:
		push_warning("SelectionOverlay: UIController not found")
		return

	# Connect to UI signals
	ui_controller.selected_item_changed.connect(_on_selected_item_changed)
	ui_controller.turn_info_changed.connect(_on_turn_info_changed)

	print_debug("SelectionOverlay: Connected to UIController")

	# Request initial turn info
	_request_initial_turn_info()

func _find_in_tree(classname: String) -> Node:
	"""Find node by script class name in scene tree"""
	return _recursively_find(get_tree().root, classname)

func _recursively_find(node: Node, classname: String) -> Node:
	"""Recursively search for node with matching class name"""
	if node.get_script() and node.get_script().get_global_name() == classname:
		return node

	for child in node.get_children():
		var result = _recursively_find(child, classname)
		if result:
			return result

	return null

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_selected_item_changed(item_data: Dictionary) -> void:
	"""Handle selection changes from UIController"""
	if not item_data.get("has_selection", false):
		_show_empty_state()
		return

	# Update schema with selection data
	selection_schema.update_from_selection_data(item_data)

	# Validate if strict mode enabled
	if strict_validation:
		var validation = selection_schema.validate_all()
		if not validation.valid:
			# Enforce limits if auto-truncate enabled
			if auto_truncate:
				# Use warnings since truncation will fix the issue
				push_warning("SelectionOverlay: Content exceeds limits, auto-truncating")
				for error in validation.errors:
					push_warning("  - %s" % error)
				selection_schema.enforce_limits()
			else:
				# Use errors since content will overflow
				push_error("SelectionOverlay: Content validation failed")
				for error in validation.errors:
					push_error("  - %s" % error)

	# Update display
	_update_selection_labels(item_data)

	print_debug("SelectionOverlay: Displaying selection: %s" % item_data.get("item_name", "Unknown"))

func _on_turn_info_changed(turn_data: Dictionary) -> void:
	"""Handle turn changes from UIController"""
	# Update schema with turn data
	selection_schema.update_from_turn_data(turn_data)

	# Update display
	turn_label.text = _format_turn_label(turn_data)

	print_debug("SelectionOverlay: Turn info updated")

# ============================================================================
# UI UPDATES
# ============================================================================

func _update_selection_labels(item_data: Dictionary) -> void:
	"""Update labels with selected item information"""
	title_display_label.text = item_data.get("item_name", "Unknown")
	type_label.text = "Type: %s" % item_data.get("item_type", "Unknown")

	# Format metadata
	var metadata = item_data.get("metadata", {})
	metadata_label.text = _format_metadata(metadata)

func _format_metadata(metadata: Dictionary) -> String:
	"""Format metadata dictionary for display"""
	# Filter out technical/debug properties (same as SelectionSchema)
	const FILTERED_KEYS = [
		"coordinates", "index", "world_position", "enabled", "navigable", "q", "r",
		"position", "in_scene", "test_status", "is_selectable"
	]

	var display_metadata = {}
	for key in metadata:
		if key not in FILTERED_KEYS:
			display_metadata[key] = metadata[key]

	if display_metadata.is_empty():
		return ""  # Don't show anything if no properties to display

	var lines: Array = ["--- Properties ---"]

	for key in display_metadata:
		var formatted_line = _format_metadata_line(key, display_metadata[key])
		lines.append(formatted_line)

	return "\n".join(lines)

func _format_metadata_line(key: String, value: Variant) -> String:
	"""Format a single metadata key-value pair"""
	match typeof(value):
		TYPE_VECTOR2:
			return "%s: (%.0f, %.0f)" % [key, value.x, value.y]
		TYPE_BOOL:
			return "%s: %s" % [key, "Yes" if value else "No"]
		_:
			return "%s: %s" % [key, str(value)]

func _show_empty_state() -> void:
	"""Show default state when nothing is selected"""
	selection_schema.clear_selection()

	title_display_label.text = "No Selection"
	type_label.text = "Click an object to view details"
	metadata_label.text = ""

# ============================================================================
# TURN FORMATTING
# ============================================================================

func _format_turn_label(turn_data: Dictionary) -> String:
	"""Format turn data into display string"""
	var agent_idx = turn_data.get("agent_index", 0) + 1
	var total = turn_data.get("total_agents", 1)

	return "Turn %s / %s\nAgent: %s\nDistance: %s m\nActions left: %s" % [
		str(agent_idx),
		str(total),
		str(turn_data.get("agent_name", "-")),
		str(turn_data.get("movements_left", "-")),
		str(turn_data.get("actions_left", "-"))
	]

func _request_initial_turn_info() -> void:
	"""Request initial turn information from SessionController"""
	if not session_controller:
		return

	var agent_manager = session_controller.get_agent_manager()
	if not agent_manager:
		return

	var agent = agent_manager.get_active_agent()
	if not agent:
		return

	# Build turn info dictionary
	var info = {
		"turn_number": agent_manager.current_round + 1,
		"agent_name": agent.agent_name,
		"agent_index": agent_manager.active_agent_index,
		"total_agents": agent_manager.get_all_agents().size(),
		"movements_left": agent.get_movements_remaining() if agent.has_method("get_movements_remaining") else agent.max_movements_per_turn,
		"actions_left": agent.get_actions_remaining() if agent.has_method("get_actions_remaining") else "-"
	}

	_on_turn_info_changed(info)
	print_debug("SelectionOverlay: Initial turn info requested")
