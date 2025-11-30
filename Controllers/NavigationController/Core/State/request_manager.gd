extends Node
class_name RequestManager

"""
Manages async request/response patterns for navigation.

Design notes:
- Tracks pending requests
- Manages request lifecycle
- Provides timeout handling
- Thread-safe request ID generation
"""

# ----------------------
# Signals
# ----------------------

signal request_completed(request_id: String, success: bool)
signal request_timeout(request_id: String)

# ----------------------
# State Variables
# ----------------------

# Pending path requests: request_id -> {start_pos, goal_pos, start_cell, goal_cell, timestamp}
var pending_path_requests: Dictionary = {}

# Pending navigation requests: request_id -> {target_pos, target_cell, timestamp}
var pending_nav_requests: Dictionary = {}

# Request timeout (milliseconds)
var request_timeout_duration: int = 5000

# ----------------------
# Path Request Management
# ----------------------

## Create a new path request
func create_path_request(start_pos: Vector2, goal_pos: Vector2) -> String:
	var request_id := _generate_request_id("path")

	pending_path_requests[request_id] = {
		"start_pos": start_pos,
		"goal_pos": goal_pos,
		"timestamp": Time.get_ticks_msec()
	}

	return request_id

## Update path request with cell response
func update_path_request(request_id: String, cell_request_id: String, cell: HexCell) -> void:
	if not pending_path_requests.has(request_id):
		if OS.is_debug_build():
			push_warning("RequestManager: Path request %s not found" % request_id)
		return

	var request = pending_path_requests[request_id]

	if cell_request_id.ends_with("_start"):
		request["start_cell"] = cell
	elif cell_request_id.ends_with("_goal"):
		request["goal_cell"] = cell

## Check if path request is complete (has both cells)
func is_path_request_complete(request_id: String) -> bool:
	if not pending_path_requests.has(request_id):
		return false

	var request = pending_path_requests[request_id]
	return request.has("start_cell") and request.has("goal_cell")

## Get and remove completed path request
func complete_path_request(request_id: String) -> Dictionary:
	if not pending_path_requests.has(request_id):
		return {}

	var request = pending_path_requests[request_id]
	pending_path_requests.erase(request_id)
	request_completed.emit(request_id, true)

	return request

## Cancel path request
func cancel_path_request(request_id: String) -> void:
	if pending_path_requests.has(request_id):
		pending_path_requests.erase(request_id)
		request_completed.emit(request_id, false)

# ----------------------
# Navigation Request Management
# ----------------------

## Create a new navigation request
func create_nav_request(target_pos: Vector2) -> String:
	var request_id := _generate_request_id("nav")

	pending_nav_requests[request_id] = {
		"target_pos": target_pos,
		"timestamp": Time.get_ticks_msec()
	}

	return request_id

## Update navigation request with cell response
func update_nav_request(request_id: String, cell: HexCell) -> void:
	if not pending_nav_requests.has(request_id):
		if OS.is_debug_build():
			push_warning("RequestManager: Nav request %s not found" % request_id)
		return

	pending_nav_requests[request_id]["target_cell"] = cell

## Check if navigation request is complete
func is_nav_request_complete(request_id: String) -> bool:
	if not pending_nav_requests.has(request_id):
		return false

	return pending_nav_requests[request_id].has("target_cell")

## Get and remove completed navigation request
func complete_nav_request(request_id: String) -> Dictionary:
	if not pending_nav_requests.has(request_id):
		return {}

	var request = pending_nav_requests[request_id]
	pending_nav_requests.erase(request_id)
	request_completed.emit(request_id, true)

	return request

## Cancel navigation request
func cancel_nav_request(request_id: String) -> void:
	if pending_nav_requests.has(request_id):
		pending_nav_requests.erase(request_id)
		request_completed.emit(request_id, false)

# ----------------------
# Request Lookup
# ----------------------

## Find path request ID from cell request ID
func find_path_request_for_cell(cell_request_id: String) -> String:
	for path_request_id in pending_path_requests.keys():
		if cell_request_id.begins_with(path_request_id):
			return path_request_id
	return ""

## Check if request ID is a navigation request
func is_nav_request(request_id: String) -> bool:
	return pending_nav_requests.has(request_id)

# ----------------------
# Timeout Handling
# ----------------------

## Check and process request timeouts
func process_timeouts() -> void:
	var current_time := Time.get_ticks_msec()
	var timeout_ms := request_timeout_duration

	# Check path request timeouts
	for request_id in pending_path_requests.keys():
		var request = pending_path_requests[request_id]
		if current_time - request.timestamp > timeout_ms:
			pending_path_requests.erase(request_id)
			request_timeout.emit(request_id)

	# Check nav request timeouts
	for request_id in pending_nav_requests.keys():
		var request = pending_nav_requests[request_id]
		if current_time - request.timestamp > timeout_ms:
			pending_nav_requests.erase(request_id)
			request_timeout.emit(request_id)

# ----------------------
# Cleanup
# ----------------------

## Clear all pending requests
func clear_all_requests() -> void:
	pending_path_requests.clear()
	pending_nav_requests.clear()

# ----------------------
# Utilities
# ----------------------

## Generate unique request ID
func _generate_request_id(prefix: String) -> String:
	return "%s_%d" % [prefix, Time.get_ticks_msec()]

# ----------------------
# Debug
# ----------------------

func get_request_stats() -> Dictionary:
	return {
		"pending_path_requests": pending_path_requests.size(),
		"pending_nav_requests": pending_nav_requests.size(),
		"total_pending": pending_path_requests.size() + pending_nav_requests.size()
	}
