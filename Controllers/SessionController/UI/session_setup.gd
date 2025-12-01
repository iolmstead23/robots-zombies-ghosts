extends Control

# --- CONSTANTS ---
const PARTY_ITEM_SCENE: PackedScene = preload("res://Controllers/SessionController/UI/party_item.tscn")

# --- STATE ---
var parties: Array = []
var party_id_counter: int = 0

@onready var parties_list: VBoxContainer = $VBoxContainer/ContentArea/MainContent/PartiesSection/PartiesScrollContainer/PartiesList

# --- LIFECYCLE ---
func _ready() -> void:
	pass # No initialization needed

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
			party[field] = value
			print_debug("Updated party %s: %s -> %s" % [party_id, field, value])
			return

func _on_party_removed(party_id: int) -> void:
	_remove_party_from_list(party_id)
	_remove_party_from_ui(party_id)

func _on_start_session_pressed() -> void:
	SessionData.set_session_parties(parties)
	_change_scene("res://main.tscn")

# --- HELPERS ---
func _create_new_party() -> Dictionary:
	var new_party = {
		"id": party_id_counter,
		"name": "Agent Party %d" % [party_id_counter + 1],
		"type": "agent",
		"agent_count": 1
	}
	party_id_counter += 1
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
