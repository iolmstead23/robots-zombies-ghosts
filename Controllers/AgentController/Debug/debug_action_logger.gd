extends Node
class_name DebugActionLogger

## Action history logger for debugging state transitions and input events.

const MAX_HISTORY := 50

var action_history: Array[Dictionary] = []
var last_printed_index := 0

func log_action(action: String, details: Dictionary = {}) -> void:
	if not OS.is_debug_build():
		return

	var timestamp := Time.get_ticks_msec() / 1000.0
	var entry: Dictionary = {
		"timestamp": timestamp,
		"action": action,
		"details": details
	}

	action_history.append(entry)
	if action_history.size() > MAX_HISTORY:
		action_history.pop_front()

func log_state_change(key: String, old_value: Variant, new_value: Variant) -> void:
	if not OS.is_debug_build():
		return

	log_action("STATE_CHANGE", {
		"key": key,
		"old": old_value,
		"new": new_value
	})

func log_animation_change(old_anim: String, new_anim: String, anim_type: String) -> void:
	if not OS.is_debug_build():
		return

	log_action("ANIMATION_CHANGE", {
		"from": old_anim,
		"to": new_anim,
		"type": anim_type
	})

func log_navigation_event(event: String, details: Dictionary = {}) -> void:
	if not OS.is_debug_build():
		return

	log_action("NAVIGATION", {
		"event": event
	}.merged(details))

func log_combat_event(event: String, details: Dictionary = {}) -> void:
	if not OS.is_debug_build():
		return

	log_action("COMBAT", {
		"event": event
	}.merged(details))

func print_history() -> void:
	if not OS.is_debug_build():
		return

	print("\n=== Action History ===")
	for i in range(action_history.size()):
		var entry = action_history[i]
		var prefix = "  "
		if i >= last_printed_index:
			prefix = "→ "

		var detail_str = ""
		if entry.details.size() > 0:
			var parts = []
			for key in entry.details.keys():
				parts.append("%s=%s" % [key, entry.details[key]])
			detail_str = " [%s]" % ", ".join(parts)

		print("%s%.2fs | %s%s" % [prefix, entry.timestamp, entry.action, detail_str])

	last_printed_index = action_history.size()
	print("======================\n")
