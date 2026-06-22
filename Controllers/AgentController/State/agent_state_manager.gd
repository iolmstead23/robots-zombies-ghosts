extends Node
class_name AgentStateManager

## Single authority for resolving the agent's high-level animation state.
##
## Reads owned state from other packages exclusively through the registry — it
## holds NO direct references to Motion, Action, or Navigation. Each frame it
## evaluates an explicit, ordered priority table and publishes the winning state
## to "state.animation". The Animation controller consults that value; it does
## not decide priority itself.
##
## The PRIORITY of states is defined entirely by the ORDER of PRIORITY_RULES
## below — the first rule whose condition matches wins. To change precedence,
## reorder the rules; never bury precedence in imperative code.
##
## Publishes: state.animation
## Reads from registry: motion.is_airborne, motion.was_running_on_jump,
##   motion.is_moving, motion.is_running, action.is_shooting, action.is_aiming

var registry: AgentRegistry

## Ordered highest-priority → lowest. Each rule maps a resolved state name to a
## predicate over a flat snapshot of the registry-published inputs (see
## _read_inputs). Evaluation stops at the first matching rule.
##
## Encodes the spec's precedence rules:
##   1. Airborne (jump/fall) overrides everything    → run_jump, jump
##   2. Combat overrides grounded locomotion          → walk_shoot, standing_shoot, idle_aim
##   3. Locomotion is the grounded default            → run, walk, idle
## Composite cases:
##   - Walk + Shoot/Aim  → walk_shoot (blended; allowed)
##   - Run + Shoot/Aim   → never reached: Action publishes action.demands_walk,
##                         Navigation drops is_running, so the agent is "walk"
##                         here and resolves to walk_shoot (run+shoot suppressed)
##   - Run + Jump        → run_jump   - Walk + Jump → jump
var _priority_rules: Array = []

func _ready() -> void:
	_priority_rules = _build_priority_rules()

func initialize(registry_ref: AgentRegistry) -> void:
	registry = registry_ref
	if _priority_rules.is_empty():
		_priority_rules = _build_priority_rules()

func update() -> void:
	var resolved := resolve_state()
	registry.publish("state.animation", resolved)

## Pure resolution: evaluate the priority table against current registry state.
## Returns the name of the first matching rule. "idle" is the guaranteed fallback.
func resolve_state() -> String:
	var inputs := _read_inputs()
	for rule in _priority_rules:
		if rule.when.call(inputs):
			return rule.state
	return "idle"

## Flat snapshot of every registry input the priority rules consult. Reading
## once per frame keeps each predicate cheap and the rule table declarative.
func _read_inputs() -> Dictionary:
	return {
		"airborne": bool(registry.query("motion.is_airborne")),
		"was_running_on_jump": bool(registry.query("motion.was_running_on_jump")),
		"moving": bool(registry.query("motion.is_moving")),
		"running": bool(registry.query("motion.is_running")),
		"shooting": bool(registry.query("action.is_shooting")),
		"aiming": bool(registry.query("action.is_aiming")),
	}

func _build_priority_rules() -> Array:
	return [
		# 1. Airborne overrides everything (combat fire is gated off mid-jump).
		{"state": "run_jump",       "when": func(s): return s.airborne and s.was_running_on_jump},
		{"state": "jump",           "when": func(s): return s.airborne},
		# 2. Combat overrides grounded locomotion.
		{"state": "walk_shoot",     "when": func(s): return (s.shooting or s.aiming) and s.moving},
		{"state": "standing_shoot", "when": func(s): return s.shooting and not s.moving},
		{"state": "idle_aim",       "when": func(s): return s.aiming and not s.moving},
		# 3. Grounded locomotion default.
		{"state": "run",            "when": func(s): return s.moving and s.running},
		{"state": "walk",           "when": func(s): return s.moving and not s.running},
		{"state": "idle",           "when": func(_s): return true},
	]

## Read-only view of the precedence contract for debugging / auditing.
func get_priority_order() -> Array:
	var order: Array = []
	for rule in _priority_rules:
		order.append(rule.state)
	return order
