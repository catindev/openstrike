extends RefCounted

class_name OpenStrikeGoldSrcAssetProvider

const OpenStrikeAssetDiagnosticsRef = preload("res://src/core/assets/asset_diagnostics.gd")
const OpenStrikeAssetProviderResultRef = preload("res://src/core/assets/asset_provider_result.gd")

var provider_id: StringName = &"goldsrc"
var vfs
var manifest


func configure(goldsrc_vfs, asset_manifest) -> void:
	vfs = goldsrc_vfs
	manifest = asset_manifest


func load_asset(asset_id: StringName, expected_type: StringName = &""):
	var result = OpenStrikeAssetProviderResultRef.new()
	result.asset_id = asset_id
	result.provider_id = provider_id

	if manifest == null:
		result.diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_provider_manifest_missing",
			"GoldSrc asset provider requires an asset manifest.",
			{"asset_id": str(asset_id)}
		))
		return result

	var reference = manifest.get_reference(asset_id)
	if reference == null:
		result.diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_manifest_entry_missing",
			"Asset manifest does not contain the requested semantic asset id.",
			{"asset_id": str(asset_id)}
		))
		return result

	result.asset_type = reference.asset_type
	result.provider_id = reference.provider_id
	result.relative_path = reference.relative_path
	result.metadata = reference.metadata.duplicate(true)

	if expected_type != StringName() and reference.asset_type != expected_type:
		result.diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_provider_type_mismatch",
			"Semantic asset type does not match the requested provider method.",
			{
				"asset_id": str(asset_id),
				"expected": str(expected_type),
				"actual": str(reference.asset_type),
			}
		))
		return result

	if reference.provider_id != provider_id:
		result.diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_provider_id_mismatch",
			"Semantic asset is assigned to a different provider.",
			{
				"asset_id": str(asset_id),
				"expected": str(provider_id),
				"actual": str(reference.provider_id),
			}
		))
		return result

	if vfs == null:
		result.diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_provider_vfs_missing",
			"GoldSrc asset provider VFS is not configured.",
			{"asset_id": str(asset_id)}
		))
		return result

	var resolution: Dictionary = vfs.resolve(reference.relative_path)
	_apply_resolution(result, resolution)
	if not result.found:
		return result

	_read_resolved_bytes(result)
	return result


func load_view_model(asset_id: StringName):
	return load_asset(asset_id, &"view_model")


func load_sprite(asset_id: StringName):
	return load_asset(asset_id, &"sprite")


func load_sound(asset_id: StringName):
	return load_asset(asset_id, &"sound")


func _apply_resolution(result, resolution: Dictionary) -> void:
	result.found = bool(resolution.get("found", false))
	result.normalized_path = str(resolution.get("normalized_path", ""))
	result.resolved_path = str(resolution.get("resolved_path", ""))
	result.root = str(resolution.get("root", ""))
	result.tried_paths = resolution.get("tried", []).duplicate(true)

	var resolution_diagnostics = resolution.get("diagnostics", [])
	if resolution_diagnostics is Array:
		result.diagnostics.append_array(resolution_diagnostics)


func _read_resolved_bytes(result) -> void:
	var file := FileAccess.open(result.resolved_path, FileAccess.READ)
	if file == null:
		result.diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_provider_read_failed",
			"Resolved GoldSrc asset could not be opened.",
			{
				"asset_id": str(result.asset_id),
				"path": result.resolved_path,
				"error": FileAccess.get_open_error(),
			}
		))
		return

	result.raw_bytes = file.get_buffer(file.get_length())
	result.loaded = true
