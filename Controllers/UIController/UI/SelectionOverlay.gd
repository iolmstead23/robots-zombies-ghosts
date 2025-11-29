## turn_changed audit handled via BaseOverlay
extends BaseOverlay

## Selection Overlay UI - Displays selected object information with Schema
## Connects to UIController for selection data updates
## Uses SelectionUISchema for structured, bounded content presentation

# Reference to UI elements
@onready var turn_label: Label = $Control/Panel/MarginContainer/VBoxContainer/TurnLabel
@onready var title_label: Label = $Control/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var type_label: Label = $Control/Panel/MarginContainer/VBoxContainer/TypeLabel
@onready var metadata_label: Label = $Control/Panel/MarginContainer/VBoxContainer/MetadataLabel

# Reference to controllers
var session_controller = null
var ui_controller = null

# UI Schema for structured content
var ui_schema: SelectionUISchema = null

func _ready():
	# Initialize UI schema first
	ui_schema = SelectionUISchema.new()

	# Find SessionController and UIController first
	var root = get_tree().root
	session_controller = _find_session_controller(root)

	if not session_controller:
		push_warning("SelectionOverlay: SessionController not found - using default config")
		_apply_default_config()
	else:
		# Wait for session initialization if needed
		if not session_controller.is_session_active():
			await session_controller.session_initialized

		# Get the UI controller
		ui_controller = session_controller.get_ui_controller()
		if ui_controller:
			# Get config from UIController (centralized styling)
			var config = ui_controller.get_selection_overlay_config()
			if config:
				config.apply_to_overlay(self)
				print("SelectionOverlay: Applied centralized config from UIController")
			else:
				push_warning("SelectionOverlay: UIController config not found - using default")
				_apply_default_config()
		else:
			push_warning("SelectionOverlay: UIController not found - using default config")
			_apply_default_config()

	# Call parent _ready to apply configuration
	super._ready()

	# Start visible with empty state
	visible = true
	_show_empty_state()

	# Connect to UIController signals (if available)
	if ui_controller:
		ui_controller.selected_item_changed.connect(_on_selected_item_changed)
		# Connect to turn info signal for reactive updates
		ui_controller.turn_info_changed.connect(refresh_turn_info)
		print("SelectionOverlay: Connected to UIController signals")

		# Request initial turn info (in case we missed the first emission during initialization)
		_request_initial_turn_info()

func _apply_default_config() -> void:
	"""Apply default configuration when UIController is not available"""
	gradient_color = Color(0, 0.2, 0.4)
	gradient_alpha = 0.9
	border_color = Color(0, 0.6, 1)
	border_width = 2.0
	anchor_position = 0  # Top Left
	offset_from_edge = Vector2(10, 10)
	overlay_size = Vector2(350, 200)  # Match debug overlay size
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

func _on_selected_item_changed(item_data: Dictionary):
	"""Update the overlay when selection changes (simple mode: name and type only)"""
	if not ui_schema:
		return

	# Update schema with selection data
	ui_schema.update_selection_info(item_data)

	# Update labels using schema
	title_label.text = ui_schema.get_title_label_text()
	type_label.text = ui_schema.get_type_label_text()
	metadata_label.text = ""  # Always empty in simple mode

	# Optional: Log if content is overflowing
	if ui_schema.is_overflowing():
		push_warning("SelectionOverlay: Content exceeds display boundaries (truncated)")

	var has_selection = item_data.get("has_selection", false)
	if has_selection:
		var item_name = item_data.get("item_name", "Unknown")
		var item_type = item_data.get("item_type", "Unknown")
		print("SelectionOverlay: Showing %s (%s)" % [item_name, item_type])

func _show_empty_state():
	"""Display empty state when no object is selected"""
	if not ui_schema:
		# Fallback if schema not initialized
		title_label.text = "No Selection"
		type_label.text = "Click to select"
		metadata_label.text = ""
		return

	# Use schema for consistent formatting
	var empty_data = {"has_selection": false}
	ui_schema.update_selection_info(empty_data)

	title_label.text = ui_schema.get_title_label_text()
	type_label.text = ui_schema.get_type_label_text()
	metadata_label.text = ""  # Always empty in simple mode

func refresh_turn_info(turn_data: Dictionary) -> void:
	"""Update turn information using schema"""
	if not ui_schema:
		return

	# Update schema with turn data
	ui_schema.update_turn_info(turn_data)

	# Update turn label
	turn_label.text = ui_schema.get_turn_label_text()

	print("[SelectionOverlay] Updated turn info via schema")

func _request_initial_turn_info() -> void:
	"""Request the current turn info from AgentManager in case we missed the initial signal"""
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
