class_name SelectionManager
extends RefCounted

## Atomized Feature: Selection Management
## Handles selection state, validation, and selection data management
## Pure logic component - no UI dependencies

# ============================================================================
# SIGNALS
# ============================================================================

signal selection_changed(item_data: Dictionary)
signal selection_cleared()

# ============================================================================
# STATE
# ============================================================================

var _current_selection: Dictionary = {}
var _has_selection: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	clear_selection()

# ============================================================================
# PUBLIC API
# ============================================================================

func select_item(item_name: String, item_type: String, metadata: Dictionary = {}) -> void:
	"""Select an item with the given data"""
	_current_selection = {
		"has_selection": true,
		"item_name": item_name,
		"item_type": item_type,
		"metadata": metadata.duplicate()
	}
	_has_selection = true
	selection_changed.emit(_current_selection.duplicate())

func update_selection(item_data: Dictionary) -> void:
	"""Update selection with a complete data dictionary"""
	if not _validate_selection_data(item_data):
		push_warning("SelectionManager: Invalid selection data")
		return

	_current_selection = item_data.duplicate()
	_has_selection = _current_selection.get("has_selection", false)

	if _has_selection:
		selection_changed.emit(_current_selection.duplicate())
	else:
		clear_selection()

func clear_selection() -> void:
	"""Clear the current selection"""
	_current_selection = {
		"has_selection": false,
		"item_name": "",
		"item_type": "",
		"metadata": {}
	}
	_has_selection = false
	selection_cleared.emit()

func get_selection() -> Dictionary:
	"""Get the current selection data"""
	return _current_selection.duplicate()

func has_selection() -> bool:
	"""Check if there is an active selection"""
	return _has_selection

func get_selected_name() -> String:
	"""Get the name of the selected item"""
	return _current_selection.get("item_name", "")

func get_selected_type() -> String:
	"""Get the type of the selected item"""
	return _current_selection.get("item_type", "")

func get_metadata() -> Dictionary:
	"""Get the metadata of the selected item"""
	return _current_selection.get("metadata", {}).duplicate()

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _validate_selection_data(data: Dictionary) -> bool:
	"""Validate that selection data has required fields"""
	return data.has("has_selection") and \
		   data.has("item_name") and \
		   data.has("item_type") and \
		   data.has("metadata")
