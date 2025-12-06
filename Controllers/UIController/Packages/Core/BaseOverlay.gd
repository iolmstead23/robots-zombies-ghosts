class_name BaseOverlay
extends CanvasLayer

## Base UI Overlay Component - Shared parent for all UI overlays
## Provides customizable gradient background, border, positioning with package-based architecture

# ============================================================================
# PACKAGE IMPORTS
# Note: These classes are globally available via class_name declarations
# ============================================================================

# GradientRenderer, TitleValidator, and ContentValidator are available globally

# ============================================================================
# CONFIGURATION - Override these in child classes or set via OverlayConfig
# ============================================================================

@export_group("Title")
## Title for this overlay (required)
@export var overlay_title: String = ""
## Extra margin below title
@export var title_margin_bottom: int = 8

@export_group("Style")
## Gradient color (RGB), opacity controlled separately
@export var gradient_color: Color = Color(0, 0.2, 0.4)
## Text color for content labels
@export var text_color: Color = Color(1, 1, 1)
## Border color
@export var border_color: Color = Color(0, 0.6, 1)
## Border width in pixels
@export var border_width: float = 2.0

@export_group("Gradient")
## Opacity at the top of the gradient (0.0 to 1.0)
@export_range(0.0, 1.0) var gradient_start_opacity: float = 0.9
## Opacity at the bottom of the gradient (0.0 to 1.0)
@export_range(0.0, 1.0) var gradient_end_opacity: float = 0.0
## Gradient distribution points (0.0 = top, 1.0 = bottom)
@export var gradient_offsets: PackedFloat32Array = PackedFloat32Array([0, 0.5, 1])

@export_group("Position")
## Anchor position: 0=top-left, 1=top-right, 2=bottom-left, 3=bottom-right
@export_enum("Top Left:0", "Top Right:1", "Bottom Left:2", "Bottom Right:3") var anchor_position: int = 0
## Offset from screen edge
@export var offset_from_edge: Vector2 = Vector2(10, 10)
## Overlay size
@export var overlay_size: Vector2 = Vector2(350, 250)

@export_group("Content")
## Maximum number of content lines (excluding title)
@export var max_content_lines: int = 10
## Internal margin for content
@export var content_margin: int = 15

@export_group("Validation")
## Enable strict validation (errors on overflow)
@export var strict_validation: bool = true
## Automatically truncate content that exceeds limits
@export var auto_truncate: bool = true
## Show "..." indicator when content is truncated
@export var show_overflow_indicator: bool = true

# ============================================================================
# NODES - Set up in scene, accessed by children
# ============================================================================

@onready var control: Control = $Control
@onready var panel: Panel = $Control/Panel
@onready var gradient_bg: TextureRect = $Control/Panel/GradientBackground
@onready var border: ReferenceRect = $Control/Panel/Border
@onready var title_container: MarginContainer = $Control/Panel/TitleContainer
@onready var title_label: Label = $Control/Panel/TitleContainer/TitleLabel
@onready var title_separator: HSeparator = $Control/Panel/TitleSeparator
@onready var margin_container: MarginContainer = $Control/Panel/MarginContainer
@onready var content_container: VBoxContainer = $Control/Panel/MarginContainer/VBoxContainer

# Gradient resources (created dynamically)
var gradient_texture: GradientTexture2D

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	# Validate title requirement
	_validate_title()

	# Apply configuration
	_apply_configuration()

	## Audit requirement: Explicitly connect to SessionController's "turn_changed" signal.
	## This ensures overlays can robustly respond to turn changes if needed, and is auditable for session-awareness.
	var session_controller = get_tree().get_root().find_child("SessionController", true, false)
	if session_controller and not session_controller.is_connected("turn_changed", Callable(self, "_on_turn_changed")):
		session_controller.connect("turn_changed", Callable(self, "_on_turn_changed"))

# ============================================================================
# CONFIGURATION
# ============================================================================

func _apply_configuration():
	"""Apply the exported configuration to the overlay"""
	_setup_title()
	_setup_gradient()
	_setup_border()
	_setup_position()
	_setup_margins()

func _validate_title():
	"""Validate title requirement using TitleValidator"""
	var validation = TitleValidator.validate_title(overlay_title)
	if not validation.valid:
		for error in validation.errors:
			push_error("BaseOverlay: %s" % error)
		# Sanitize title if invalid
		overlay_title = TitleValidator.sanitize_title(overlay_title)
		push_warning("BaseOverlay: Title sanitized to '%s'" % overlay_title)

func _setup_title():
	"""Setup title label and separator"""
	if title_label:
		title_label.text = overlay_title
		title_label.add_theme_color_override("font_color", text_color)

	# Configure title container margins
	if title_container:
		title_container.add_theme_constant_override("margin_left", content_margin)
		title_container.add_theme_constant_override("margin_top", content_margin)
		title_container.add_theme_constant_override("margin_right", content_margin)
		title_container.add_theme_constant_override("margin_bottom", title_margin_bottom)

