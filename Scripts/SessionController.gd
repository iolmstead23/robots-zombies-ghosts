extends Node

# Signal API for debug UI updates
signal debug_info_updated(key: String, value: Variant)
signal debug_visibility_changed(visible: bool)

# Debug state
var debug_visible: bool = true
var debug_data: Dictionary = {}

func _ready():
	# Initialize debug data with default values
	debug_data = {
		"fps": 0,
		"entities": 0,
		"player_pos": Vector2.ZERO
	}

func _input(event):
	if event.is_action_pressed("toggle_debug"):
		toggle_debug_visibility()

# Public API for toggling debug UI visibility
func toggle_debug_visibility():
	debug_visible = !debug_visible
	debug_visibility_changed.emit(debug_visible)

func set_debug_visibility(visible: bool):
	debug_visible = visible
	debug_visibility_changed.emit(debug_visible)

# Public API for updating debug information
func update_debug_info(key: String, value: Variant):
	debug_data[key] = value
	debug_info_updated.emit(key, value)

func get_debug_info(key: String) -> Variant:
	return debug_data.get(key, null)

func get_all_debug_info() -> Dictionary:
	return debug_data.duplicate()