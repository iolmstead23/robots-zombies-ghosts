extends Node
class_name AgentRegistry

## Central registry for all published agent state. Packages publish owned keys;
## consumers read via query() or subscribe() to changes. No direct cross-package references.

var _state := {}
var _subscribers := {}

func _ready() -> void:
	_initialize_defaults()

func _initialize_defaults() -> void:
	_state = {
		"motion.facing_direction": "down",
		"motion.is_moving": false,
		"motion.is_running": false,
		"motion.is_jumping": false,
		"motion.jump_height": 0.0,
		"motion.is_airborne": false,
		"motion.is_falling": false,
		"motion.is_grounded": true,
		"motion.vertical_state": "grounded",
		"motion.was_running_on_jump": false,
		"motion.blocks_input": false,
		"action.is_aiming": false,
		"action.is_shooting": false,
		"action.demands_walk": false,
		"action.shoot_anim_speed": 15.0,
		"state.animation": "idle",
		"interaction.last_kind": "",
		"interaction.last_target_name": "",
		"interaction.count": 0,
		"core.is_active": false,
	}
	_subscribers = {}

func publish(key: String, value: Variant) -> void:
	var is_new_key := not _state.has(key)
	if is_new_key:
		push_warning("Registry: unknown key '%s'; initializing to null" % key)

	var previous: Variant = _state.get(key)
	_state[key] = value

	# Change-gated: only notify subscribers when the value actually changed.
	# Packages re-publish unchanged state every physics frame; gating here
	# removes that per-frame noise. All registry values are primitives, so
	# '==' is a correct value comparison.
	if not is_new_key and previous == value:
		return

	if _subscribers.has(key):
		for callback in _subscribers[key]:
			callback.call(value)

func query(key: String) -> Variant:
	if not _state.has(key):
		return null
	return _state[key]

func subscribe(key: String, callback: Callable) -> void:
	if not _subscribers.has(key):
		_subscribers[key] = []
	_subscribers[key].append(callback)

func get_snapshot() -> Dictionary:
	return _state.duplicate()
