extends RefCounted

class_name OpenStrikeAssetManifest

const OpenStrikeAssetDiagnosticsRef = preload("res://src/core/assets/asset_diagnostics.gd")
const OpenStrikeAssetReferenceRef = preload("res://src/core/assets/asset_reference.gd")

var source_path: String = ""
var metadata: Dictionary = {}
var diagnostics: Array[Dictionary] = []

var _references: Dictionary = {}


func load_from_file(path: String) -> void:
	_reset()
	source_path = path

	if not FileAccess.file_exists(path):
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_manifest_missing",
			"Asset manifest file is missing.",
			{"path": path}
		))
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_manifest_unreadable",
			"Asset manifest file cannot be opened.",
			{"path": path, "error": FileAccess.get_open_error()}
		))
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_manifest_invalid_json",
			"Asset manifest must be a JSON object.",
			{"path": path}
		))
		return

	configure_from_dictionary(parsed, path)


func configure_from_dictionary(data: Dictionary, source: String = "") -> void:
	_reset()
	source_path = source

	var raw_metadata = data.get("metadata", {})
	if raw_metadata is Dictionary:
		metadata = raw_metadata.duplicate(true)
	else:
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.warning(
			"asset_manifest_metadata_invalid",
			"Asset manifest metadata must be a dictionary.",
			{"source_path": source_path}
		))

	var raw_assets = data.get("assets", {})
	if not raw_assets is Dictionary:
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_manifest_assets_invalid",
			"Asset manifest requires an assets dictionary.",
			{"source_path": source_path}
		))
		return

	for raw_asset_id in raw_assets.keys():
		var asset_id := StringName(str(raw_asset_id).strip_edges())
		var raw_entry = raw_assets[raw_asset_id]
		if not raw_entry is Dictionary:
			diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
				"asset_manifest_entry_invalid",
				"Asset manifest entries must be dictionaries.",
				{"asset_id": str(asset_id), "source_path": source_path}
			))
			continue

		var reference = OpenStrikeAssetReferenceRef.new()
		reference.configure(asset_id, raw_entry)
		_references[asset_id] = reference
		diagnostics.append_array(reference.diagnostics)


func is_valid() -> bool:
	return not OpenStrikeAssetDiagnosticsRef.has_errors(diagnostics)


func has_reference(asset_id: StringName) -> bool:
	return _references.has(asset_id)


func get_reference(asset_id: StringName):
	return _references.get(asset_id, null)


func get_asset_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for asset_id in _references.keys():
		ids.append(asset_id)
	return ids


func to_dictionary() -> Dictionary:
	var assets := {}
	for asset_id in _references.keys():
		assets[str(asset_id)] = _references[asset_id].to_dictionary()
	return {
		"source_path": source_path,
		"metadata": metadata,
		"valid": is_valid(),
		"assets": assets,
		"diagnostics": diagnostics,
	}


func _reset() -> void:
	source_path = ""
	metadata.clear()
	diagnostics.clear()
	_references.clear()
