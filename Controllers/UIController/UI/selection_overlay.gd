## turn_changed audit handled via BaseOverlay
extends BaseOverlay

## Selection Overlay UI - Displays selected object information
## Connects to UIController for selection data updates

# Reference to UI elements
@onready var turn_label: Label = $Control/Panel/MarginContainer/VBoxContainer/TurnLabel
@onready var title_label: Label = $Control/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var type_label: Label = $Control/Panel/MarginContainer/VBoxContainer/TypeLabel
@onready var metadata_label: Label = $Control/Panel/MarginContainer/VBoxContainer/MetadataLabel

# Reference to controllers
var session_controller = null
var ui_controller = null

func _ready():
	# Configure the base overlay style (before super._ready())
	gradient_color = Color(0, 0.2, 0.4)
	gradient_alpha = 0.9
	border_color = Color(0, 0.6, 1)
	border_width = 2.0
	anchor_position = 0  # Top Left
	offset_from_edge = Vector2(10, 10)
	overlay_size = Vector2(350, 200)
	content_margin = 15

	# Call parent _ready to apply configuration
	super._ready()

	# Start visible with empty state
	visible = true
	_show_empty_state()
	# update_turn_label() -- removed, replaced by signal-driven update

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

	# Connect to turn info signal for reactive updates
	ui_controller.turn_info_changed.connect(refresh_turn_info)

	print("SelectionOverlay: Connected to UIController and listening for turn_info_changed")

	# Request initial turn info (in case we missed the first emission during initialization)
	_request_initial_turn_info()

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

	# update_turn_label() -- removed, replaced by signal-driven update

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
	# update_turn_label() -- removed, replaced by signal-driven update
	title_label.text = "No Selection"
	type_label.text = "Click an object to view details"
# Updated: Label updates are now reactive via refresh_turn_info

func refresh_turn_info(turn_data: Dictionary) -> void:
	# turn_data: { "turn_number", "agent_name", "agent_index", "total_agents", "movements_left", "actions_left" }
	var agent_num = turn_data.get("agent_index", 0) + 1  # Convert 0-based index to 1-based
	var total_agents = turn_data.get("total_agents", 1)
	var distance_left = turn_data.get("movements_left", "-")
	var label_text := "Turn %s / %s\nAgent: %s\nDistance: %s m\nActions left: %s" % [
		str(agent_num),
		str(total_agents),
		str(turn_data.get("agent_name", "-")),
		str(distance_left),
		str(turn_data.get("actions_left", "-"))
	]
	turn_label.text = label_text
	print("[SelectionOverlay] Updated turn info: %s" % label_text)

func _request_initial_turn_info() -> void:
	"""Request the current turn info from AgentController in case we missed the initial signal"""
	if not session_controller:
		return

	var agent_manager = session_controller.get_agent_manager()
	if not agent_manager:
		return

	var active_agent = agent_manager.get_active_agent()
	if not active_agent:
		return

	# Build turn info manually
	var turn_info = {
		"turn_number": agent_manager.current_round + 1,
		"agent_name": active_agent.agent_name,
		"agent_index": agent_manager.active_agent_index,
		"total_agents": agent_manager.get_all_agents().size(),
		"movements_left": active_agent.get_movements_remaining() if active_agent.has_method("get_movements_remaining") else active_agent.max_movements_per_turn,
		"actions_left": active_agent.get_actions_remaining() if active_agent.has_method("get_actions_remaining") else "-"
	}

	# Update the UI
	refresh_turn_info(turn_info)
	print("[SelectionOverlay] Requested and received initial turn info")
