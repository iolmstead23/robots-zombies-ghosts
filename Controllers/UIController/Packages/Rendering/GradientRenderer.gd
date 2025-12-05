class_name GradientRenderer
extends RefCounted

## Gradient Rendering Package
## Provides static methods for creating and updating vertical gradients with configurable opacity

# ============================================================================
# GRADIENT CREATION
# ============================================================================

static func create_gradient(
	color: Color,
	start_opacity: float,
	end_opacity: float,
	offsets: PackedFloat32Array
) -> GradientTexture2D:
	"""
	Create a vertical gradient texture with configurable opacity endpoints.

	Args:
		color: Base RGB color for the gradient
		start_opacity: Opacity at the top (0.0 to 1.0)
		end_opacity: Opacity at the bottom (0.0 to 1.0)
		offsets: Array of gradient points (0.0 = top, 1.0 = bottom)

	Returns:
		GradientTexture2D configured with vertical fill
	"""
	# Validate offsets
	if offsets.size() < 2:
		push_error("GradientRenderer: offsets must have at least 2 points")
		offsets = PackedFloat32Array([0, 1])

	# Create gradient
	var gradient = Gradient.new()
	gradient.offsets = offsets

	# Build color array based on offsets
	# Each offset point gets a color with interpolated opacity
	var colors: Array[Color] = []
	for i in range(offsets.size()):
		var t = offsets[i]  # Position from 0.0 (top) to 1.0 (bottom)
		var opacity = lerp(start_opacity, end_opacity, t)
		colors.append(Color(color.r, color.g, color.b, opacity))

	gradient.colors = PackedColorArray(colors)

	# Create texture with vertical fill
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0)   # Top center
	texture.fill_to = Vector2(0.5, 1)     # Bottom center
	texture.width = 256
	texture.height = 256

	return texture

# ============================================================================
# GRADIENT UPDATING
# ============================================================================

static func update_gradient(
	texture: GradientTexture2D,
	color: Color,
	start_opacity: float,
	end_opacity: float,
	offsets: PackedFloat32Array
) -> void:
	"""
	Update an existing gradient texture with new parameters.

	Args:
		texture: Existing GradientTexture2D to update
		color: New base RGB color
		start_opacity: New top opacity (0.0 to 1.0)
		end_opacity: New bottom opacity (0.0 to 1.0)
		offsets: New gradient points
	"""
	if not texture or not texture.gradient:
		push_error("GradientRenderer: Cannot update null or invalid texture")
		return

	# Validate offsets
	if offsets.size() < 2:
		push_error("GradientRenderer: offsets must have at least 2 points")
		return

	var gradient = texture.gradient
	gradient.offsets = offsets

	# Build new color array
	var colors: Array[Color] = []
	for i in range(offsets.size()):
		var t = offsets[i]
		var opacity = lerp(start_opacity, end_opacity, t)
		colors.append(Color(color.r, color.g, color.b, opacity))

	gradient.colors = PackedColorArray(colors)

# ============================================================================
# GRADIENT PRESETS
# ============================================================================

static func create_linear_gradient(
	color: Color,
	start_opacity: float,
	end_opacity: float
) -> GradientTexture2D:
	"""Create a simple 2-point linear gradient"""
	return create_gradient(
		color,
		start_opacity,
		end_opacity,
		PackedFloat32Array([0, 1])
	)

static func create_ease_out_gradient(
	color: Color,
	start_opacity: float,
	end_opacity: float
) -> GradientTexture2D:
	"""Create a gradient with slower fade at the bottom"""
	return create_gradient(
		color,
		start_opacity,
		end_opacity,
		PackedFloat32Array([0, 0.3, 0.7, 1])
	)

static func create_ease_in_gradient(
	color: Color,
	start_opacity: float,
	end_opacity: float
) -> GradientTexture2D:
	"""Create a gradient with faster fade at the bottom"""
	return create_gradient(
		color,
		start_opacity,
		end_opacity,
		PackedFloat32Array([0, 0.6, 0.9, 1])
	)

# ============================================================================
# UTILITY
# ============================================================================

static func validate_offsets(offsets: PackedFloat32Array) -> bool:
	"""Validate that gradient offsets are properly formatted"""
	if offsets.size() < 2:
		return false

	# Check that offsets are in ascending order
	for i in range(offsets.size() - 1):
		if offsets[i] >= offsets[i + 1]:
			push_warning("GradientRenderer: offsets should be in ascending order")
			return false

	# Check that values are within 0.0 to 1.0 range
	for offset in offsets:
		if offset < 0.0 or offset > 1.0:
			push_warning("GradientRenderer: offset values should be between 0.0 and 1.0")
			return false

	return true
