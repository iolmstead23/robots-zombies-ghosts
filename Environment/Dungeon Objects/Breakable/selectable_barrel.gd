extends StaticBody2D

## Selectable barrel object for testing selection system
## This script makes barrels clickable and displays test metadata

# SelectableObject properties
@export var object_name: String = "Test Barrel"
@export var object_type: String = "Barrel"

# Custom metadata
var custom_metadata: Dictionary = {}

# Signals
signal selection_requested(selection_data: Dictionary)

func _ready():
	# Add to "selectable" group for SelectionController discovery
	add_to_group("selectable")

	# Connect to input_event signal (StaticBody2D has this built-in)
	input_event.connect(_on_input_event)

func get_selection_data() -> Dictionary:
	return {
		"has_selection": true,
		"item_type": object_type,
		"item_name": object_name,
		"metadata": _build_metadata()
	}

func _build_metadata() -> Dictionary:
	var metadata = custom_metadata.duplicate()

	# Add common properties
	metadata["position"] = global_position
	metadata["in_scene"] = is_inside_tree()

	# Add test metadata to verify selection is working
	metadata["test_status"] = "Selection Working"
	metadata["is_selectable"] = true

	return metadata

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Get SelectionController and select this object
			var selection_controller = get_tree().root.find_child("SelectionController", true, false)
			if selection_controller:
				selection_controller.select_object(self)
			else:
				push_error("Barrel: SelectionController not found!")

			get_viewport().set_input_as_handled()
