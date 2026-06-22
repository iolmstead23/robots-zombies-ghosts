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
		"motion.was_running_on_jump": false,
		"motion.blocks_input": false,
		"action.is_aiming": false,
		"action.is_shooting": false,
		"action.demands_walk": false,
		"action.shoot_anim_speed": 15.0,
		"state.animation": "idle",
		"core.is_active": false,
	}
	_subscribers = {}

func publish(key: String, value: Variant) -> void:
	if not _state.has(key):
		push_warning("Registry: unknown key '%s'; initializing to null" % key)
		_state[key] = null

	_state[key] = value

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
