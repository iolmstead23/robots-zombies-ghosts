class_name HexPathTracker
extends Node

## Tracks pathfinding operations for testing and analysis

signal path_logged(log_entry: Dictionary)
signal report_generated(report: Dictionary)

var path_history: Array[Dictionary] = []
var max_history_size: int = 100
var tracking_enabled: bool = true

# Statistics
var total_paths_tracked: int = 0
var total_distance_traveled: float = 0.0
var average_path_efficiency: float = 0.0

func log_path(
	start_cell: HexCell,
	end_cell: HexCell,
	path: Array[HexCell],
	duration_ms: float = 0.0,
	metadata: Dictionary = {}
) -> void:
	if not tracking_enabled:
		return
	
	var log_entry := _create_log_entry(start_cell, end_cell, path, duration_ms, metadata)
	_store_log_entry(log_entry)
	_update_statistics(log_entry)
	path_logged.emit(log_entry)
	
	if OS.is_debug_build():
		_print_log_entry(log_entry)

func _create_log_entry(start_cell: HexCell, end_cell: HexCell, path: Array[HexCell], duration_ms: float, metadata: Dictionary) -> Dictionary:
	var entry := {
		"id": total_paths_tracked,
		"timestamp": Time.get_datetime_string_from_system(),
		"start_coords": Vector2i(start_cell.q, start_cell.r) if start_cell else Vector2i.ZERO,
		"end_coords": Vector2i(end_cell.q, end_cell.r) if end_cell else Vector2i.ZERO,
		"path_length": path.size(),
		"movement_cost": max(0, path.size() - 1),
		"straight_line_distance": start_cell.distance_to(end_cell) if (start_cell and end_cell) else 0,
		"path_efficiency": 0.0,
		"duration_ms": duration_ms,
		"success": path.size() > 0,
		"metadata": metadata,
		"path_cells": []
	}
	
	# Calculate efficiency
	if entry["movement_cost"] > 0 and entry["straight_line_distance"] > 0:
		entry["path_efficiency"] = float(entry["straight_line_distance"]) / float(entry["movement_cost"])
	
	# Store path details
	for cell in path:
		entry["path_cells"].append({
			"q": cell.q,
			"r": cell.r,
			"world_pos": cell.world_position
		})
	
	return entry

func _store_log_entry(entry: Dictionary) -> void:
	path_history.append(entry)
	
	if path_history.size() > max_history_size:
		path_history.pop_front()

func _update_statistics(entry: Dictionary) -> void:
	total_paths_tracked += 1
	
	if entry["success"]:
		total_distance_traveled += entry["movement_cost"]
		_recalculate_average_efficiency()

func _recalculate_average_efficiency() -> void:
	var total_efficiency := 0.0
	var count := 0
	
	for entry in path_history:
		if entry["success"] and entry["path_efficiency"] > 0:
			total_efficiency += entry["path_efficiency"]
			count += 1
	
	average_path_efficiency = total_efficiency / float(count) if count > 0 else 0.0

func _print_log_entry(entry: Dictionary) -> void:
	print("\n=== Path Log #%d ===" % entry["id"])
	print("Time: %s" % entry["timestamp"])
	print("Route: (%d, %d) -> (%d, %d)" % [
		entry["start_coords"].x, entry["start_coords"].y,
		entry["end_coords"].x, entry["end_coords"].y
	])
	print("Success: %s" % ("Yes" if entry["success"] else "No"))
	
	if entry["success"]:
		print("Path: %d cells | Cost: %d | Direct: %d | Efficiency: %.1f%%" % [
			entry["path_length"], entry["movement_cost"],
			entry["straight_line_distance"], entry["path_efficiency"] * 100.0
		])
		
		if entry["duration_ms"] > 0:
			print("Duration: %.3f ms" % entry["duration_ms"])

func get_recent_paths(count: int = 10) -> Array[Dictionary]:
	var start_index: int = max(0, path_history.size() - count)
	return path_history.slice(start_index)

func get_all_paths() -> Array[Dictionary]:
	return path_history.duplicate()

func clear_history() -> void:
	path_history.clear()
	if OS.is_debug_build():
		print("HexPathTracker: History cleared")

