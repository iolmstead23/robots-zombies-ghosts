class_name SelectionController
extends Node

## Manages object selection and communicates with UIController
##
## This controller:
##   - Automatically discovers and connects to all selectable objects (any object in "selectable" group)
##   - Tracks the currently selected object
##   - Emits signals when selection changes
##   - Updates the UI overlay with selected object metadata
##
## Integration:
##   - Created by SessionController
##   - Connected to UIController for metadata display
##   - Works with any object that has get_selection_data() method

# ============================================================================
# SIGNALS
# ============================================================================

signal object_selected(selection_data: Dictionary)
signal selection_cleared()

# ============================================================================
# STATE
# ============================================================================

var currently_selected = null  # Any object with get_selection_data() method
var ui_controller: UIController = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	# Connect to all existing selectable objects
	_connect_selectables()

	# Listen for new objects added to scene tree
	get_tree().node_added.connect(_on_node_added)

	if OS.is_debug_build():
		print("SelectionController: Initialized")

# ============================================================================
# PUBLIC API
# ============================================================================

## Set the UIController reference for metadata display updates
func set_ui_controller(controller: UIController):
	ui_controller = controller
	if OS.is_debug_build():
		print("SelectionController: UIController reference set")

## Select an object and update the UI overlay
## Works with any object that has a get_selection_data() method
func select_object(selectable):
	if currently_selected == selectable:
		return

	# Verify the object has the required method
	if not selectable.has_method("get_selection_data"):
		push_error("SelectionController: Object does not have get_selection_data() method")
		return

	currently_selected = selectable
	var selection_data = selectable.get_selection_data()

	object_selected.emit(selection_data)

	# Update UI overlay
	if ui_controller:
		ui_controller.update_selected_item_requested.emit(selection_data)

	if OS.is_debug_build():
		print("SelectionController: Selected '%s' (%s)" % [
			selection_data.get("item_name"),
			selection_data.get("item_type")
		])

## Clear the current selection
func clear_selection():
	currently_selected = null
	selection_cleared.emit()

	if ui_controller:
		ui_controller.clear_selected_item_requested.emit()

	if OS.is_debug_build():
		print("SelectionController: Selection cleared")

## Get the currently selected object (or null)
func get_selected_object():
	return currently_selected

# ============================================================================
# INTERNAL - SELECTABLE OBJECT DISCOVERY
# ============================================================================

## Connect to all selectable objects currently in the scene tree
## Only connects to objects that have get_selection_data() method
func _connect_selectables():
	var count = 0
	for node in get_tree().get_nodes_in_group("selectable"):
		if node.has_method("get_selection_data"):
			count += 1

	if OS.is_debug_build():
		print("SelectionController: Found %d selectable objects" % count)

## Called when a new node is added to the scene tree
func _on_node_added(node: Node):
	if node.is_in_group("selectable") and node.has_method("get_selection_data"):
		if OS.is_debug_build():
			print("SelectionController: New selectable object added '%s'" % node.name)

