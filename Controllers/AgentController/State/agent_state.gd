extends Node
class_name AgentState

## Centralised state bag for the AgentController component system.
## All components read and write agent flags (facing, movement, combat, jump)
## through this node, which emits signals on every change and maintains a bounded
## history for debugging.

var state := {
	"facing_direction": "down",
	"is_moving": false,
	"is_active": false,
	"is_running": false,
	"is_jumping": false,
	"jump_height": 0.0,
	"is_aiming": false,
	"is_shooting": false,
	"animation_type": "idle"
}

var prev_state := {}

var state_history := []
const MAX_HISTORY_SIZE := 10

var _state_snapshot_history := []
const MAX_SNAPSHOT_SIZE := 50

signal state_changed(new_state: Dictionary)
signal state_value_changed(key: String, value: Variant)

func _ready() -> void:
	prev_state = state.duplicate()

func set_state_value(key: String, value: Variant) -> void:
	if key not in state:
		return

	var old_value = state[key]
	if old_value != value:
		state[key] = value
		state_value_changed.emit(key, value)
		_log_state_change(key, old_value, value)

func _log_state_change(key: String, old_value: Variant, new_value: Variant) -> void:
	if not OS.is_debug_build():
		return

	var active_states := _get_active_states()
	print_debug("FSM: %s = %s (was %s) | active: %s" % [key, new_value, old_value, active_states])

func _get_active_states() -> String:
	var active := []
	if state.is_moving:
		active.append("MOVING")
	if state.is_jumping:
		active.append("JUMPING")
	if state.is_aiming:
		active.append("AIMING")
	if state.is_shooting:
		active.append("SHOOTING")
	if state.is_running:
		active.append("RUNNING")
	return "[%s]" % ", ".join(active) if active else "[]"

func get_state_value(key: String) -> Variant:
	if key in state:
		return state[key]

	push_error("AgentState: Key not found: %s" % key)
	return null

func set_state_values(updates: Dictionary) -> void:
	for key in updates:
		set_state_value(key, updates[key])

func get_state() -> Dictionary:
	return state.duplicate()

func has_state_changed() -> bool:
	return _state_changed_from(prev_state)

func _state_changed_from(other_state: Dictionary) -> bool:
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
	var active: bool = state.is_moving or state.is_aiming or state.is_shooting or state.is_jumping
	set_state_value("is_active", active)

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
	if has_state_changed():
		state_changed.emit(state.duplicate())
		_push_history(state.duplicate())
		_snapshot_state_change()
	prev_state = state.duplicate()

func _snapshot_state_change() -> void:
	if not OS.is_debug_build():
		return

	var changed := get_changed_keys()
	if changed.is_empty():
		return

	var snapshot := {
		"frame": Engine.get_physics_frames(),
		"time": Time.get_ticks_msec() / 1000.0,
		"changed_keys": changed,
		"new_state": state.duplicate(),
		"prev_state": prev_state.duplicate()
	}

	_state_snapshot_history.append(snapshot)
	if _state_snapshot_history.size() > MAX_SNAPSHOT_SIZE:
		_state_snapshot_history.pop_front()

func _push_history(snapshot: Dictionary) -> void:
	state_history.push_front(snapshot)
	if state_history.size() > MAX_HISTORY_SIZE:
		state_history.pop_back()

func print_state() -> void:
	if not OS.is_debug_build():
		return

	print("=== AgentState ===")
	print("Moving: %s | Input: %s | Running: %s" % [state.is_moving, state.has_input, state.is_running])
	print("Jumping: %s | Aiming: %s | Shooting: %s" % [state.is_jumping, state.is_aiming, state.is_shooting])
	print("Direction: %s | Animation: %s" % [state.facing_direction, state.animation_type])

	var changed := get_changed_keys()
	if changed.size() > 0:
		print("Changed: %s" % changed)

func print_state_snapshot_history() -> void:
	if not OS.is_debug_build():
		return

	print("\n=== State Change History ===")
	for i in range(_state_snapshot_history.size()):
		var snap = _state_snapshot_history[i]
		var changed_str = ", ".join(snap.changed_keys)
		print("[frame %d @ %.2fs] → %s" % [snap.frame, snap.time, changed_str])
	print("===========================\n")
