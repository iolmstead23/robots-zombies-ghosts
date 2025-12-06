extends Node
class_name KeyboardInputHandler

## KeyboardInputHandler - Handles keyboard shortcut input events
##
## Atomized component that processes keyboard shortcuts and
## emits signals for gameplay functions.
##
## Responsibilities:
## - Detect keyboard shortcuts (Space/Enter for end turn)
## - Filter out key echoes (repeat events)
## - Emit signals for other systems to consume
##
## Does NOT:
## - Execute the actual game logic (delegated via signals)
## - Know about navigation or pathfinding systems

# ============================================================================
# SIGNALS
# ============================================================================

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
