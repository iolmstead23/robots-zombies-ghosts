## SIGNAL COMPLIANCE AUDIT (SessionController.turn_changed)
## This overlay intentionally does not interact with or react to the 'turn_changed' signal from SessionController.
## Its responsibility is limited to presenting metadata for the currently selected item and reacting to UI visibility and selection changes.
## The design explicitly avoids responding to turn change events, as selection and metadata display are managed independently.
extends CanvasLayer

## Metadata Display UI - User Feedback Overlay
## Displays metadata about the selected item in the game
## Always visible, positioned in top-left corner with gray background

# Reference to UI elements
@onready var control: Control = $Control
@onready var label: Label = $Control/Panel/MarginContainer/VBoxContainer/Label

# Reference to controllers (will be set in _ready)
var session_controller = null
var ui_controller = null

func _ready():
	# Set the layer to ensure highest z-index
	layer = 100

	# Find SessionController in the scene
	var root = get_tree().root
	session_controller = _find_session_controller(root)

	if not session_controller:
		push_warning("MetadataDisplay: SessionController not found in scene")
		visible = false
		return

	# Wait for session initialization
	if not session_controller.is_session_active():
		await session_controller.session_initialized

	# Get the UI controller
	ui_controller = session_controller.get_ui_controller()
	if not ui_controller:
		push_warning("MetadataDisplay: UIController not found")
		visible = false
		return

	# Connect to UIController signals
	ui_controller.ui_visibility_changed.connect(_on_ui_visibility_changed)
	ui_controller.selected_item_changed.connect(_on_selected_item_changed)

	# Initialize visibility (always visible for user feedback)
	visible = ui_controller.ui_visible

	# Initialize with current selected item data
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

func _on_ui_visibility_changed(should_be_visible: bool):
	visible = should_be_visible
	if should_be_visible:
		_update_display()

func _on_selected_item_changed(_item_data: Dictionary):
	_update_display()

func _update_display():
	if not ui_controller:
		return

	var item_data = ui_controller.get_selected_item()
	var lines: Array[String] = []

	# Header
	lines.append("=== SELECTED ITEM ===")
	lines.append("")

	if item_data.get("has_selection", false):
		# Item Type
		var item_type = item_data.get("item_type", "Unknown")
		if item_type:
			lines.append("Type: %s" % item_type)

		# Item Name
		var item_name = item_data.get("item_name", "Unnamed")
		if item_name:
			lines.append("Name: %s" % item_name)

		# Metadata section
		var metadata = item_data.get("metadata", {})
		if metadata.size() > 0:
			lines.append("")
			lines.append("--- METADATA ---")
			for key in metadata:
				var value = metadata[key]
				# Format different types appropriately
				if value is Vector2:
					lines.append("%s: (%.1f, %.1f)" % [key, value.x, value.y])
				elif value is Vector2i:
					lines.append("%s: (%d, %d)" % [key, value.x, value.y])
				elif value is bool:
					lines.append("%s: %s" % [key, "Yes" if value else "No"])
				elif value is float:
					lines.append("%s: %.2f" % [key, value])
				else:
					lines.append("%s: %s" % [key, str(value)])
	else:
		lines.append("No item selected")
		lines.append("")
		lines.append("Click on an item to")
		lines.append("view its metadata")

	label.text = "\n".join(lines)
