extends PanelContainer

signal party_updated(party_id, field, value)
signal party_removed(party_id)

var party_data = {}

@onready var party_name_label = $MarginContainer/VBoxContainer/HeaderRow/PartyNameLabel
@onready var agent_count_spinbox = $MarginContainer/VBoxContainer/ConfigRow/RobotCountSpinBox

func set_party_data(data):
	party_data = data
	_update_ui()

func _update_ui():
	if party_name_label:
		party_name_label.text = party_data.get("name", "Agent Party")
	if agent_count_spinbox:
		agent_count_spinbox.value = party_data.get("agent_count", 1)

func _on_agent_count_changed(value):
	party_updated.emit(party_data.id, "agent_count", int(value))

func _on_remove_pressed():
	party_removed.emit(party_data.id)
