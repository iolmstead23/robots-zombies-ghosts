extends Node

# Session configuration data
var session_parties = []

func set_session_parties(parties):
	session_parties = parties.duplicate(true)

func get_session_parties():
	return session_parties

func get_total_robot_count():
	var total = 0
	for party in session_parties:
		if party.type == "robot":
			total += party.robot_count
	return total

func clear_session():
	session_parties.clear()
