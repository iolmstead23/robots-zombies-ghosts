extends BaseOverlay

# --- UI REFERENCES ---
@onready var turn_label: Label = $Control/Panel/MarginContainer/VBoxContainer/TurnLabel
@onready var title_label: Label = $Control/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var type_label: Label = $Control/Panel/MarginContainer/VBoxContainer/TypeLabel
@onready var metadata_label: Label = $Control/Panel/MarginContainer/VBoxContainer/MetadataLabel

# --- CONTROLLERS ---
var session_controller: Node = null
var ui_controller: Node = null

# --- LIFECYCLE ---
func _ready() -> void:
	_configure_overlay()
	_connect_controllers()
	visible = true
	_show_empty_state()

# --- CONFIGURATION ---
func _configure_overlay() -> void:
	gradient_color = Color(0, 0.2, 0.4)
	gradient_alpha = 0.9
	border_color = Color(0, 0.6, 1)
	border_width = 2.0
	anchor_position = 0
	offset_from_edge = Vector2(10, 10)
	overlay_size = Vector2(350, 200)
	content_margin = 15
	super._ready()

# --- CONTROLLER CONNECTIONS ---
func _connect_controllers() -> void:
	session_controller = _find_in_tree("SessionController")
	if not session_controller:
		push_warning("SessionController not found")
		return
	if not session_controller.is_session_active():
		await session_controller.session_initialized
	ui_controller = session_controller.get_ui_controller()
	if not ui_controller:
		push_warning("UIController not found")
		return
	ui_controller.selected_item_changed.connect(_on_selected_item_changed)
	ui_controller.turn_info_changed.connect(_on_turn_info_changed)
	print_debug("Connected SelectionOverlay to UIController")
	_request_initial_turn_info()

func _find_in_tree(classname: String) -> Node:
	return _recursively_find(get_tree().root, classname)

func _recursively_find(node: Node, classname: String) -> Node:
	if node.get_script() and node.get_script().get_global_name() == classname:
		return node
	for child in node.get_children():
		var result = _recursively_find(child, classname)
		if result:
			return result
	return null

# --- UI UPDATES ---
func _on_selected_item_changed(item_data: Dictionary) -> void:
	if not item_data.get("has_selection", false):
		_show_empty_state()
		return
	_update_selection_labels(item_data)

func _update_selection_labels(item_data: Dictionary) -> void:
	title_label.text = item_data.get("item_name", "Unknown")
	type_label.text = "Type: %s" % item_data.get("item_type", "Unknown")
	metadata_label.text = _format_metadata(item_data.get("metadata", {}))
	print_debug("Displaying selection: %s" % item_data)

func _format_metadata(metadata: Dictionary) -> String:
	var lines: Array = ["--- Properties ---"]
	for key in metadata:
		var val = metadata[key]
		lines.append(_format_metadata_line(key, val))
	return "\n".join(lines)

func _format_metadata_line(key, value) -> String:
	match typeof(value):
		TYPE_VECTOR2:
			return "%s: (%.0f, %.0f)" % [key, value.x, value.y]
		TYPE_BOOL:
			return "%s: %s" % [key, "Yes" if value else "No"]
		_:
			return "%s: %s" % [key, str(value)]

func _show_empty_state() -> void:
	title_label.text = "No Selection"
	type_label.text = "Click an object to view details"
	metadata_label.text = ""

# --- TURN INFO UPDATES ---
func _on_turn_info_changed(turn_data: Dictionary) -> void:
	turn_label.text = _format_turn_label(turn_data)
	print_debug("[SelectionOverlay] Turn info: %s" % turn_label.text)

func _format_turn_label(td: Dictionary) -> String:
	var idx = td.get("agent_index", 0) + 1
	var total = td.get("total_agents", 1)
	return "Turn %s / %s\nAgent: %s\nDistance: %s m\nActions left: %s" % [
		str(idx),
		str(total),
		str(td.get("agent_name", "-")),
		str(td.get("movements_left", "-")),
		str(td.get("actions_left", "-"))
	]

func _request_initial_turn_info() -> void:
	if not session_controller:
		return
	var agent_manager = session_controller.get_agent_manager()
	if not agent_manager:
		return
	var agent = agent_manager.get_active_agent()
	if not agent:
		return
	var info = {
		"turn_number": agent_manager.current_round + 1,
		"agent_name": agent.agent_name,
		"agent_index": agent_manager.active_agent_index,
		"total_agents": agent_manager.get_all_agents().size(),
		"movements_left": agent.get_movements_remaining() if agent.has_method("get_movements_remaining") else agent.max_movements_per_turn,
		"actions_left": agent.get_actions_remaining() if agent.has_method("get_actions_remaining") else "-"
	}
	_on_turn_info_changed(info)
	print_debug("[SelectionOverlay] Initial turn info requested")
