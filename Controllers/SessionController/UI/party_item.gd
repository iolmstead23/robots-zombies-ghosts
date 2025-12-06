extends PanelContainer

signal party_updated(party_id, field, value)
signal party_removed(party_id)

var party_data = {}

@onready var party_name_label = $MarginContainer/VBoxContainer/HeaderRow/PartyNameLabel
@onready var party_size_spinbox = $MarginContainer/VBoxContainer/ConfigRow/PartySizeSpinBox
@onready var robot_button = $MarginContainer/VBoxContainer/ConfigRow/TypeButtonsContainer/RobotButton
@onready var ghost_button = $MarginContainer/VBoxContainer/ConfigRow/TypeButtonsContainer/GhostButton
@onready var zombie_button = $MarginContainer/VBoxContainer/ConfigRow/TypeButtonsContainer/ZombieButton

func set_party_data(data):
	party_data = data
	_update_ui()

func _update_ui():
	if party_name_label:
		party_name_label.text = party_data.get("name", "Party")
	if party_size_spinbox:
		party_size_spinbox.value = party_data.get("agent_count", 1)

	# Update button states based on agent type
	var type_str = party_data.get("agent_type", "robot")
	_update_type_buttons(type_str)

func _update_type_buttons(type_str: String):
	"""Update which type button is pressed"""
	if robot_button:
		robot_button.button_pressed = (type_str == "robot")
	if ghost_button:
		ghost_button.button_pressed = (type_str == "ghost")
	if zombie_button:
		zombie_button.button_pressed = (type_str == "zombie")

func _on_party_size_changed(value):
	party_updated.emit(party_data.id, "agent_count", int(value))

func _on_robot_button_pressed():
	_set_agent_type("robot")

func _on_ghost_button_pressed():
	_set_agent_type("ghost")

func _on_zombie_button_pressed():
	_set_agent_type("zombie")

func _set_agent_type(type_str: String):
	"""Set the agent type and update button states"""
	_update_type_buttons(type_str)
	party_updated.emit(party_data.id, "agent_type", type_str)

func _on_remove_pressed():
	party_removed.emit(party_data.id)
