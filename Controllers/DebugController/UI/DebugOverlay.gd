extends BaseOverlay

## Debug Overlay - Displays FPS, grid stats, and cell information
## Refactored to use package-based architecture with schemas and presets

# ============================================================================
# PACKAGE IMPORTS
# Note: These classes are globally available via class_name declarations
# ============================================================================

# DebugSchema and OverlayPresets are available globally

# ============================================================================
# UI REFERENCES
# ============================================================================

@onready var label: Label = $Control/Panel/MarginContainer/VBoxContainer/Label

# ============================================================================
# STATE
# ============================================================================

var debug_schema: DebugSchema
var session_controller: Node = null
var debug_controller: Node = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Load configuration from preset
	var config = OverlayPresets.get_preset("debug")
	config.apply_to_overlay(self)

	# Initialize parent (validates title, sets up gradient, etc.)
	super._ready()

	# Apply text color to label
	_apply_text_colors()

	# Initialize schema
	_initialize_schema()

	# Connect to DebugController
	_connect_debug_controller()

	# Initialize visibility
	if debug_controller:
		visible = debug_controller.debug_visible
		if visible:
			_update_display()
	else:
		visible = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _initialize_schema() -> void:
	"""Initialize DebugSchema with overlay configuration"""
	debug_schema = DebugSchema.new()
	debug_schema.max_lines = max_content_lines
	debug_schema.title = overlay_title
	debug_schema.strict_validation = strict_validation
	debug_schema.auto_truncate = auto_truncate
	debug_schema.truncation_indicator = "..." if show_overflow_indicator else ""

func _apply_text_colors() -> void:
	"""Apply text_color to content label"""
	label.add_theme_color_override("font_color", text_color)

# ============================================================================
# CONTROLLER CONNECTIONS
# ============================================================================

func _connect_debug_controller() -> void:
	"""Connect to SessionController's DebugController for state updates"""
	# Find SessionController
	var root = get_tree().root
	session_controller = _find_session_controller(root)

	if not session_controller:
		push_warning("DebugOverlay: SessionController not found")
		return

	# Wait for session initialization
	if not session_controller.is_session_active():
		await session_controller.session_initialized

	# Get DebugController
	debug_controller = session_controller.get_debug_controller()
	if not debug_controller:
		push_warning("DebugOverlay: DebugController not found")
		return

	# Connect to signals
	debug_controller.debug_visibility_changed.connect(_on_debug_visibility_changed)
	debug_controller.debug_info_updated.connect(_on_debug_info_updated)

	print_debug("DebugOverlay: Connected to DebugController")

func _find_session_controller(node: Node) -> Node:
	"""Recursively search for SessionController in scene tree"""
	if node.get_script() and node.get_script().get_global_name() == "SessionController":
		return node

	for child in node.get_children():
		var result = _find_session_controller(child)
		if result:
			return result

	return null

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_debug_visibility_changed(should_be_visible: bool) -> void:
	"""Handle debug visibility toggle"""
	visible = should_be_visible
	if should_be_visible:
		_update_display()
	print_debug("DebugOverlay visibility changed: %s" % should_be_visible)

func _on_debug_info_updated(_key: String, _value: Variant) -> void:
	"""Handle debug info updates"""
	_update_display()

func _on_turn_changed(_turn_info):
	"""Handle turn changes (compatibility method for signal connection)"""
	_update_display()

# ============================================================================
# DISPLAY UPDATES
# ============================================================================

func _update_display() -> void:
	"""Update display with current debug data"""
	if not debug_controller:
		return

	# Gather all debug data
	var debug_data = _gather_debug_data()

	# Update schema
	debug_schema.update_from_debug_data(debug_data)

	# Validate if strict mode enabled
	if strict_validation:
		var validation = debug_schema.validate_all()
		if not validation.valid:
			# Debug overlay allows overflow - just log warnings
			for warning in validation.warnings:
				push_warning("DebugOverlay: %s" % warning)

		# Enforce limits if auto-truncate enabled
		if auto_truncate and not validation.valid:
			debug_schema.enforce_limits()

	# Generate and display text
	var display_text = debug_schema.generate_display_text()
	label.text = display_text

func _gather_debug_data() -> Dictionary:
	"""Gather all debug information into a single dictionary"""
	var data = {}

	# Performance data
	data["fps"] = Engine.get_frames_per_second()
	data["frame_time"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0

	# Grid data (if available)
	if debug_controller.has_method("get_grid_stats"):
		var grid_stats = debug_controller.get_grid_stats()
		data["total_cells"] = grid_stats.get("total", 0)
		data["enabled_cells"] = grid_stats.get("enabled", 0)
		data["disabled_cells"] = grid_stats.get("disabled", 0)
		data["navigable_cells"] = grid_stats.get("navigable", 0)
	else:
		# Fallback to debug_controller properties
		data["total_cells"] = debug_controller.get("total_cells")
		data["enabled_cells"] = debug_controller.get("enabled_cells")
		data["disabled_cells"] = debug_controller.get("disabled_cells")
		data["navigable_cells"] = debug_controller.get("navigable_cells")

	# Navigation data
	data["agent_position"] = debug_controller.get("agent_position")
	data["path_length"] = debug_controller.get("path_length")

	# Hovered cell data
	if debug_controller.get("hovered_cell_data"):
		data["hovered_cell"] = debug_controller.hovered_cell_data
	else:
		data["hovered_cell"] = {}

	return data

# ============================================================================
# PROCESS
# ============================================================================

func _process(_delta: float) -> void:
	"""Update display every frame for real-time FPS"""
	if visible and debug_controller:
		_update_display()
