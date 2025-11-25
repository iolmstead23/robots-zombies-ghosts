extends CanvasLayer

## Debug UI - Signal-Based Architecture
## Connects to SessionController's DebugController for state updates

# Reference to UI elements
@onready var control: Control = $Control
@onready var label: Label = $Control/Panel/MarginContainer/Label

# Reference to controllers (will be set in _ready)
var session_controller = null
var debug_controller = null

func _ready():
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

func _on_debug_info_updated(_key: String, _value: Variant):
	_update_display()

func _update_display():
	if not debug_controller:
		return

	var debug_data = debug_controller.get_all_debug_info()
	var text = ""

	# Format debug data for display
	for key in debug_data:
		var value = debug_data[key]
		text += "%s: %s\n" % [key.capitalize(), str(value)]

	label.text = text.strip_edges()

func _process(_delta: float):
	# Update FPS and other dynamic info every frame
	if not debug_controller:
		return

	# Update FPS
	debug_controller.update_debug_info_requested.emit("fps", Engine.get_frames_per_second())

	# You can add other dynamic updates here if needed