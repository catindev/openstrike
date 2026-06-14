extends RefCounted

class_name OpenStrikeAssetReference

const OpenStrikeAssetDiagnosticsRef = preload("res://src/core/assets/asset_diagnostics.gd")

var asset_id: StringName = &""
var asset_type: StringName = &""
var relative_path: String = ""
var provider_id: StringName = &"goldsrc"
var metadata: Dictionary = {}
var diagnostics: Array[Dictionary] = []


func configure(id: StringName, data: Dictionary) -> void:
	asset_id = id
	asset_type = StringName(str(data.get("type", "")).strip_edges())
	relative_path = str(data.get("path", "")).strip_edges()
	provider_id = StringName(str(data.get("provider", "goldsrc")).strip_edges())
	metadata = {}
	diagnostics.clear()

	var raw_metadata = data.get("metadata", {})
	if raw_metadata is Dictionary:
		metadata = raw_metadata.duplicate(true)
	else:
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.warning(
			"asset_reference_metadata_invalid",
			"Asset reference metadata must be a dictionary.",
			{"asset_id": str(asset_id)}
		))

	_validate()


func is_valid() -> bool:
	return not OpenStrikeAssetDiagnosticsRef.has_errors(diagnostics)


func to_dictionary() -> Dictionary:
	return {
		"asset_id": str(asset_id),
		"type": str(asset_type),
		"path": relative_path,
		"provider": str(provider_id),
		"metadata": metadata,
		"valid": is_valid(),
		"diagnostics": diagnostics,
	}


func _validate() -> void:
	if asset_id == StringName():
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_reference_id_missing",
			"Asset reference requires a semantic asset id."
		))

	if asset_type == StringName():
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_reference_type_missing",
			"Asset reference requires a semantic asset type.",
			{"asset_id": str(asset_id)}
		))

	if relative_path == "":
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_reference_path_missing",
			"Asset reference requires a GoldSrc-relative path.",
			{"asset_id": str(asset_id)}
		))

	if provider_id == StringName():
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_reference_provider_missing",
			"Asset reference requires a provider id.",
			{"asset_id": str(asset_id)}
		))