func _setup_gradient():
	"""Create and apply gradient using GradientRenderer package"""
	gradient_texture = GradientRenderer.create_gradient(
		gradient_color,
		gradient_start_opacity,
		gradient_end_opacity,
		gradient_offsets
	)

	# Apply to background
	if gradient_bg:
		gradient_bg.texture = gradient_texture

func _setup_border():
	"""Apply border configuration"""
	if border:
		border.border_color = border_color
		border.border_width = border_width

func _setup_position():
	"""Position the overlay based on anchor_position"""
	if not control:
		return

	match anchor_position:
		0: # Top Left
			control.anchor_left = 0.0
			control.anchor_top = 0.0
			control.anchor_right = 0.0
			control.anchor_bottom = 0.0
			control.offset_left = offset_from_edge.x
			control.offset_top = offset_from_edge.y
			control.offset_right = offset_from_edge.x + overlay_size.x
			control.offset_bottom = offset_from_edge.y + overlay_size.y
			control.grow_horizontal = Control.GROW_DIRECTION_END
			control.grow_vertical = Control.GROW_DIRECTION_END

		1: # Top Right
			control.anchor_left = 1.0
			control.anchor_top = 0.0
			control.anchor_right = 1.0
			control.anchor_bottom = 0.0
			control.offset_left = - (offset_from_edge.x + overlay_size.x)
			control.offset_top = offset_from_edge.y
			control.offset_right = - offset_from_edge.x
			control.offset_bottom = offset_from_edge.y + overlay_size.y
			control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			control.grow_vertical = Control.GROW_DIRECTION_END

		2: # Bottom Left
			control.anchor_left = 0.0
			control.anchor_top = 1.0
			control.anchor_right = 0.0
			control.anchor_bottom = 1.0
			control.offset_left = offset_from_edge.x
			control.offset_top = - (offset_from_edge.y + overlay_size.y)
			control.offset_right = offset_from_edge.x + overlay_size.x
			control.offset_bottom = - offset_from_edge.y
			control.grow_horizontal = Control.GROW_DIRECTION_END
			control.grow_vertical = Control.GROW_DIRECTION_BEGIN

		3: # Bottom Right
			control.anchor_left = 1.0
			control.anchor_top = 1.0
			control.anchor_right = 1.0
			control.anchor_bottom = 1.0
			control.offset_left = - (offset_from_edge.x + overlay_size.x)
			control.offset_top = - (offset_from_edge.y + overlay_size.y)
			control.offset_right = - offset_from_edge.x
			control.offset_bottom = - offset_from_edge.y
			control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			control.grow_vertical = Control.GROW_DIRECTION_BEGIN

func _setup_margins():
	"""Apply margin configuration"""
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", content_margin)
		margin_container.add_theme_constant_override("margin_top", content_margin)
		margin_container.add_theme_constant_override("margin_right", content_margin)
		margin_container.add_theme_constant_override("margin_bottom", content_margin)

# ============================================================================
# PUBLIC API - For child classes to override or use
# ============================================================================

func get_content_container() -> VBoxContainer:
	"""Get the container where child classes should add their content"""
	return content_container

func load_config(config: Resource) -> void:
	"""Load configuration from OverlayConfig resource"""
	if not config:
		push_error("BaseOverlay: Cannot load null config")
		return

	# Apply config using its apply_to_overlay method
	if config.has_method("apply_to_overlay"):
		config.apply_to_overlay(self)
		# Reapply configuration after loading
		if is_inside_tree():
			_apply_configuration()
	else:
		push_error("BaseOverlay: Config does not have apply_to_overlay method")

func get_available_content_lines() -> int:
	"""Get number of lines available for content (excluding title)"""
	return max_content_lines

func update_style(
	new_gradient_color: Color = gradient_color,
	new_border_color: Color = border_color,
	new_start_opacity: float = gradient_start_opacity,
	new_end_opacity: float = gradient_end_opacity
):
	"""Update the overlay style at runtime"""
	gradient_color = new_gradient_color
	border_color = new_border_color
	gradient_start_opacity = new_start_opacity
	gradient_end_opacity = new_end_opacity
	_setup_gradient()
	_setup_border()

# =============================================================================
# TURN HANDLING (AUDIT STUB)
# =============================================================================

## Handler for SessionController's "turn_changed" signal.
##
## Stub provided for audit and robustness—child classes should override to implement turn-specific behavior.
## Ensures overlays can safely and explicitly react to turn changes.
func _on_turn_changed(_turn_info: Dictionary):
	pass
