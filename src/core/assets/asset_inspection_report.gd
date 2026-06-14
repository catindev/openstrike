extends RefCounted

class_name OpenStrikeAssetInspectionReport

const OpenStrikeAssetDiagnosticsRef = preload("res://src/core/assets/asset_diagnostics.gd")

var source_path: String = ""
var metadata: Dictionary = {}
var total_count: int = 0
var resolved_count: int = 0
var missing_count: int = 0
var invalid_count: int = 0
var type_counts: Dictionary = {}
var entries: Array[Dictionary] = []
var diagnostics: Array[Dictionary] = []


func add_result(result) -> void:
	total_count += 1

	var asset_type := str(result.asset_type)
	type_counts[asset_type] = int(type_counts.get(asset_type, 0)) + 1

	var entry: Dictionary = result.to_dictionary()
	entries.append(entry)

	if OpenStrikeAssetDiagnosticsRef.has_errors(result.diagnostics):
		invalid_count += 1
	elif result.found:
		resolved_count += 1
	else:
		missing_count += 1


func is_complete() -> bool:
	return total_count > 0 and resolved_count == total_count and invalid_count == 0 and missing_count == 0


func to_dictionary() -> Dictionary:
	return {
		"source_path": source_path,
		"metadata": metadata,
		"total": total_count,
		"resolved": resolved_count,
		"missing": missing_count,
		"invalid": invalid_count,
		"type_counts": type_counts,
		"complete": is_complete(),
		"entries": entries,
		"diagnostics": diagnostics,
	}
