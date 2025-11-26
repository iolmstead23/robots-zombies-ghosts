extends Control

# Preload the PartyItem scene
const PartyItem = preload("res://Controllers/SessionController/UI/PartyItem.tscn")

# Session data
var parties = []
var party_id_counter = 0

@onready var parties_list = $VBoxContainer/ContentArea/MainContent/PartiesSection/PartiesScrollContainer/PartiesList

func _ready():
	pass

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Controllers/SessionController/UI/MainMenu.tscn")

func _on_add_party_pressed():
	# Create a new party with default values
	var party_data = {
		"id": party_id_counter,
		"name": "Robot Party " + str(party_id_counter + 1),
		"type": "robot",
		"robot_count": 1
	}
	party_id_counter += 1
	parties.append(party_data)

	# Create and add the party UI item
	var party_item = PartyItem.instantiate()
	party_item.set_party_data(party_data)
	party_item.party_updated.connect(_on_party_updated)
	party_item.party_removed.connect(_on_party_removed)
	parties_list.add_child(party_item)

func _on_party_updated(party_id, field, value):
	# Update the party data when values change
	for party in parties:
		if party.id == party_id:
			party[field] = value
			break

func _on_party_removed(party_id):
	# Remove party from data
	for i in range(parties.size()):
		if parties[i].id == party_id:
			parties.remove_at(i)
			break

	# Remove party from UI
	for child in parties_list.get_children():
		if child.party_data.id == party_id:
			child.queue_free()
			break

func _on_start_session_pressed():
	# Store session data in an autoload singleton (we'll create this)
	SessionData.set_session_parties(parties)

	# Start the game
	get_tree().change_scene_to_file("res://main.tscn")
