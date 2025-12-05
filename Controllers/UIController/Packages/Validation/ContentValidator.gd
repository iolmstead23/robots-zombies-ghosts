class_name ContentValidator
extends RefCounted

## Content Validation Package
## Provides strict validation to prevent text overflow beyond overlay boundaries

# ============================================================================
# VALIDATION
# ============================================================================

static func validate_content(
	line_count: int,
	max_lines: int,
	strict: bool
) -> Dictionary:
	"""
	Validates content line count against overlay limits.

	Args:
		line_count: Number of content lines
		max_lines: Maximum allowed lines
		strict: If true, overflow is an error; if false, it's a warning

	Returns:
		Dictionary with keys:
			- valid (bool): Whether content passes validation
			- overflow (int): Number of lines exceeding the limit
			- errors (Array[String]): List of validation errors
			- warnings (Array[String]): List of warnings
	"""
	var result = {
		"valid": true,
		"overflow": 0,
		"errors": [],
		"warnings": []
	}

	if line_count > max_lines:
		result.overflow = line_count - max_lines

		if strict:
			result.valid = false
			result.errors.append(
				"Content exceeds maximum lines: %d/%d (overflow: %d)" %
				[line_count, max_lines, result.overflow]
			)
		else:
			result.warnings.append(
				"Content overflow: %d/%d lines (overflow: %d)" %
				[line_count, max_lines, result.overflow]
			)

	return result

static func validate_line_lengths(
	lines: Array[String],
	max_chars_per_line: int
) -> Array[int]:
	"""
	Check which lines exceed character limit.

	Args:
		lines: Array of content lines
		max_chars_per_line: Maximum characters per line

	Returns:
		Array of line indices that exceed the limit
	"""
	var violations: Array[int] = []

	for i in range(lines.size()):
		if lines[i].length() > max_chars_per_line:
			violations.append(i)

	return violations

# ============================================================================
# TRUNCATION
# ============================================================================

static func truncate_to_fit(
	lines: Array[String],
	max_lines: int,
	indicator: String = "..."
) -> Array[String]:
	"""
	Truncate line array to fit within maximum line count.

	Args:
		lines: Array of content lines
		max_lines: Maximum allowed lines
		indicator: String to append when truncated

	Returns:
		Truncated array of lines
	"""
	if lines.size() <= max_lines:
		return lines

	# Take first (max_lines - 1) lines and add truncation indicator
	var truncated = lines.slice(0, max_lines - 1)
	truncated.append(indicator)

	return truncated

static func truncate_line(line: String, max_chars: int, indicator: String = "...") -> String:
	"""
	Truncate a single line to fit within character limit.

	Args:
		line: The line to truncate
		max_chars: Maximum characters
		indicator: String to append when truncated

	Returns:
		Truncated line
	"""
	if line.length() <= max_chars:
		return line

	return line.substr(0, max_chars - indicator.length()) + indicator

# ============================================================================
# UTILITY
# ============================================================================

static func count_lines_in_text(text: String) -> int:
	"""Count number of lines in a text block"""
	if text.is_empty():
		return 0

	var lines = text.split("\n")
	return lines.size()

static func estimate_line_width(text: String, avg_char_width: float = 8.0) -> float:
	"""Estimate pixel width of a line based on character count"""
	return text.length() * avg_char_width

static func calculate_max_lines_for_height(
	available_height: float,
	line_height: float,
	spacing: float = 2.0
) -> int:
	"""Calculate maximum lines that fit in available height"""
	if line_height <= 0:
		return 0

	var effective_line_height = line_height + spacing
	return int(available_height / effective_line_height)
