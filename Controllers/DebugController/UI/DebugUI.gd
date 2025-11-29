extends BaseOverlay

## Debug UI - Signal-Based Architecture with Schema
## Connects to SessionController's DebugController for state updates
## Uses DebugUISchema for structured, bounded content presentation

# Reference to UI elements
@onready var label: Label = $Control/Panel/MarginContainer/VBoxContainer/Label

# Reference to controllers (will be set in _ready)
var session_controller = null
var debug_controller = null

# UI Schema for structured content
var ui_schema: DebugUISchema = null

func _ready():
	# Initialize UI schema first
	ui_schema = DebugUISchema.new()

	# Find SessionController and get UI config first
	var root = get_tree().root
	session_controller = _find_session_controller(root)

	if not session_controller:
		push_warning("DebugUI: SessionController not found - using default config")
		_apply_default_config()
	else:
		# Wait for session initialization if needed
		if not session_controller.is_session_active():
			await session_controller.session_initialized

		# Get UIController for centralized config
		var ui_controller = session_controller.get_ui_controller()
		if ui_controller:
			# Get config from UIController (centralized styling)
			var config = ui_controller.get_debug_overlay_config()
			if config:
				config.apply_to_overlay(self)
				print("DebugUI: Applied centralized config from UIController")
			else:
				push_warning("DebugUI: UIController config not found - using default")
				_apply_default_config()
		else:
			push_warning("DebugUI: UIController not found - using default config")
			_apply_default_config()

		# Get the debug controller
		debug_controller = session_controller.get_debug_controller()
		if not debug_controller:
			push_warning("DebugUI: DebugController not found")
			visible = false
			return

	# Call parent _ready to apply configuration
	super._ready()

	# Connect to DebugController signals (if available)
	if debug_controller:
		debug_controller.debug_visibility_changed.connect(_on_debug_visibility_changed)
		debug_controller.debug_info_updated.connect(_on_debug_info_updated)

		# Initialize visibility
		visible = debug_controller.debug_visible

		# Initialize with current debug data
		_update_display()

func _apply_default_config() -> void:
	"""Apply default configuration when UIController is not available"""
	gradient_color = Color(0, 0.1, 0.2)
	gradient_alpha = 0.88
	border_color = Color(0, 0.4, 0.7)
	border_width = 2.0
	anchor_position = 1  # Top Right
	offset_from_edge = Vector2(10, 10)
	overlay_size = Vector2(350, 200)
	content_margin = 10

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
	if not debug_controller or not ui_schema:
		return

	# Get debug data from controller
	var debug_data = debug_controller.get_all_debug_info()

	# Update schema with data
	ui_schema.update_from_debug_data(debug_data)

	# Generate display text using schema (with automatic boundary enforcement)
	label.text = ui_schema.get_display_text()

	# Optional: Log if content is overflowing (for debugging)
	if ui_schema.is_overflowing():
		push_warning("DebugUI: Content exceeds display boundaries (truncated)")

func _process(_delta: float):
	# Update FPS and other dynamic info every frame
	if not debug_controller:
		return

	# Update FPS
	debug_controller.update_debug_info_requested.emit("fps", Engine.get_frames_per_second())
