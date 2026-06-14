extends RefCounted

class_name OpenStrikeAssetProviderResult

const OpenStrikeAssetDiagnosticsRef = preload("res://src/core/assets/asset_diagnostics.gd")

var asset_id: StringName = &""
var asset_type: StringName = &""
var provider_id: StringName = &""
var relative_path: String = ""
var normalized_path: String = ""
var resolved_path: String = ""
var root: String = ""
var tried_paths: Array = []
var found: bool = false
var loaded: bool = false
var raw_bytes: PackedByteArray = PackedByteArray()
var metadata: Dictionary = {}
var diagnostics: Array[Dictionary] = []


func is_success() -> bool:
	return found and loaded and not OpenStrikeAssetDiagnosticsRef.has_errors(diagnostics)


func is_resolved() -> bool:
	return found and not OpenStrikeAssetDiagnosticsRef.has_errors(diagnostics)


func to_dictionary() -> Dictionary:
	return {
		"asset_id": str(asset_id),
		"type": str(asset_type),
		"provider": str(provider_id),
		"relative_path": relative_path,
		"normalized_path": normalized_path,
		"resolved_path": resolved_path,
		"root": root,
		"tried": tried_paths,
		"found": found,
		"loaded": loaded,
		"resolved": is_resolved(),
		"bytes": raw_bytes.size(),
		"metadata": metadata,
		"diagnostics": diagnostics,
	}
