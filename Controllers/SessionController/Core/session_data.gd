extends Node

# Session configuration data
var session_parties = []

# Harden: Forbid storing Node/agent node references in session_parties (config only)
func _recursive_find_node(val, path := "") -> Variant:
	if val == null:
		return null
	if val is Node:
		return [path, val]
	if val is Array:
		for i in range(val.size()):
			var found = _recursive_find_node(val[i], "%s[%d]" % [path, i])
			if found != null:
				return found
	if val is Dictionary:
		for k in val.keys():
			var found = _recursive_find_node(val[k], "%s[%s]" % [path, str(k)])
			if found != null:
				return found
	return null

func set_session_parties(parties):
	
	var node_ref_details = _recursive_find_node(parties, "root")
	if node_ref_details != null:
		var path = "[unknown]"
		var val = "[unknown]"
		if typeof(node_ref_details) == TYPE_ARRAY and node_ref_details.size() >= 2:
			var details_array: Array = node_ref_details as Array
			path = details_array[0]
			val = str(details_array[1])
		else:
			printerr("[SessionData] DIAGNOSTIC: node_ref_details has unexpected structure: %s" % [str(node_ref_details)])
		printerr("[SessionData] ERROR: Attempted to assign Node/agent reference to session_parties at %s. Value: %s\n%s" % [path, val, get_stack()])
		push_error("[SessionData] ABORTED session_parties assignment due to forbidden Node/agent value.")
		return
	if parties == null or typeof(parties) != TYPE_ARRAY:
		printerr("[SessionData] ERROR: Invalid session_parties assignment attempted (parties is null or not array). Value: %s\n%s" % [str(parties), get_stack()])
		push_error("[SessionData] session_parties not set. Data must be array.")
		return
	session_parties = parties.duplicate(true)

func get_session_parties():
	return session_parties

func get_total_agent_count():
	var total = 0
	if session_parties == null or typeof(session_parties) != TYPE_ARRAY:
		printerr("[SessionData] ERROR: session_parties is null or not array in get_total_agent_count. Value: %s\n%s" % [str(session_parties), get_stack()])
		return 0
	for i in range(session_parties.size()):
		var party = session_parties[i]
		if party == null or typeof(party) != TYPE_DICTIONARY:
			printerr("[SessionData] WARNING: session_parties[%d] is invalid in get_total_agent_count (party=%s)" % [i, str(party)])
			continue
		if "type" in party and party.type == "agent" and "agent_count" in party and typeof(party.agent_count) == TYPE_INT:
			total += party.agent_count
		else:
			printerr("[SessionData] WARNING: party[%d] missing required keys or has wrong type: %s" % [i, str(party)])
	return total

func clear_session():
	session_parties.clear()