class_name UIStateManager
extends RefCounted

## Atomized Feature: UI State Management
## Manages UI state transitions, validation, and state history
## Pure logic component - no UI dependencies

# ============================================================================
# SIGNALS
# ============================================================================

signal state_changed(old_state: String, new_state: String, data: Dictionary)
signal state_entered(state_name: String, data: Dictionary)
signal state_exited(state_name: String)

# ============================================================================
# STATE
# ============================================================================

var _current_state: String = ""
var _previous_state: String = ""
var _state_data: Dictionary = {}
var _valid_states: Array[String] = []
var _state_history: Array[String] = []
var _max_history_size: int = 10

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(initial_state: String = "idle", valid_states: Array[String] = []):
	_valid_states = valid_states.duplicate()
	if not _valid_states.is_empty() and not _valid_states.has(initial_state):
		push_warning("UIStateManager: Initial state '%s' not in valid states list" % initial_state)
	_current_state = initial_state
	_state_history.append(initial_state)

# ============================================================================
# PUBLIC API - State Management
# ============================================================================

func change_state(new_state: String, data: Dictionary = {}) -> bool:
	"""Change to a new state"""
	if not _is_valid_state(new_state):
		push_warning("UIStateManager: Invalid state '%s'" % new_state)
		return false

	if _current_state == new_state:
		# State unchanged, just update data
		_state_data = data.duplicate()
		return true

	var old_state = _current_state

	# Exit current state
	state_exited.emit(old_state)

	# Update state
	_previous_state = old_state
	_current_state = new_state
	_state_data = data.duplicate()

	# Add to history
	_add_to_history(new_state)

	# Emit signals
	state_entered.emit(new_state, _state_data)
	state_changed.emit(old_state, new_state, _state_data)

	return true

func get_current_state() -> String:
	"""Get the current state name"""
	return _current_state

func get_previous_state() -> String:
	"""Get the previous state name"""
	return _previous_state

func get_state_data() -> Dictionary:
	"""Get the current state data"""
	return _state_data.duplicate()

func set_state_data(data: Dictionary) -> void:
	"""Update the current state data without changing state"""
	_state_data = data.duplicate()

func is_in_state(state_name: String) -> bool:
	"""Check if currently in a specific state"""
	return _current_state == state_name

func is_in_any_state(states: Array[String]) -> bool:
	"""Check if currently in any of the specified states"""
	return states.has(_current_state)

# ============================================================================
# PUBLIC API - Valid States
# ============================================================================

func set_valid_states(states: Array[String]) -> void:
	"""Define the valid states for this manager"""
	_valid_states = states.duplicate()
	if not _valid_states.is_empty() and not _valid_states.has(_current_state):
		push_warning("UIStateManager: Current state '%s' not in new valid states list" % _current_state)

func add_valid_state(state_name: String) -> void:
	"""Add a new valid state"""
	if not _valid_states.has(state_name):
		_valid_states.append(state_name)

func remove_valid_state(state_name: String) -> void:
	"""Remove a valid state"""
	var index = _valid_states.find(state_name)
	if index >= 0:
		_valid_states.remove_at(index)

func get_valid_states() -> Array[String]:
	"""Get list of valid states"""
	return _valid_states.duplicate()

# ============================================================================
# PUBLIC API - State History
# ============================================================================

func get_state_history() -> Array[String]:
	"""Get the state history"""
	return _state_history.duplicate()

func clear_history() -> void:
	"""Clear the state history (keeps current state)"""
	_state_history.clear()
	_state_history.append(_current_state)

func set_max_history_size(size: int) -> void:
	"""Set the maximum history size"""
	_max_history_size = max(1, size)
	_trim_history()

func revert_to_previous() -> bool:
	"""Revert to the previous state"""
	if _previous_state.is_empty():
		return false
	return change_state(_previous_state)

# ============================================================================
# PUBLIC API - Utility
# ============================================================================

func reset(initial_state: String = "idle") -> void:
	"""Reset to initial state"""
	_previous_state = _current_state
	_current_state = initial_state
	_state_data.clear()
	_state_history.clear()
	_state_history.append(initial_state)
	state_changed.emit(_previous_state, _current_state, {})

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _is_valid_state(state_name: String) -> bool:
	"""Check if a state is valid"""
	# If no valid states defined, all states are valid
	if _valid_states.is_empty():
		return true
	return _valid_states.has(state_name)

func _add_to_history(state_name: String) -> void:
	"""Add a state to the history"""
	_state_history.append(state_name)
	_trim_history()

func _trim_history() -> void:
	"""Trim history to max size"""
	while _state_history.size() > _max_history_size:
		_state_history.pop_front()