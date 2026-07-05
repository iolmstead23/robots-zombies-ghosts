extends Node
class_name AgentInteractionPackage

## Owns the interaction.* registry namespace and the agent's public interaction
## entry point. This is scaffolding for future external object interactions — it
## performs NO auto-detection (no Area2D, no proximity scanning). External systems
## call interact_with() when they decide an interaction has occurred.
##
## Publishes: interaction.last_kind, interaction.last_target_name, interaction.count
##
## Registry values are kept primitive (strings + int) so get_snapshot() stays
## cleanly serializable for a turn-deciding AI. The live object reference travels
## only through the `interacted` signal; it is never stored in registry state.

signal interacted(object: Node, kind: String)

var registry: AgentRegistry

func initialize(registry_ref: AgentRegistry) -> void:
	registry = registry_ref

## Record an interaction with an object and announce it. `kind` is a free-form
## tag the game assigns (e.g. "pickup", "door", "damage"); `object` may be null.
func interact_with(object: Node, kind: String) -> void:
	var target_name: String = String(object.name) if is_instance_valid(object) else ""
	registry.publish("interaction.last_kind", kind)
	registry.publish("interaction.last_target_name", target_name)
	registry.publish("interaction.count", int(registry.query("interaction.count")) + 1)
	interacted.emit(object, kind)
