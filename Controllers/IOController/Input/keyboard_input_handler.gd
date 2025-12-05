extends Node
class_name KeyboardInputHandler

## KeyboardInputHandler - Handles keyboard shortcut input events
##
## Atomized component that processes keyboard shortcuts and
## emits signals for debug/utility functions.
##
## Responsibilities:
## - Detect keyboard shortcuts (R, C, E, etc.)
## - Filter out key echoes (repeat events)
## - Emit signals for other systems to consume
##
## Does NOT:
## - Execute the actual debug/export logic (delegated via signals)
## - Know about navigation or pathfinding systems

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when R key is pressed (request pathfinding report)
signal report_key_pressed()

## Emitted when C key is pressed (request clear history)
signal clear_key_pressed()

## Emitted when E key is pressed (request export data)
signal export_key_pressed()

## Emitted when Space or Enter is pressed (end current agent turn)
signal end_turn_requested()

# ============================================================================
# CONFIGURATION
# ============================================================================

## Enable/disable keyboard shortcuts
var enabled: bool = true

# ============================================================================
# INPUT PROCESSING
# ============================================================================

func _input(event: InputEvent) -> void:
	if not enabled:
		return

	if not event is InputEventKey:
		return

	if not event.pressed:
		return

	# Ignore key echoes (held keys)
	if event.echo:
		return

	# Handle keyboard shortcuts (global, always processed)
	match event.keycode:
		KEY_R:
			report_key_pressed.emit()

		KEY_C:
			clear_key_pressed.emit()

		KEY_E:
			export_key_pressed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return

	if not event is InputEventKey:
		return

	if not event.pressed:
		return

	# Ignore key echoes (held keys)
	if event.echo:
		return

	# Handle context-sensitive shortcuts (only if not handled by SessionController)
	match event.keycode:
		KEY_SPACE, KEY_ENTER:
			print("[KeyboardInputHandler] Space/Enter pressed - requesting end turn")
			end_turn_requested.emit()
			get_viewport().set_input_as_handled()

# ============================================================================
# PUBLIC API
# ============================================================================

func enable() -> void:
	"""Enable keyboard input handling"""
	enabled = true

func disable() -> void:
	"""Disable keyboard input handling"""
	enabled = false
