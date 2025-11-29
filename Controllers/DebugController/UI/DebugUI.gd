extends BaseOverlay

## Debug UI - Signal-Based Architecture
## Connects to SessionController's DebugController for state updates

# Reference to UI elements
@onready var label: Label = $Control/Panel/MarginContainer/VBoxContainer/Label

# Reference to controllers (will be set in _ready)
var session_controller = null
var debug_controller = null

func _ready():
	# Configure the base overlay style (before super._ready())
	gradient_color = Color(0, 0.1, 0.2)
	gradient_alpha = 0.88
	border_color = Color(0, 0.4, 0.7)
	border_width = 2.0
	anchor_position = 1  # Top Right
	offset_from_edge = Vector2(10, 10)
	overlay_size = Vector2(350, 200)
	content_margin = 10

	# Call parent _ready to apply configuration
	super._ready()

	# Find SessionController in the scene
	# Assuming the main scene structure has SessionController as a child of the root
	var root = get_tree().root
	session_controller = _find_session_controller(root)

	if not session_controller:
		push_warning("DebugUI: SessionController not found in scene")
		visible = false
		return

	# Wait for session initialization
	if not session_controller.is_session_active():
		await session_controller.session_initialized

	# Get the debug controller
	debug_controller = session_controller.get_debug_controller()
	if not debug_controller:
		push_warning("DebugUI: DebugController not found")
		visible = false
		return

	# Connect to DebugController signals
	debug_controller.debug_visibility_changed.connect(_on_debug_visibility_changed)
	debug_controller.debug_info_updated.connect(_on_debug_info_updated)

	# Initialize visibility
	visible = debug_controller.debug_visible

	# Initialize with current debug data
	_update_display()

func _find_session_controller(node: Node):
	"""Recursively search for SessionController in the scene tree"""
	# Check if this node has the class_name "SessionController"
	if node.get_script() and node.get_script().get_global_name() == "SessionController":
		return node

	for child in node.get_children():
		var result = _find_session_controller(child)
		if result:
			return result

	return null

func _on_debug_visibility_changed(should_be_visible: bool):
	visible = should_be_visible
	if should_be_visible:
		_update_display()
	print("DebugUI visibility changed: %s" % should_be_visible)

func _on_debug_info_updated(_key: String, _value: Variant):
	_update_display()

func _update_display():
	if not debug_controller:
		return

	var debug_data = debug_controller.get_all_debug_info()
	var lines: Array[String] = []

	# Header
	lines.append("=== DEBUG INFO ===")

	# FPS (always show if available)
	var fps = debug_data.get("fps")
	if fps != null:
		lines.append("FPS: %d" % fps)

	# Grid Stats (compact format)
	var grid_cells = debug_data.get("grid_cells")
	var enabled_cells = debug_data.get("enabled_cells")
	var disabled_cells = debug_data.get("disabled_cells")
	if grid_cells != null:
		lines.append("Grid: %d (%d/%d)" % [grid_cells, enabled_cells if enabled_cells != null else 0, disabled_cells if disabled_cells != null else 0])

	# Navigation Status (compact)
	var path_length = debug_data.get("path_length")
	if path_length != null and path_length > 0:
		lines.append("Path: %d cells" % path_length)

	# Separator before cell info
	lines.append("")
	lines.append("--- HOVERED CELL ---")

	# Hovered Cell Info
	var cell_q = debug_data.get("hovered_cell_q")
	var cell_r = debug_data.get("hovered_cell_r")
	var cell_index = debug_data.get("hovered_cell_index")
	var cell_enabled = debug_data.get("hovered_cell_enabled")

	if cell_q != null and cell_r != null and cell_index != null and cell_enabled != null:
		lines.append("Coords: (%d, %d) #%d" % [cell_q, cell_r, cell_index])
		lines.append("State: %s" % ("Enabled" if cell_enabled else "Disabled"))

		var world_pos = debug_data.get("hovered_cell_world_pos")
		if world_pos != null:
			lines.append("Pos: (%.0f, %.0f)" % [world_pos.x, world_pos.y])

		# Show metadata if available
		var metadata = debug_data.get("hovered_cell_metadata")
		if metadata != null and metadata.size() > 0:
			for key in metadata:
				lines.append("%s: %s" % [key, str(metadata[key])])
	else:
		lines.append("None")

	label.text = "\n".join(lines)

func _process(_delta: float):
	# Update FPS and other dynamic info every frame
	if not debug_controller:
		return

	# Update FPS
	debug_controller.update_debug_info_requested.emit("fps", Engine.get_frames_per_second())
