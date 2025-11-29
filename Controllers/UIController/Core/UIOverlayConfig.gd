class_name UIOverlayConfig
extends RefCounted

## UI Overlay Configuration - Centralized styling for all overlays
## Manages size, colors, gradients, and positioning for consistent UI appearance

# ============================================================================
# STYLE PROPERTIES
# ============================================================================

## Overlay dimensions
var size: Vector2 = Vector2(350, 200)

## Position anchor (0=top-left, 1=top-right, 2=bottom-left, 3=bottom-right)
var anchor_position: int = 0

## Offset from screen edge
var offset_from_edge: Vector2 = Vector2(10, 10)

## Gradient base color (RGB only, alpha set separately)
var gradient_color: Color = Color(0, 0.2, 0.4)

## Gradient opacity (0.0 - 1.0)
var gradient_alpha: float = 0.9

## Border color
var border_color: Color = Color(0, 0.6, 1)

## Border width in pixels
var border_width: float = 2.0

## Internal content margin
var content_margin: int = 15

## Gradient style (shared across all overlays)
var gradient_style: int = 0  # 0 = vertical fade, 1 = radial, 2 = solid

# ============================================================================
# PRESETS
# ============================================================================

## Create config for debug overlay (top-right, dark blue)
static func create_debug_config() -> UIOverlayConfig:
	var config = UIOverlayConfig.new()
	config.size = Vector2(350, 200)
	config.anchor_position = 1  # Top Right
	config.offset_from_edge = Vector2(10, 10)
	config.gradient_color = Color(0, 0.1, 0.2)  # Dark blue
	config.gradient_alpha = 0.88
	config.border_color = Color(0, 0.4, 0.7)  # Medium blue
	config.border_width = 2.0
	config.content_margin = 10
	return config

## Create config for selection overlay (top-left, lighter blue)
static func create_selection_config() -> UIOverlayConfig:
	var config = UIOverlayConfig.new()
	config.size = Vector2(350, 200)  # Same size as debug
	config.anchor_position = 0  # Top Left
	config.offset_from_edge = Vector2(10, 10)
	config.gradient_color = Color(0, 0.2, 0.4)  # Lighter blue
	config.gradient_alpha = 0.9
	config.border_color = Color(0, 0.6, 1)  # Bright blue
	config.border_width = 2.0
	config.content_margin = 10
	return config

# ============================================================================
# UTILITY METHODS
# ============================================================================

## Apply this config to a BaseOverlay instance
func apply_to_overlay(overlay: Node) -> void:
	"""Apply configuration to a BaseOverlay before its _ready() is called"""
	if not overlay:
		push_error("UIOverlayConfig: Cannot apply to null overlay")
		return

	# Set all overlay properties
	overlay.set("gradient_color", gradient_color)
	overlay.set("gradient_alpha", gradient_alpha)
	overlay.set("border_color", border_color)
	overlay.set("border_width", border_width)
	overlay.set("anchor_position", anchor_position)
	overlay.set("offset_from_edge", offset_from_edge)
	overlay.set("overlay_size", size)
	overlay.set("content_margin", content_margin)

## Create a duplicate of this config
func duplicate_config() -> UIOverlayConfig:
	var new_config = UIOverlayConfig.new()
	new_config.size = size
	new_config.anchor_position = anchor_position
	new_config.offset_from_edge = offset_from_edge
	new_config.gradient_color = gradient_color
	new_config.gradient_alpha = gradient_alpha
	new_config.border_color = border_color
	new_config.border_width = border_width
	new_config.content_margin = content_margin
	new_config.gradient_style = gradient_style
	return new_config

## Get a summary string of this config
func get_config_summary() -> String:
	return "UIOverlayConfig(size=%s, anchor=%d, color=%s)" % [size, anchor_position, gradient_color]
