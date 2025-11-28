extends CanvasLayer

## Selection Overlay UI - Displays selected object information
## Connects to UIController for selection data updates

# Reference to UI elements
@onready var control: Control = $Control
@onready var title_label: Label = $Control/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var type_label: Label = $Control/Panel/MarginContainer/VBoxContainer/TypeLabel
@onready var metadata_label: Label = $Control/Panel/MarginContainer/VBoxContainer/MetadataLabel

# Reference to controllers
var session_controller = null
var ui_controller = null

func _ready():
	# Start visible with empty state
	visible = true
	_show_empty_state()

	# Find SessionController in the scene
	var root = get_tree().root
	session_controller = _find_session_controller(root)

	if not session_controller:
		push_warning("SelectionOverlay: SessionController not found in scene")
		return

	# Wait for session initialization
	if not session_controller.is_session_active():
		await session_controller.session_initialized

	# Get the UI controller
	ui_controller = session_controller.get_ui_controller()
	if not ui_controller:
		push_warning("SelectionOverlay: UIController not found")
		return

	# Connect to UIController signals
	ui_controller.selected_item_changed.connect(_on_selected_item_changed)

	print("SelectionOverlay: Connected to UIController")

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

func _on_selected_item_changed(item_data: Dictionary):
	"""Update the overlay when selection changes"""
	var has_selection = item_data.get("has_selection", false)

	if not has_selection:
		# Show empty state when selection is cleared
		_show_empty_state()
		return

	# Update labels with selection data
	var item_name = item_data.get("item_name", "Unknown")
	var item_type = item_data.get("item_type", "Unknown")
	var metadata = item_data.get("metadata", {})

	title_label.text = item_name
	type_label.text = "Type: %s" % item_type

	# Format metadata
	var metadata_lines: Array[String] = []
	metadata_lines.append("--- Properties ---")

	for key in metadata:
		var value = metadata[key]
		# Format values based on type
		if value is Vector2:
			metadata_lines.append("%s: (%.0f, %.0f)" % [key, value.x, value.y])
		elif value is bool:
			metadata_lines.append("%s: %s" % [key, "Yes" if value else "No"])
		else:
			metadata_lines.append("%s: %s" % [key, str(value)])

	metadata_label.text = "\n".join(metadata_lines)

	print("SelectionOverlay: Showing %s (%s)" % [item_name, item_type])

func _show_empty_state():
	"""Display empty state when no object is selected"""
	title_label.text = "No Selection"
	type_label.text = "Click an object to view details"
	metadata_label.text = ""
