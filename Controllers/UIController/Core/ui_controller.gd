class_name UIController
extends Node

## Manages UI overlay for user feedback
## Communicates exclusively through signals - no direct dependencies on other features
## Distinction: DebugController is for developer feedback, UIController is for user feedback
## Now built with atomized feature components for better modularity

# ============================================================================
# ATOMIZED FEATURES
# ============================================================================

var selection_manager: SelectionManager
var metadata_formatter: MetadataFormatter
var visibility_controller: OverlayVisibilityController
var state_manager: UIStateManager

# ============================================================================
# SIGNALS - Public API
# ============================================================================

## Emitted when UI visibility changes
signal ui_visibility_changed(visible: bool)

## Emitted when selected item changes
signal selected_item_changed(item_data: Dictionary)

## Emitted when the current turn info changes (used for overlays)
signal turn_info_changed(turn_data: Dictionary)

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
# STATE (Legacy - maintained for compatibility)
# ============================================================================

var ui_visible: bool = true  # UI overlay is always visible (unlike debug overlay)
var selected_item_data: Dictionary = {}

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	_initialize_features()
	_initialize_state()
	_connect_signals()
	_connect_feature_signals()

	## Note: SessionController connects its 'turn_changed' signal to this controller's
	## '_on_turn_changed' handler in SessionController._connect_controller_signals()
	## No manual connection needed here.

	print("UIController: Initialized with atomized features")

# ============================================================================
# INITIALIZATION
# ============================================================================

func _initialize_features():
	"""Initialize all atomized feature components"""
	# Selection management
	selection_manager = SelectionManager.new()

	# Metadata formatting
	metadata_formatter = MetadataFormatter.new()
	metadata_formatter.set_vector_format(MetadataFormatter.VectorFormat.ROUNDED)
	metadata_formatter.set_bool_format(MetadataFormatter.BoolFormat.YES_NO)

	# Visibility control
	visibility_controller = OverlayVisibilityController.new()
	visibility_controller.register_overlay("main_ui", true)

	# State management
	state_manager = UIStateManager.new("idle", ["idle", "selecting", "selected", "editing"])

func _initialize_state():
	"""Initialize legacy state for compatibility"""
	selected_item_data = {
		"has_selection": false,
		"item_type": "",
		"item_name": "",
		"metadata": {}
	}

func _connect_signals():
	"""Connect to own command signals"""
	set_ui_visibility_requested.connect(_on_set_ui_visibility_requested)
	update_selected_item_requested.connect(_on_update_selected_item_requested)
	clear_selected_item_requested.connect(_on_clear_selected_item_requested)

	# Connect to state update signals
	on_session_state_changed.connect(_on_session_state_changed)
	on_grid_state_changed.connect(_on_grid_state_changed)

func _connect_feature_signals():
	"""Connect to atomized feature signals"""
	selection_manager.selection_changed.connect(_on_selection_manager_changed)
	selection_manager.selection_cleared.connect(_on_selection_manager_cleared)

	visibility_controller.visibility_changed.connect(_on_visibility_controller_changed)

	state_manager.state_changed.connect(_on_state_manager_changed)

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
# FEATURE SIGNAL HANDLERS
# ============================================================================

func _on_selection_manager_changed(item_data: Dictionary):
	"""Handle selection changes from SelectionManager"""
	# Update legacy state for compatibility
	selected_item_data = item_data.duplicate()

	# Emit to UI overlays
	selected_item_changed.emit(item_data)

	# Update UI state
	if item_data.get("has_selection", false):
		state_manager.change_state("selected", item_data)
	else:
		state_manager.change_state("idle")

func _on_selection_manager_cleared():
	"""Handle selection cleared from SelectionManager"""
	# Update legacy state
	selected_item_data = {
		"has_selection": false,
		"item_type": "",
		"item_name": "",
		"metadata": {}
	}

	# Emit to UI overlays
	selected_item_changed.emit(selected_item_data)

	# Update UI state
	state_manager.change_state("idle")

func _on_visibility_controller_changed(overlay_name: String, is_visible: bool):
	"""Handle visibility changes from VisibilityController"""
	if overlay_name == "main_ui":
		ui_visible = is_visible
		ui_visibility_changed.emit(is_visible)

func _on_state_manager_changed(old_state: String, new_state: String, _data: Dictionary):
	"""Handle state changes from StateManager"""
	print("UIController: State changed from '%s' to '%s'" % [old_state, new_state])

# ============================================================================
# SIGNAL HANDLERS - SessionController (runtime connection)
# ============================================================================

## Handler stub for SessionController's 'turn_changed' signal.
## Called when the session advances turns. Implement business logic as appropriate.
func _on_turn_changed(turn_data: Dictionary):
	# Forward turn info to overlays
	turn_info_changed.emit(turn_data)
	if OS.is_debug_build():
		print("[UIController] Forwarded turn_info_changed: %s" % str(turn_data))

# ============================================================================
# PUBLIC API (called internally via signals) - Legacy Compatibility
# ============================================================================

func set_ui_visibility(visible: bool):
	visibility_controller.set_overlay_visible("main_ui", visible)

func update_selected_item(item_data: Dictionary):
	"""Update the selected item with new metadata"""
	selection_manager.update_selection(item_data)

func clear_selected_item():
	"""Clear the current selection"""
	selection_manager.clear_selection()

func get_selected_item() -> Dictionary:
	"""Get the currently selected item data"""
	return selection_manager.get_selection()

func has_selection() -> bool:
	"""Check if there is a current selection"""
	return selection_manager.has_selection()

# ============================================================================
# PUBLIC API - New Feature-Based Methods
# ============================================================================

func get_selection_manager() -> SelectionManager:
	"""Get the selection manager feature"""
	return selection_manager

func get_metadata_formatter() -> MetadataFormatter:
	"""Get the metadata formatter feature"""
	return metadata_formatter

func get_visibility_controller() -> OverlayVisibilityController:
	"""Get the visibility controller feature"""
	return visibility_controller

func get_state_manager() -> UIStateManager:
	"""Get the state manager feature"""
	return state_manager

func format_metadata(metadata: Dictionary) -> String:
	"""Format metadata using the MetadataFormatter"""
	return metadata_formatter.format_metadata_dict(metadata)

func get_current_ui_state() -> String:
	"""Get the current UI state"""
	return state_manager.get_current_state()