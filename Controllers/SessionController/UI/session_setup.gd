extends Control

# --- CONSTANTS ---
const PARTY_ITEM_SCENE: PackedScene = preload("res://Controllers/SessionController/UI/party_item.tscn")

# --- STATE ---
var parties: Array = []
var party_id_counter: int = 0
var party_type_counters: Dictionary = {
	"robot": 0,
	"ghost": 0,
	"zombie": 0
}
var debug_mode_enabled: bool = false

@onready var parties_list: VBoxContainer = $VBoxContainer/ContentArea/MainContent/PartiesSection/PartiesScrollContainer/PartiesList
@onready var debug_checkbox: CheckBox = $VBoxContainer/SessionOptionsFooter/MarginContainer/VBoxContainer/OptionsContainer/DebugModeCheckbox
@onready var start_session_button: Button = $VBoxContainer/BottomBar/CenterContainer/StartSessionButton

# --- LIFECYCLE ---
func _ready() -> void:
	_validate_start_button()

# --- UI CALLBACKS ---
func _on_back_pressed() -> void:
	_change_scene("res://Controllers/SessionController/UI/main_menu.tscn")

func _on_add_party_pressed() -> void:
	var party = _create_new_party()
	parties.append(party)
	_add_party_item_ui(party)

func _on_party_updated(party_id: int, field: String, value) -> void:
	for party in parties:
		if party.id == party_id:
			var old_value = party.get(field)
			party[field] = value

			# If type changed, update name and counter
			if field == "agent_type":
				_handle_type_change(party, old_value, value)

			print_debug("Updated party %s: %s -> %s" % [party_id, field, value])
			_validate_start_button()
			return

func _on_party_removed(party_id: int) -> void:
	var removed_party = _get_party_by_id(party_id)
	if removed_party:
		_decrement_type_counter(removed_party.get("agent_type", "robot"))
	_remove_party_from_list(party_id)
	_remove_party_from_ui(party_id)
	_validate_start_button()

func _on_debug_mode_toggled(toggled_on: bool) -> void:
	debug_mode_enabled = toggled_on
	print_debug("Debug mode: %s" % ("enabled" if toggled_on else "disabled"))

func _on_start_session_pressed() -> void:
	SessionData.set_session_parties(parties)
	SessionData.set_debug_enabled(debug_mode_enabled)
	_change_scene("res://main.tscn")

# --- HELPERS ---
func _create_new_party() -> Dictionary:
	var default_type = "robot"

	var new_party = {
		"id": party_id_counter,
		"name": "Party %d" % (party_id_counter + 1),
		"agent_type": default_type,
		"agent_count": 1
	}
	party_id_counter += 1
	_increment_type_counter(default_type)
	print_debug("Created new party: %s" % new_party)
	return new_party

func _add_party_item_ui(party: Dictionary) -> void:
	var item = PARTY_ITEM_SCENE.instantiate()
	item.set_party_data(party)
	item.party_updated.connect(_on_party_updated)
	item.party_removed.connect(_on_party_removed)
	parties_list.add_child(item)
	print_debug("Added party UI item: %s" % party.id)

func _remove_party_from_list(party_id: int) -> void:
	for i in parties.size():
		if parties[i].id == party_id:
			parties.remove_at(i)
			print_debug("Removed party from list: %s" % party_id)
			return

func _remove_party_from_ui(party_id: int) -> void:
	for child in parties_list.get_children():
		if child.party_data.id == party_id:
			child.queue_free()
			print_debug("Removed party UI for: %s" % party_id)
			return

func _change_scene(path: String) -> void:
	print_debug("Changing scene to %s" % path)
	get_tree().change_scene_to_file(path)

func _validate_start_button() -> void:
	"""Enable/disable start button based on party validation"""
	if not start_session_button:
		return

	var has_parties = parties.size() > 0
	start_session_button.disabled = not has_parties

	# Visual feedback - gray out when disabled
	if start_session_button.disabled:
		start_session_button.modulate = Color(0.5, 0.5, 0.5, 0.7)
	else:
		start_session_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

	print_debug("Start button validation: parties=%d, enabled=%s" % [parties.size(), not start_session_button.disabled])

func _increment_type_counter(type: String) -> int:
	"""Increment and return the counter for a specific agent type"""
	party_type_counters[type] += 1
	return party_type_counters[type]

func _decrement_type_counter(type: String) -> void:
	"""Decrement the counter for a specific agent type"""
	if party_type_counters.has(type) and party_type_counters[type] > 0:
		party_type_counters[type] -= 1

func _handle_type_change(party: Dictionary, old_type: String, new_type: String) -> void:
	"""Handle party type change - update counters"""
	_decrement_type_counter(old_type)
	_increment_type_counter(new_type)

	# Party name stays the same (just "Party 1", "Party 2", etc.)
	# Update UI to reflect type change
	for child in parties_list.get_children():
		if child.party_data.id == party.id:
			child.set_party_data(party)
			break

func _get_party_by_id(party_id: int) -> Dictionary:
	"""Get party dictionary by ID"""
	for party in parties:
		if party.id == party_id:
			return party
	return {}
