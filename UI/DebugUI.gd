extends CanvasLayer

# Reference to UI elements
@onready var control: Control = $Control
@onready var label: Label = $Control/Panel/MarginContainer/Label

func _ready():
	# Connect to SessionController signals
	SessionController.debug_visibility_changed.connect(_on_debug_visibility_changed)
	SessionController.debug_info_updated.connect(_on_debug_info_updated)

	# Initialize visibility
	visible = SessionController.debug_visible

	# Initialize with current debug data
	_update_display()

func _on_debug_visibility_changed(should_be_visible: bool):
	visible = should_be_visible

func _on_debug_info_updated(_key: String, _value: Variant):
	_update_display()

func _update_display():
	var debug_data = SessionController.get_all_debug_info()
	var text = ""

	for key in debug_data:
		var value = debug_data[key]
		text += "%s: %s\n" % [key, str(value)]

	label.text = text.strip_edges()