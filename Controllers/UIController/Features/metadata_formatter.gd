class_name MetadataFormatter
extends RefCounted

## Atomized Feature: Metadata Formatting
## Formats various data types for display in UI overlays
## Pure utility component - no state, just formatting logic

# ============================================================================
# FORMATTING OPTIONS
# ============================================================================

enum VectorFormat {
	ROUNDED, # (123, 456)
	PRECISE, # (123.45, 456.78)
	SCIENTIFIC # (1.2e2, 4.6e2)
}

enum BoolFormat {
	YES_NO, # Yes/No
	TRUE_FALSE, # True/False
	ON_OFF, # On/Off
	ENABLED_DISABLED # Enabled/Disabled
}

var vector_format: VectorFormat = VectorFormat.ROUNDED
var bool_format: BoolFormat = BoolFormat.YES_NO
var max_string_length: int = 50
var use_color_codes: bool = false

# ============================================================================
# PUBLIC API - Format Single Values
# ============================================================================

func format_value(value: Variant) -> String:
	"""Format a single value based on its type"""
	if value is Vector2:
		return format_vector2(value)
	elif value is Vector3:
		return format_vector3(value)
	elif value is bool:
		return format_bool(value)
	elif value is float:
		return format_float(value)
	elif value is int:
		return format_int(value)
	elif value is String:
		return format_string(value)
	elif value is Color:
		return format_color(value)
	else:
		return str(value)

func format_vector2(vec: Vector2) -> String:
	"""Format a Vector2"""
	match vector_format:
		VectorFormat.ROUNDED:
			return "(%.0f, %.0f)" % [vec.x, vec.y]
		VectorFormat.PRECISE:
			return "(%.2f, %.2f)" % [vec.x, vec.y]
		VectorFormat.SCIENTIFIC:
			return "(%.2e, %.2e)" % [vec.x, vec.y]
		_:
			return str(vec)

func format_vector3(vec: Vector3) -> String:
	"""Format a Vector3"""
	match vector_format:
		VectorFormat.ROUNDED:
			return "(%.0f, %.0f, %.0f)" % [vec.x, vec.y, vec.z]
		VectorFormat.PRECISE:
			return "(%.2f, %.2f, %.2f)" % [vec.x, vec.y, vec.z]
		VectorFormat.SCIENTIFIC:
			return "(%.2e, %.2e, %.2e)" % [vec.x, vec.y, vec.z]
		_:
			return str(vec)

func format_bool(value: bool) -> String:
	"""Format a boolean value"""
	match bool_format:
		BoolFormat.YES_NO:
			return "Yes" if value else "No"
		BoolFormat.TRUE_FALSE:
			return "True" if value else "False"
		BoolFormat.ON_OFF:
			return "On" if value else "Off"
		BoolFormat.ENABLED_DISABLED:
			return "Enabled" if value else "Disabled"
		_:
			return str(value)

func format_float(value: float) -> String:
	"""Format a float value"""
	# Round to 2 decimal places if it has decimals
	if abs(value - round(value)) < 0.001:
		return "%.0f" % value
	else:
		return "%.2f" % value

func format_int(value: int) -> String:
	"""Format an integer value"""
	# Add thousand separators for large numbers
	if abs(value) >= 1000:
		return "%,d" % value
	return str(value)

func format_string(value: String) -> String:
	"""Format a string (truncate if too long)"""
	if max_string_length > 0 and value.length() > max_string_length:
		return value.substr(0, max_string_length - 3) + "..."
	return value

func format_color(color: Color) -> String:
	"""Format a Color"""
	return "rgba(%.0f, %.0f, %.0f, %.2f)" % [color.r * 255, color.g * 255, color.b * 255, color.a]

# ============================================================================
# PUBLIC API - Format Metadata Dictionary
# ============================================================================

func format_metadata_dict(metadata: Dictionary, include_header: bool = true) -> String:
	"""Format an entire metadata dictionary as a multi-line string"""
	var lines: Array[String] = []

	if include_header:
		lines.append("--- Properties ---")

	for key in metadata:
		var value = metadata[key]
		var formatted_value = format_value(value)
		lines.append("%s: %s" % [key, formatted_value])

	return "\n".join(lines)

func format_metadata_as_pairs(metadata: Dictionary) -> Array[Dictionary]:
	"""Format metadata as an array of {key, value, formatted_value} dictionaries"""
	var pairs: Array[Dictionary] = []

	for key in metadata:
		var value = metadata[key]
		pairs.append({
			"key": key,
			"value": value,
			"formatted": format_value(value)
		})

	return pairs

func format_key_value(key: String, value: Variant) -> String:
	"""Format a single key-value pair"""
	return "%s: %s" % [key, format_value(value)]

# ============================================================================
# PUBLIC API - Debug/Info Formatting
# ============================================================================

func format_debug_info(debug_data: Dictionary, header: String = "=== DEBUG INFO ===") -> String:
	"""Format debug information with a header"""
	var lines: Array[String] = []

	if not header.is_empty():
		lines.append(header)

	for key in debug_data:
		var value = debug_data[key]
		if value != null:
			lines.append("%s: %s" % [key, format_value(value)])

	return "\n".join(lines)

# ============================================================================
# UTILITY METHODS
# ============================================================================

func set_vector_format(format: VectorFormat) -> void:
	"""Set the format for Vector2/Vector3 values"""
	vector_format = format

func set_bool_format(format: BoolFormat) -> void:
	"""Set the format for boolean values"""
	bool_format = format

func set_max_string_length(length: int) -> void:
	"""Set the maximum length for string values"""
	max_string_length = length
