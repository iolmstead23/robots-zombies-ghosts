class_name OverlayPresets
extends RefCounted

## Overlay Configuration Presets Factory
## Provides pre-configured OverlayConfig instances for common overlay types

# ============================================================================
# PRESET FACTORY
# ============================================================================

static func get_preset(preset_name: String) -> OverlayConfig:
	"""
	Get a predefined overlay configuration by name.

	Args:
		preset_name: Name of the preset ("selection", "debug", or "default")

	Returns:
		OverlayConfig instance with preset values
	"""
	match preset_name:
		"selection":
			return create_selection_preset()
		"debug":
			return create_debug_preset()
		_:
			return create_default_preset()

# ============================================================================
# PRESET DEFINITIONS
# ============================================================================

static func create_selection_preset() -> OverlayConfig:
	"""
	Create configuration for the selection overlay (left side).
	Shows turn info, agent status, and selected object details.
	"""
	var config = OverlayConfig.new()

	# Identity
	config.config_name = "Selection Overlay"
	config.description = "Displays turn information, agent status, and selected object details"

	# Title
	config.overlay_title = "Selection"

	# Appearance - Lighter blue theme
	config.gradient_color = Color(0, 0.2, 0.4)  # Light blue
	config.text_color = Color(1, 1, 1)          # White text
	config.border_color = Color(0, 0.6, 1)      # Bright blue border
	config.border_width = 2.0

	# Gradient - Full fade to transparent
	config.gradient_start_opacity = 0.95
	config.gradient_end_opacity = 0.0
	config.gradient_offsets = PackedFloat32Array([0, 0.5, 1])

	# Layout - Top Left
	config.anchor_position = 0  # Top Left
	config.offset_from_edge = Vector2(10, 10)
	config.overlay_size = Vector2(350, 250)

	# Content
	config.max_content_lines = 12
	config.content_margin = 15
	config.title_margin_bottom = 8

	# Validation - Strict for game UI
	config.strict_validation = true
	config.auto_truncate = true
	config.show_overflow_indicator = true

	return config

static func create_debug_preset() -> OverlayConfig:
	"""
	Create configuration for the debug overlay (right side).
	Shows FPS, grid info, and hovered cell details.
	"""
	var config = OverlayConfig.new()

	# Identity
	config.config_name = "Debug Overlay"
	config.description = "Displays debug information including FPS, grid stats, and cell details"

	# Title
	config.overlay_title = "DEBUG INFO"

	# Appearance - Darker blue theme
	config.gradient_color = Color(0, 0.1, 0.2)  # Dark blue
	config.text_color = Color(0.9, 0.9, 0.9)    # Light gray text
	config.border_color = Color(0, 0.4, 0.7)    # Muted blue border
	config.border_width = 2.0

	# Gradient - Partial fade for better readability
	config.gradient_start_opacity = 0.92
	config.gradient_end_opacity = 0.2  # Not fully transparent
	config.gradient_offsets = PackedFloat32Array([0, 0.4, 1])

	# Layout - Top Right
	config.anchor_position = 1  # Top Right
	config.offset_from_edge = Vector2(10, 10)
	config.overlay_size = Vector2(350, 280)

	# Content
	config.max_content_lines = 15
	config.content_margin = 15
	config.title_margin_bottom = 8

	# Validation - Allow overflow in debug (warnings only)
	config.strict_validation = false
	config.auto_truncate = true
	config.show_overflow_indicator = true

	return config

static func create_default_preset() -> OverlayConfig:
	"""
	Create default configuration with standard values.
	Used as fallback or starting point for custom overlays.
	"""
	var config = OverlayConfig.new()

	# Identity
	config.config_name = "Default Overlay"
	config.description = "Default overlay configuration"

	# Title
	config.overlay_title = "Overlay"

	# Appearance - Neutral theme
	config.gradient_color = Color(0.1, 0.1, 0.2)
	config.text_color = Color(1, 1, 1)
	config.border_color = Color(0.5, 0.5, 0.7)
	config.border_width = 2.0

	# Gradient - Standard fade
	config.gradient_start_opacity = 0.9
	config.gradient_end_opacity = 0.0
	config.gradient_offsets = PackedFloat32Array([0, 0.5, 1])

	# Layout - Top Left (default)
	config.anchor_position = 0
	config.offset_from_edge = Vector2(10, 10)
	config.overlay_size = Vector2(350, 200)

	# Content
	config.max_content_lines = 10
	config.content_margin = 15
	config.title_margin_bottom = 8

	# Validation
	config.strict_validation = true
	config.auto_truncate = true
	config.show_overflow_indicator = true

	return config

# ============================================================================
# PRESET VARIANTS
# ============================================================================

static func create_info_overlay_preset() -> OverlayConfig:
	"""
	Create configuration for a general information overlay.
	Can be used for tooltips, help text, etc.
	"""
	var config = create_default_preset()

	# Customize for info display
	config.config_name = "Info Overlay"
	config.overlay_title = "Information"
	config.gradient_color = Color(0.2, 0.3, 0.1)  # Green tint
	config.gradient_start_opacity = 0.85
	config.overlay_size = Vector2(300, 150)
	config.max_content_lines = 8

	return config

static func create_warning_overlay_preset() -> OverlayConfig:
	"""
	Create configuration for a warning/alert overlay.
	"""
	var config = create_default_preset()

	# Customize for warnings
	config.config_name = "Warning Overlay"
	config.overlay_title = "WARNING"
	config.gradient_color = Color(0.4, 0.2, 0.0)  # Orange tint
	config.border_color = Color(1.0, 0.5, 0.0)    # Orange border
	config.gradient_start_opacity = 0.95
	config.overlay_size = Vector2(400, 200)

	return config

# ============================================================================
# UTILITY
# ============================================================================

static func list_available_presets() -> Array[String]:
	"""Get list of all available preset names"""
	return ["selection", "debug", "default", "info", "warning"]

static func save_preset_as_resource(preset_name: String, save_path: String) -> Error:
	"""
	Save a preset configuration as a .tres resource file.

	Args:
		preset_name: Name of the preset to save
		save_path: File path to save the resource (e.g., "res://config/my_preset.tres")

	Returns:
		Error code (OK if successful)
	"""
	var config = get_preset(preset_name)
	if not config:
		push_error("OverlayPresets: Unknown preset '%s'" % preset_name)
		return ERR_DOES_NOT_EXIST

	return ResourceSaver.save(config, save_path)
