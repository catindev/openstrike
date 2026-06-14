extends RefCounted

class_name OpenStrikeAssetManager

const OpenStrikeAssetDiagnosticsRef = preload("res://src/core/assets/asset_diagnostics.gd")
const OpenStrikeAssetInspectionReportRef = preload("res://src/core/assets/asset_inspection_report.gd")
const OpenStrikeAssetManifestRef = preload("res://src/core/assets/asset_manifest.gd")
const OpenStrikeAssetProviderResultRef = preload("res://src/core/assets/asset_provider_result.gd")
const OpenStrikeGoldSrcAssetProviderRef = preload("res://src/core/assets/goldsrc_asset_provider.gd")
const OpenStrikeGoldSrcLocalConfigRef = preload("res://src/core/assets/goldsrc_local_config.gd")
const OpenStrikeGoldSrcVFSRef = preload("res://src/core/assets/goldsrc_vfs.gd")

var local_config
var vfs
var asset_manifest
var goldsrc_provider
var diagnostics: Array[Dictionary] = []
var asset_manifest_diagnostics: Array[Dictionary] = []


static func create_from_config_path(path: String = OpenStrikeGoldSrcLocalConfigRef.DEFAULT_CONFIG_PATH):
	var manager = load("res://src/core/assets/asset_manager.gd").new()
	manager.configure_from_config_path(path)
	return manager


func configure_from_config_path(path: String = OpenStrikeGoldSrcLocalConfigRef.DEFAULT_CONFIG_PATH) -> void:
	var config = OpenStrikeGoldSrcLocalConfigRef.new()
	config.load_from_file(path)
	configure_from_local_config(config)


func configure_from_local_config(config) -> void:
	local_config = config
	vfs = OpenStrikeGoldSrcVFSRef.new()
	goldsrc_provider = null
	diagnostics.clear()

	if local_config == null:
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_manager_config_missing",
			"OpenStrikeAssetManager cannot start without a GoldSrc local config."
		))
		return

	diagnostics.append_array(local_config.diagnostics)
	if not local_config.is_valid():
		return

	vfs.configure(local_config.get_search_roots())
	diagnostics.append_array(vfs.get_diagnostics())

	if not vfs.is_available():
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_manager_vfs_unavailable",
			"OpenStrikeAssetManager has no available GoldSrc VFS roots."
		))

	_configure_provider_if_ready()


func configure_asset_manifest_from_file(path: String) -> void:
	var manifest = OpenStrikeAssetManifestRef.new()
	manifest.load_from_file(path)
	configure_asset_manifest(manifest)


func configure_asset_manifest_from_dictionary(data: Dictionary, source: String = "") -> void:
	var manifest = OpenStrikeAssetManifestRef.new()
	manifest.configure_from_dictionary(data, source)
	configure_asset_manifest(manifest)


func configure_asset_manifest(manifest) -> void:
	asset_manifest = manifest
	asset_manifest_diagnostics.clear()

	if asset_manifest == null:
		asset_manifest_diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_manager_manifest_missing",
			"OpenStrikeAssetManager cannot configure providers without an asset manifest."
		))
		goldsrc_provider = null
		return

	asset_manifest_diagnostics.append_array(asset_manifest.diagnostics)
	if not asset_manifest.is_valid():
		goldsrc_provider = null
		return

	_configure_provider_if_ready()


func is_available() -> bool:
	return vfs != null and vfs.is_available() and not OpenStrikeAssetDiagnosticsRef.has_errors(get_diagnostics())


func resolve_asset(relative_path: String) -> Dictionary:
	if vfs == null:
		return {
			"found": false,
			"requested_path": relative_path,
			"normalized_path": "",
			"resolved_path": "",
			"root": "",
			"tried": [],
			"diagnostics": [OpenStrikeAssetDiagnosticsRef.error(
				"asset_manager_vfs_missing",
				"OpenStrikeAssetManager VFS is not configured.",
				{"requested_path": relative_path}
			)],
		}
	return vfs.resolve(relative_path)


func read_asset_bytes(relative_path: String) -> PackedByteArray:
	if vfs == null:
		return PackedByteArray()
	return vfs.read_file_bytes(relative_path)


func load_asset(asset_id: StringName):
	if goldsrc_provider == null:
		return _provider_unavailable_result(asset_id, &"")
	return goldsrc_provider.load_asset(asset_id)


func load_view_model(asset_id: StringName):
	if goldsrc_provider == null:
		return _provider_unavailable_result(asset_id, &"view_model")
	return goldsrc_provider.load_view_model(asset_id)


func load_sprite(asset_id: StringName):
	if goldsrc_provider == null:
		return _provider_unavailable_result(asset_id, &"sprite")
	return goldsrc_provider.load_sprite(asset_id)


func load_sound(asset_id: StringName):
	if goldsrc_provider == null:
		return _provider_unavailable_result(asset_id, &"sound")
	return goldsrc_provider.load_sound(asset_id)


func inspect_asset(asset_id: StringName):
	if goldsrc_provider == null:
		return _provider_unavailable_result(asset_id, &"")
	return goldsrc_provider.inspect_asset(asset_id)


func inspect_view_model(asset_id: StringName):
	if goldsrc_provider == null:
		return _provider_unavailable_result(asset_id, &"view_model")
	return goldsrc_provider.inspect_view_model(asset_id)


func inspect_sprite(asset_id: StringName):
	if goldsrc_provider == null:
		return _provider_unavailable_result(asset_id, &"sprite")
	return goldsrc_provider.inspect_sprite(asset_id)


func inspect_sound(asset_id: StringName):
	if goldsrc_provider == null:
		return _provider_unavailable_result(asset_id, &"sound")
	return goldsrc_provider.inspect_sound(asset_id)


func inspect_manifest():
	var report = OpenStrikeAssetInspectionReportRef.new()

	if asset_manifest == null:
		report.diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_manager_manifest_missing",
			"OpenStrikeAssetManager cannot inspect assets without an asset manifest."
		))
		return report

	if goldsrc_provider == null:
		report.diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_manager_provider_unavailable",
			"OpenStrikeAssetManager cannot inspect assets without a configured provider."
		))
		return report

	for asset_id in asset_manifest.get_asset_ids():
		report.add_result(goldsrc_provider.inspect_asset(asset_id))

	return report


func get_diagnostics() -> Array[Dictionary]:
	var entries := diagnostics.duplicate(true)
	entries.append_array(asset_manifest_diagnostics)
	if vfs != null:
		entries.append_array(vfs.get_diagnostics())
	return entries


func _configure_provider_if_ready() -> void:
	if vfs == null or asset_manifest == null:
		return
	if not vfs.is_available() or not asset_manifest.is_valid():
		return

	goldsrc_provider = OpenStrikeGoldSrcAssetProviderRef.new()
	goldsrc_provider.configure(vfs, asset_manifest)


func _provider_unavailable_result(asset_id: StringName, expected_type: StringName):
	var result = OpenStrikeAssetProviderResultRef.new()
	result.asset_id = asset_id
	result.asset_type = expected_type
	result.provider_id = &"goldsrc"
	result.diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
		"asset_manager_provider_unavailable",
		"OpenStrikeAssetManager has no configured GoldSrc asset provider.",
		{"asset_id": str(asset_id), "expected_type": str(expected_type)}
	))
	return result
