class_name SelectableObject
extends Node2D

## Base class for any object that can be selected and display metadata in the UI overlay
##
## Usage:
##   1. Extend this class for your selectable objects
##   2. Set object_name and object_type in _ready()
##   3. Override _build_metadata() to add custom metadata fields
##   4. Ensure the object has input detection (CollisionObject2D or Area2D)
##
## The object will automatically:
##   - Add itself to the "selectable" group
##   - Format metadata for the UI overlay
##   - Emit signals when clicked

# ============================================================================
# EXPORTS
# ============================================================================

@export var object_name: String = "Unnamed Object"
@export var object_type: String = "Object"

# ============================================================================
# STATE
# ============================================================================

# Custom metadata that can be set per-instance or in code
var custom_metadata: Dictionary = {}

# ============================================================================
# SIGNALS
# ============================================================================

signal selection_requested(selectable: SelectableObject)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	# Add to "selectable" group for easy querying by SelectionController
	add_to_group("selectable")

# ============================================================================
# PUBLIC API
# ============================================================================

## Returns formatted selection data for the UI overlay
func get_selection_data() -> Dictionary:
	return {
		"has_selection": true,
		"item_type": object_type,
		"item_name": object_name,
		"metadata": _build_metadata()
	}

# ============================================================================
# VIRTUAL METHODS (Override in subclasses)
# ============================================================================

## Override this method to add custom metadata fields for your object type
## Always call super._build_metadata() first to include base metadata
func _build_metadata() -> Dictionary:
	var metadata = custom_metadata.duplicate()

	# Add common properties
	metadata["position"] = global_position
	metadata["in_scene"] = is_inside_tree()

	return metadata

# ============================================================================
# INPUT HANDLING
# ============================================================================

## Called by CollisionObject2D when clicked (if the object has collision)
## Connect this to Area2D.input_event or use _input_event on StaticBody2D/etc
func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			selection_requested.emit(self)
			get_viewport().set_input_as_handled()
