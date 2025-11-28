extends Node
class_name StateManager

## Manages player state and tracks state changes

# Current state
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

# State history
var state_history := []
const MAX_HISTORY_SIZE := 10

signal state_changed(new_state: Dictionary)
signal state_value_changed(key: String, value: Variant)

func _ready() -> void:
	prev_state = state.duplicate()

func set_state_value(key: String, value: Variant) -> void:
	if key not in state:
		return

	var old_value: Array[String] = state[key]
	if old_value != value:
		state[key] = value
		state_value_changed.emit(key, value)

func get_state_value(key: String) -> Variant:
	if key in state:
		return state[key]

	push_error("StateManager: Key not found: %s" % key)
	return null

func set_state_values(updates: Dictionary) -> void:
	for key in updates:
		set_state_value(key, updates[key])

func get_state() -> Dictionary:
	return state.duplicate()

func get_prev_state() -> Dictionary:
	return prev_state.duplicate()

func has_state_changed() -> bool:
	return state_changed_from(prev_state)

func state_changed_from(other_state: Dictionary) -> bool:
	for key in state:
		if state[key] != other_state.get(key):
			return true
	return false

func get_changed_keys() -> Array:
	var changed := []
	for key in state:
		if state[key] != prev_state.get(key):
			changed.append(key)
	return changed

func update_animation_type() -> void:
	var new_animation_type := _determine_animation_type()
	set_state_value("animation_type", new_animation_type)

func _determine_animation_type() -> String:
	if state.is_shooting:
		return "walk_shoot" if state.is_moving else "standing_shoot"

	if state.is_jumping:
		return "jump"

	if state.is_aiming:
		return "walk_shoot" if state.is_moving else "idle_aim"

	if state.is_moving:
		return "run" if state.is_running else "walk"

	return "idle"

func save_state() -> void:
	prev_state = state.duplicate()

	state_history.push_front(state.duplicate())
	if state_history.size() > MAX_HISTORY_SIZE:
		state_history.pop_back()

	if has_state_changed():
		state_changed.emit(state)

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

func get_state_from_history(index: int) -> Dictionary:
	if index < state_history.size():
		return state_history[index]
	return {}

func print_state() -> void:
	if not OS.is_debug_build():
		return

	print("=== StateManager ===")
	print("Moving: %s | Input: %s | Running: %s" % [state.is_moving, state.has_input, state.is_running])
	print("Jumping: %s | Aiming: %s | Shooting: %s" % [state.is_jumping, state.is_aiming, state.is_shooting])
	print("Direction: %s | Animation: %s" % [state.facing_direction, state.animation_type])

	var changed := get_changed_keys()
	if changed.size() > 0:
		print("Changed: %s" % changed)
