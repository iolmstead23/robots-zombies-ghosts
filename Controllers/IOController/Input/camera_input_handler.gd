extends Node
class_name CameraInputHandler

## CameraInputHandler - Handles camera control input events
##
## Atomized component that processes mouse wheel input for camera zoom.
##
## Responsibilities:
## - Detect mouse wheel scroll events
## - Emit signals for zoom requests
##
## Does NOT:
## - Directly modify the camera (delegated via signals)
## - Know about zoom levels or camera constraints

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when mouse wheel scrolls up (zoom in)
signal zoom_in_requested()

## Emitted when mouse wheel scrolls down (zoom out)
signal zoom_out_requested()

# ============================================================================
# CONFIGURATION
# ============================================================================

## Enable/disable camera input
var enabled: bool = true

# ============================================================================
# INPUT PROCESSING
# ============================================================================

func _input(event: InputEvent) -> void:
	if not enabled:
		return

	if not event is InputEventMouseButton:
		return

	if not event.pressed:
		return

	# Handle mouse wheel zoom
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			zoom_in_requested.emit()

		MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out_requested.emit()

# ============================================================================
# PUBLIC API
# ============================================================================

func enable() -> void:
	"""Enable camera input handling"""
	enabled = true

func disable() -> void:
	"""Disable camera input handling"""
	enabled = false