func generate_report() -> Dictionary:
	var report := {
		"total_paths": total_paths_tracked,
		"successful_paths": 0,
		"failed_paths": 0,
		"total_distance": total_distance_traveled,
		"average_efficiency": average_path_efficiency,
		"average_path_length": 0.0,
		"min_path_length": INF,
		"max_path_length": 0,
		"average_duration_ms": 0.0,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	if path_history.is_empty():
		report_generated.emit(report)
		return report
	
	var total_length := 0
	var total_duration := 0.0
	var paths_with_duration := 0
	
	for entry in path_history:
		if entry["success"]:
			report["successful_paths"] += 1
			total_length += entry["path_length"]
			report["min_path_length"] = min(report["min_path_length"], entry["path_length"])
			report["max_path_length"] = max(report["max_path_length"], entry["path_length"])
			
			if entry["duration_ms"] > 0:
				total_duration += entry["duration_ms"]
				paths_with_duration += 1
		else:
			report["failed_paths"] += 1
	
	if report["successful_paths"] > 0:
		report["average_path_length"] = float(total_length) / float(report["successful_paths"])
	
	if paths_with_duration > 0:
		report["average_duration_ms"] = total_duration / float(paths_with_duration)
	
	report_generated.emit(report)
	return report

func print_report() -> void:
	var report := generate_report()
	var separator := "=".repeat(50)
	
	print("\n%s\nPATHFINDING ANALYSIS REPORT\n%s" % [separator, separator])
	print("Generated: %s\n" % report["timestamp"])
	print("Overall Statistics:")
	print("  Total Paths: %d" % report["total_paths"])
	print("  Successful: %d (%.1f%%)" % [
		report["successful_paths"],
		_calculate_success_rate(report)
	])
	print("  Failed: %d\n" % report["failed_paths"])
	print("Path Metrics:")
	print("  Total Distance: %.1f cells" % report["total_distance"])
	print("  Avg Length: %.2f cells" % report["average_path_length"])
	print("  Min/Max: %d / %d cells" % [report["min_path_length"], report["max_path_length"]])
	print("  Avg Efficiency: %.1f%%" % (report["average_efficiency"] * 100.0))
	
	if report["average_duration_ms"] > 0:
		print("\nPerformance:")
		print("  Avg Calculation: %.3f ms" % report["average_duration_ms"])
	
	print(separator + "\n")

func _calculate_success_rate(report: Dictionary) -> float:
	if report["total_paths"] == 0:
		return 0.0
	return (float(report["successful_paths"]) / float(report["total_paths"])) * 100.0

func export_to_json(file_path: String) -> bool:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("HexPathTracker: Failed to open file: %s" % file_path)
		return false
	
	var export_data := {
		"report": generate_report(),
		"paths": path_history
	}
	
	file.store_string(JSON.stringify(export_data, "\t"))
	file.close()
	
	if OS.is_debug_build():
		print("HexPathTracker: Data exported to %s" % file_path)
	return true

func compare_paths(path1_id: int, path2_id: int) -> void:
	if path1_id >= path_history.size() or path2_id >= path_history.size():
		push_error("HexPathTracker: Invalid path IDs")
		return
	
	var p1 := path_history[path1_id]
	var p2 := path_history[path2_id]
	
	print("\n=== Path Comparison ===")
	print("Path #%d: Length %d | Efficiency %.1f%%" % [path1_id, p1["path_length"], p1["path_efficiency"] * 100.0])
	print("Path #%d: Length %d | Efficiency %.1f%%" % [path2_id, p2["path_length"], p2["path_efficiency"] * 100.0])
	
	var diff_length: int = p2["path_length"] - p1["path_length"]
	var diff_efficiency: int = (p2["path_efficiency"] - p1["path_efficiency"]) * 100.0
	
	print("\nDifference: %+d cells | %+.1f%% efficiency" % [diff_length, diff_efficiency])
	
	if diff_length < 0:
		print("-> Path #%d is shorter" % path2_id)
	elif diff_length > 0:
		print("-> Path #%d is shorter" % path1_id)
	else:
		print("-> Equal length")