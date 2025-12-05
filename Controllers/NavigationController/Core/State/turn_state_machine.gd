extends Node
class_name TurnStateMachine

"""
Manages turn-based movement state machine.

Design notes:
- Tracks current turn state
- Validates state transitions
- Emits signals on state changes
"""

# ----------------------
# Signals
# ----------------------

signal state_changed(old_state: NavigationTypes.TurnState, new_state: NavigationTypes.TurnState)
signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)

# ----------------------
# State Variables
# ----------------------

var current_state: NavigationTypes.TurnState = NavigationTypes.TurnState.IDLE
var current_turn: int = 0
var previous_state: NavigationTypes.TurnState = NavigationTypes.TurnState.IDLE

# ----------------------
# State Transitions
# ----------------------

## Change to a new state
func change_state(new_state: NavigationTypes.TurnState) -> bool:
	if not _is_valid_transition(current_state, new_state):
		if OS.is_debug_build():
			push_warning("TurnStateMachine: Invalid transition from %s to %s" % [
				_state_to_string(current_state),
				_state_to_string(new_state)
			])
		return false

	previous_state = current_state
	current_state = new_state
	state_changed.emit(previous_state, current_state)

	return true

## Start a new turn
func start_turn() -> void:
	current_turn += 1
	change_state(NavigationTypes.TurnState.IDLE)
	turn_started.emit(current_turn)

## End current turn
func end_turn() -> void:
	# Only transition to COMPLETED if we're in EXECUTING state
	# Otherwise, just reset to IDLE
	if current_state == NavigationTypes.TurnState.EXECUTING:
		change_state(NavigationTypes.TurnState.COMPLETED)
	else:
		change_state(NavigationTypes.TurnState.IDLE)
	turn_ended.emit(current_turn)

## Reset to idle state
func reset() -> void:
	previous_state = current_state
	current_state = NavigationTypes.TurnState.IDLE
	state_changed.emit(previous_state, current_state)

# ----------------------
# State Queries
# ----------------------

## Check if in a specific state
func is_in_state(state: NavigationTypes.TurnState) -> bool:
	return current_state == state

## Check if in any of multiple states
func is_in_any_state(states: Array) -> bool:
	for state in states:
		if current_state == state:
			return true
	return false

## Check if currently executing movement
func is_executing() -> bool:
	return current_state == NavigationTypes.TurnState.EXECUTING

## Check if movement is active (any non-idle state)
func is_active() -> bool:
	return current_state != NavigationTypes.TurnState.IDLE

# ----------------------
# Validation
# ----------------------

## Validate state transition
func _is_valid_transition(from: NavigationTypes.TurnState, to: NavigationTypes.TurnState) -> bool:
	# Allow any transition to IDLE (reset/cancel)
	if to == NavigationTypes.TurnState.IDLE:
		return true

	# Valid state machine transitions
	match from:
		NavigationTypes.TurnState.IDLE:
			return to in [NavigationTypes.TurnState.PLANNING]

		NavigationTypes.TurnState.PLANNING:
			return to in [NavigationTypes.TurnState.PREVIEW, NavigationTypes.TurnState.IDLE]

		NavigationTypes.TurnState.PREVIEW:
			return to in [NavigationTypes.TurnState.AWAITING_CONFIRMATION, NavigationTypes.TurnState.IDLE]

		NavigationTypes.TurnState.AWAITING_CONFIRMATION:
			return to in [NavigationTypes.TurnState.EXECUTING, NavigationTypes.TurnState.IDLE]

		NavigationTypes.TurnState.EXECUTING:
			return to in [NavigationTypes.TurnState.COMPLETED, NavigationTypes.TurnState.IDLE]

		NavigationTypes.TurnState.COMPLETED:
			return to in [NavigationTypes.TurnState.IDLE]

	return false

# ----------------------
# Utilities
# ----------------------

## Convert state to string for debugging
func _state_to_string(state: NavigationTypes.TurnState) -> String:
	match state:
		NavigationTypes.TurnState.IDLE:
			return "IDLE"
		NavigationTypes.TurnState.PLANNING:
			return "PLANNING"
		NavigationTypes.TurnState.PREVIEW:
			return "PREVIEW"
		NavigationTypes.TurnState.AWAITING_CONFIRMATION:
			return "AWAITING_CONFIRMATION"
		NavigationTypes.TurnState.EXECUTING:
			return "EXECUTING"
		NavigationTypes.TurnState.COMPLETED:
			return "COMPLETED"
	return "UNKNOWN"

## Get current state as string
func get_current_state_string() -> String:
	return _state_to_string(current_state)

# ----------------------
# Debug
# ----------------------

func get_state_info() -> Dictionary:
	return {
		"current_state": get_current_state_string(),
		"previous_state": _state_to_string(previous_state),
		"current_turn": current_turn,
		"is_active": is_active()
	}
