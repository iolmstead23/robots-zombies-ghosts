class_name OverlayConfig
extends Resource

## Configuration Resource for UI Overlays
## Provides centralized configuration for all overlay visual and behavioral properties

# ============================================================================
# IDENTITY
# ============================================================================

@export var config_name: String = "DefaultOverlay"
@export_multiline var description: String = ""

# ============================================================================
# APPEARANCE
# ============================================================================

@export_group("Appearance")
## Base gradient color (RGB only, opacity controlled separately)
@export var gradient_color: Color = Color(0, 0.2, 0.4)
## Text color for all content labels
@export var text_color: Color = Color(1, 1, 1)
## Border color
@export var border_color: Color = Color(0, 0.6, 1)
## Border width in pixels
@export var border_width: float = 2.0

# ============================================================================
# GRADIENT OPACITY
# ============================================================================

@export_group("Gradient")
## Opacity at the top of the gradient (0.0 = transparent, 1.0 = opaque)
@export_range(0.0, 1.0) var gradient_start_opacity: float = 0.9
## Opacity at the bottom of the gradient (0.0 = transparent, 1.0 = opaque)
@export_range(0.0, 1.0) var gradient_end_opacity: float = 0.0
## Gradient distribution points (0.0 = top, 1.0 = bottom)
## Must have at least 2 points for proper gradient
@export var gradient_offsets: PackedFloat32Array = PackedFloat32Array([0, 0.5, 1])

# ============================================================================
# LAYOUT
# ============================================================================

@export_group("Layout")
## Title for this overlay (required)
@export var overlay_title: String = ""
## Size of the overlay in pixels
@export var overlay_size: Vector2 = Vector2(350, 250)
## Anchor position on screen
@export_enum("Top Left:0", "Top Right:1", "Bottom Left:2", "Bottom Right:3")
var anchor_position: int = 0
## Offset from screen edge
@export var offset_from_edge: Vector2 = Vector2(10, 10)

# ============================================================================
# CONTENT
# ============================================================================

@export_group("Content")
## Maximum number of content lines (excluding title)
@export var max_content_lines: int = 10
## Internal margin for content padding
@export var content_margin: int = 15
## Extra margin below title
@export var title_margin_bottom: int = 8

# ============================================================================
# VALIDATION
# ============================================================================

@export_group("Validation")
## Enable strict validation (errors on overflow)
@export var strict_validation: bool = true
## Automatically truncate content that exceeds limits
@export var auto_truncate: bool = true
## Show "..." indicator when content is truncated
@export var show_overflow_indicator: bool = true

# ============================================================================
# METHODS
# ============================================================================

func apply_to_overlay(overlay: BaseOverlay) -> void:
	"""Apply all configuration properties to an overlay instance"""
	if not overlay:
		push_error("OverlayConfig: Cannot apply to null overlay")
		return

	# Identity
	# (config_name and description are metadata, not applied)

	# Appearance
	overlay.gradient_color = gradient_color
	overlay.text_color = text_color
	overlay.border_color = border_color
	overlay.border_width = border_width

	# Gradient
	overlay.gradient_start_opacity = gradient_start_opacity
	overlay.gradient_end_opacity = gradient_end_opacity
	overlay.gradient_offsets = gradient_offsets.duplicate()

	# Layout
	overlay.overlay_title = overlay_title
	overlay.overlay_size = overlay_size
	overlay.anchor_position = anchor_position
	overlay.offset_from_edge = offset_from_edge

	# Content
	overlay.max_content_lines = max_content_lines
	overlay.content_margin = content_margin
	overlay.title_margin_bottom = title_margin_bottom

	# Validation
	overlay.strict_validation = strict_validation
	overlay.auto_truncate = auto_truncate
	overlay.show_overflow_indicator = show_overflow_indicator

func duplicate_config() -> OverlayConfig:
	"""Create a duplicate of this configuration"""
	var new_config = OverlayConfig.new()

	# Identity
	new_config.config_name = config_name
	new_config.description = description

	# Appearance
	new_config.gradient_color = gradient_color
	new_config.text_color = text_color
	new_config.border_color = border_color
	new_config.border_width = border_width

	# Gradient
	new_config.gradient_start_opacity = gradient_start_opacity
	new_config.gradient_end_opacity = gradient_end_opacity
	new_config.gradient_offsets = gradient_offsets.duplicate()

	# Layout
	new_config.overlay_title = overlay_title
	new_config.overlay_size = overlay_size
	new_config.anchor_position = anchor_position
	new_config.offset_from_edge = offset_from_edge

	# Content
	new_config.max_content_lines = max_content_lines
	new_config.content_margin = content_margin
	new_config.title_margin_bottom = title_margin_bottom

	# Validation
	new_config.strict_validation = strict_validation
	new_config.auto_truncate = auto_truncate
	new_config.show_overflow_indicator = show_overflow_indicator

	return new_config
