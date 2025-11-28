class_name UIController
extends Node

## Manages UI overlay for user feedback
## Communicates exclusively through signals - no direct dependencies on other features
## Distinction: DebugController is for developer feedback, UIController is for user feedback

# ============================================================================
# SIGNALS - Public API
# ============================================================================

## Emitted when UI visibility changes
signal ui_visibility_changed(visible: bool)

## Emitted when selected item changes
signal selected_item_changed(item_data: Dictionary)

# ============================================================================
# SIGNALS - Commands (Received from SessionController or other features)
# ============================================================================

## Request to show/hide UI overlay
signal set_ui_visibility_requested(visible: bool)

## Request to update selected item metadata
signal update_selected_item_requested(item_data: Dictionary)

## Request to clear selected item
signal clear_selected_item_requested()

# ============================================================================
# SIGNALS - State Updates (Received from SessionController)
# ============================================================================

## Receive session state updates
signal on_session_state_changed(state_data: Dictionary)

## Receive grid state updates
signal on_grid_state_changed(grid_data: Dictionary)

# ============================================================================
# STATE
# ============================================================================

var ui_visible: bool = true  # UI overlay is always visible (unlike debug overlay)
var selected_item_data: Dictionary = {}

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	# Initialize selected item data
	selected_item_data = {
		"has_selection": false,
		"item_type": "",
		"item_name": "",
		"metadata": {}
	}

	# Connect to own command signals
	set_ui_visibility_requested.connect(_on_set_ui_visibility_requested)
	update_selected_item_requested.connect(_on_update_selected_item_requested)
	clear_selected_item_requested.connect(_on_clear_selected_item_requested)

	# Connect to state update signals
	on_session_state_changed.connect(_on_session_state_changed)
	on_grid_state_changed.connect(_on_grid_state_changed)

# ============================================================================
# COMMAND HANDLERS
# ============================================================================

func _on_set_ui_visibility_requested(visible: bool):
	set_ui_visibility(visible)

func _on_update_selected_item_requested(item_data: Dictionary):
	update_selected_item(item_data)

func _on_clear_selected_item_requested():
	clear_selected_item()

# ============================================================================
# STATE UPDATE HANDLERS
# ============================================================================

func _on_session_state_changed(_state_data: Dictionary):
	# Handle session state changes if needed
	pass

func _on_grid_state_changed(_grid_data: Dictionary):
	# Handle grid state changes if needed
	pass

# ============================================================================
# PUBLIC API (called internally via signals)
# ============================================================================

func set_ui_visibility(visible: bool):
	ui_visible = visible
	ui_visibility_changed.emit(ui_visible)

func update_selected_item(item_data: Dictionary):
	"""Update the selected item with new metadata"""
	selected_item_data = item_data.duplicate()
	selected_item_data["has_selection"] = true
	selected_item_changed.emit(selected_item_data)

func clear_selected_item():
	"""Clear the current selection"""
	selected_item_data = {
		"has_selection": false,
		"item_type": "",
		"item_name": "",
		"metadata": {}
	}
	selected_item_changed.emit(selected_item_data)

func get_selected_item() -> Dictionary:
	"""Get the currently selected item data"""
	return selected_item_data.duplicate()

func has_selection() -> bool:
	"""Check if there is a current selection"""
	return selected_item_data.get("has_selection", false)
