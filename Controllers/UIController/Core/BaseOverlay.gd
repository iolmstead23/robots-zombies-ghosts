class_name BaseOverlay
extends CanvasLayer

## Base UI Overlay Component - Shared parent for all UI overlays
## Provides customizable gradient background, border, and positioning

# ============================================================================
# CONFIGURATION - Override these in child classes or set in _ready()
# ============================================================================

@export_group("Style")
## Gradient color (RGB), alpha is set separately
@export var gradient_color: Color = Color(0, 0.2, 0.4)
## Opacity for the main gradient area (0.0 - 1.0)
@export var gradient_alpha: float = 0.9
## Border color
@export var border_color: Color = Color(0, 0.6, 1)
## Border width in pixels
@export var border_width: float = 2.0

@export_group("Position")
## Anchor position: 0=top-left, 1=top-right, 2=bottom-left, 3=bottom-right
@export_enum("Top Left:0", "Top Right:1", "Bottom Left:2", "Bottom Right:3") var anchor_position: int = 0
## Offset from screen edge
@export var offset_from_edge: Vector2 = Vector2(10, 10)
## Overlay size
@export var overlay_size: Vector2 = Vector2(350, 200)

@export_group("Spacing")
## Internal margin for content
@export var content_margin: int = 15

# ============================================================================
# NODES - Set up in scene, accessed by children
# ============================================================================

@onready var control: Control = $Control
@onready var panel: Panel = $Control/Panel
@onready var gradient_bg: TextureRect = $Control/Panel/GradientBackground
@onready var border: ReferenceRect = $Control/Panel/Border
@onready var margin_container: MarginContainer = $Control/Panel/MarginContainer
@onready var content_container: VBoxContainer = $Control/Panel/MarginContainer/VBoxContainer

# Gradient resources (created dynamically)
var gradient: Gradient
var gradient_texture: GradientTexture2D

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	_apply_configuration()

# ============================================================================
# CONFIGURATION
# ============================================================================

func _apply_configuration():
	"""Apply the exported configuration to the overlay"""
	_setup_gradient()
	_setup_border()
	_setup_position()
	_setup_margins()

func _setup_gradient():
	"""Create and apply gradient with configured colors"""
	# Create gradient
	gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.5, 1])

	# Set colors with alpha fade at bottom
	var color_top = Color(gradient_color.r, gradient_color.g, gradient_color.b, gradient_alpha)
	var color_bottom = Color(gradient_color.r, gradient_color.g, gradient_color.b, 0)
	gradient.colors = PackedColorArray([color_top, color_top, color_bottom])

	# Create gradient texture
	gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill = GradientTexture2D.FILL_LINEAR
	gradient_texture.fill_from = Vector2(0.5, 0)
	gradient_texture.fill_to = Vector2(0.5, 1)

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
			control.offset_left = -(offset_from_edge.x + overlay_size.x)
			control.offset_top = offset_from_edge.y
			control.offset_right = -offset_from_edge.x
			control.offset_bottom = offset_from_edge.y + overlay_size.y
			control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			control.grow_vertical = Control.GROW_DIRECTION_END

		2: # Bottom Left
			control.anchor_left = 0.0
			control.anchor_top = 1.0
			control.anchor_right = 0.0
			control.anchor_bottom = 1.0
			control.offset_left = offset_from_edge.x
			control.offset_top = -(offset_from_edge.y + overlay_size.y)
			control.offset_right = offset_from_edge.x + overlay_size.x
			control.offset_bottom = -offset_from_edge.y
			control.grow_horizontal = Control.GROW_DIRECTION_END
			control.grow_vertical = Control.GROW_DIRECTION_BEGIN

		3: # Bottom Right
			control.anchor_left = 1.0
			control.anchor_top = 1.0
			control.anchor_right = 1.0
			control.anchor_bottom = 1.0
			control.offset_left = -(offset_from_edge.x + overlay_size.x)
			control.offset_top = -(offset_from_edge.y + overlay_size.y)
			control.offset_right = -offset_from_edge.x
			control.offset_bottom = -offset_from_edge.y
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

func update_style(new_gradient_color: Color = gradient_color, new_border_color: Color = border_color, new_alpha: float = gradient_alpha):
	"""Update the overlay style at runtime"""
	gradient_color = new_gradient_color
	border_color = new_border_color
	gradient_alpha = new_alpha
	_setup_gradient()
	_setup_border()
