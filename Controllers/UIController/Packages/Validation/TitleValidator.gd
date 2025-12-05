class_name TitleValidator
extends RefCounted

## Title Validation Package
## Enforces title requirements for all overlays

# ============================================================================
# VALIDATION
# ============================================================================

static func validate_title(title: String, max_length: int = 40) -> Dictionary:
	"""
	Validates overlay title against requirements.

	Args:
		title: The title string to validate
		max_length: Maximum allowed length for the title

	Returns:
		Dictionary with keys:
			- valid (bool): Whether the title passes validation
			- errors (Array[String]): List of validation errors
	"""
	var result = {
		"valid": true,
		"errors": []
	}

	# Check if title is empty
	if title.is_empty():
		result.valid = false
		result.errors.append("Title is required for all overlays")

	# Check title length
	if title.length() > max_length:
		result.valid = false
		result.errors.append(
			"Title exceeds maximum length (%d > %d)" % [title.length(), max_length]
		)

	# Check for invalid characters (optional)
	if title.contains("\n") or title.contains("\t"):
		result.valid = false
		result.errors.append("Title cannot contain newline or tab characters")

	return result

# ============================================================================
# SANITIZATION
# ============================================================================

static func sanitize_title(title: String, max_length: int = 40) -> String:
	"""
	Sanitize a title to meet validation requirements.

	Args:
		title: The title to sanitize
		max_length: Maximum allowed length

	Returns:
		Sanitized title string
	"""
	var sanitized = title.strip_edges()

	# Remove newlines and tabs
	sanitized = sanitized.replace("\n", " ")
	sanitized = sanitized.replace("\t", " ")

	# Remove multiple consecutive spaces
	while sanitized.contains("  "):
		sanitized = sanitized.replace("  ", " ")

	# Truncate if too long
	if sanitized.length() > max_length:
		sanitized = sanitized.substr(0, max_length - 3) + "..."

	# Provide default if empty
	if sanitized.is_empty():
		sanitized = "UNTITLED"

	return sanitized

# ============================================================================
# UTILITY
# ============================================================================

static func is_valid_title(title: String, max_length: int = 40) -> bool:
	"""Quick validation check - returns true if title is valid"""
	return validate_title(title, max_length).valid
