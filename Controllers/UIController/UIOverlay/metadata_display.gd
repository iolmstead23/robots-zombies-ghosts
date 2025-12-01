extends CanvasLayer

# --- UI REFERENCES ---
@onready var control: Control = $Control
@onready var label: Label = $Control/Panel/MarginContainer/VBoxContainer/Label

# --- CONTROLLERS ---
var session_controller: Node = null
var ui_controller: Node = null

# --- LIFECYCLE ---
func _ready() -> void:
	layer = 100
	_connect_controllers()
	visible = ui_controller and ui_controller.ui_visible
	_update_metadata_display()

# --- CONTROLLER CONNECTIONS ---
func _connect_controllers() -> void:
	session_controller = _find_in_tree("SessionController")
	if not session_controller:
		push_warning("MetadataDisplay: SessionController not found")
		visible = false
		return
	if not session_controller.is_session_active():
		await session_controller.session_initialized
	ui_controller = session_controller.get_ui_controller()
	if not ui_controller:
		push_warning("MetadataDisplay: UIController not found")
		visible = false
		return
	ui_controller.ui_visibility_changed.connect(_on_ui_visibility_changed)
	ui_controller.selected_item_changed.connect(_on_selected_item_changed)

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

# --- SIGNAL HANDLERS ---
func _on_ui_visibility_changed(visible_now: bool) -> void:
	visible = visible_now
	if visible_now:
		_update_metadata_display()
	print_debug("MetadataDisplay: visibility changed %s" % visible_now)

func _on_selected_item_changed(_item: Dictionary) -> void:
	_update_metadata_display()

# --- DISPLAY LOGIC ---
func _update_metadata_display() -> void:
	if not ui_controller:
		return
	var item = ui_controller.get_selected_item()
	label.text = _format_metadata_text(item)
	print_debug("MetadataDisplay: updated")

func _format_metadata_text(item: Dictionary) -> String:
	var out: Array = ["=== SELECTED ITEM ===", ""]
	if item.get("has_selection", false):
		if item.has("item_type"):
			out.append("Type: %s" % item.get("item_type"))
		if item.has("item_name"):
			out.append("Name: %s" % item.get("item_name"))
		var meta = item.get("metadata", {})
		if meta.size() > 0:
			out.append("")
			out.append("--- METADATA ---")
			for key in meta:
				var value = meta[key]
				out.append(_format_meta_line(key, value))
	else:
		out += ["No item selected", "", "Click on an item to", "view its metadata"]
	return "\n".join(out)

func _format_meta_line(key, value) -> String:
	match typeof(value):
		TYPE_VECTOR2:
			return "%s: (%.1f, %.1f)" % [key, value.x, value.y]
		TYPE_VECTOR2I:
			return "%s: (%d, %d)" % [key, value.x, value.y]
		TYPE_BOOL:
			return "%s: %s" % [key, "Yes" if value else "No"]
		TYPE_FLOAT:
			return "%s: %.2f" % [key, value]
		_:
			return "%s: %s" % [key, str(value)]
