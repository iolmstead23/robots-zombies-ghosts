extends Node
class_name StateManager

## Manages player state and tracks state changes

# Current state dictionary
var state := {
	"facing_direction": "down",
	"is_moving": false,
	"has_input": false,
	"is_running": false,
	"is_jumping": false,
	"is_aiming": false,
	"is_shooting": false,
	"animation_type": "idle"
}

# Previous state for change detection
var prev_state := {}

# State history for debugging or rollback
var state_history := []
const MAX_HISTORY_SIZE := 10

# Signals
signal state_changed(new_state: Dictionary)
signal state_value_changed(key: String, value: Variant)

func _ready() -> void:
	prev_state = state.duplicate()

## Update a single state value
func set_state_value(key: String, value: Variant) -> void:
	if key in state:
		var old_value = state[key]
		if old_value != value:
			state[key] = value
			state_value_changed.emit(key, value)

## Get a single state value
func get_state_value(key: String) -> Variant:
	if key in state:
		return state[key]
	else:
		push_error("State key not found: " + key)
		return null

## Update multiple state values at once
func set_state_values(updates: Dictionary) -> void:
	for key in updates:
		set_state_value(key, updates[key])

## Get the entire state dictionary
func get_state() -> Dictionary:
	return state.duplicate()

## Get the previous state dictionary
func get_prev_state() -> Dictionary:
	return prev_state.duplicate()

## Check if state has changed since last frame
func has_state_changed() -> bool:
	return state_changed_from(prev_state)

## Check if state has changed from a specific state
func state_changed_from(other_state: Dictionary) -> bool:
	for key in state:
		if state[key] != other_state.get(key):
			return true
	return false

## Get changed keys between current and previous state
func get_changed_keys() -> Array:
	var changed := []
	for key in state:
		if state[key] != prev_state.get(key):
			changed.append(key)
	return changed

## Update animation type based on current state
func update_animation_type() -> void:
	var new_animation_type := "idle"
	
	# Priority system for animation states
	if state.is_shooting:
		if state.is_moving:
			new_animation_type = "walk_shoot"
		else:
			new_animation_type = "standing_shoot"
	elif state.is_jumping:
		# Use the jump component's was_running flag for this
		new_animation_type = "jump"  # This will be set properly by animation controller
	elif state.is_aiming:
		if state.is_moving:
			new_animation_type = "walk_shoot"
		else:
			new_animation_type = "idle_aim"
	elif state.is_moving:
		if state.is_running:
			new_animation_type = "run"
		else:
			new_animation_type = "walk"
	else:
		new_animation_type = "idle"
	
	set_state_value("animation_type", new_animation_type)

## Called at the end of each frame to save state
func save_state() -> void:
	prev_state = state.duplicate()
	
	# Add to history
	state_history.push_front(state.duplicate())
	if state_history.size() > MAX_HISTORY_SIZE:
		state_history.pop_back()
	
	# Emit signal if state changed
	if has_state_changed():
		state_changed.emit(state)

## Reset state to default values
func reset_state() -> void:
	state = {
		"facing_direction": "down",
		"is_moving": false,
		"has_input": false,
		"is_running": false,
		"is_jumping": false,
		"is_aiming": false,
		"is_shooting": false,
		"animation_type": "idle"
	}
	prev_state = state.duplicate()
	state_history.clear()

## Get state from history (0 = current, 1 = previous frame, etc.)
func get_state_from_history(index: int) -> Dictionary:
	if index < state_history.size():
		return state_history[index]
	return {}

## Debug function to print current state
func print_state() -> void:
	print("=== Player State ===")
	print("Is Moving: ", state.is_moving)
	print("Has Input: ", state.has_input)
	print("Is Running: ", state.is_running)
	print("Is Jumping: ", state.is_jumping)
	print("Is Aiming: ", state.is_aiming)
	print("Is Shooting: ", state.is_shooting)
	print("Direction: ", state.facing_direction)
	print("Animation: ", state.animation_type)
	
	var changed := get_changed_keys()
	if changed.size() > 0:
		print("Changed: ", changed)
