extends RefCounted

class_name OpenStrikeAssetManager

const OpenStrikeAssetDiagnosticsRef = preload("res://src/core/assets/asset_diagnostics.gd")
const OpenStrikeGoldSrcLocalConfigRef = preload("res://src/core/assets/goldsrc_local_config.gd")
const OpenStrikeGoldSrcVFSRef = preload("res://src/core/assets/goldsrc_vfs.gd")

var local_config
var vfs
var diagnostics: Array[Dictionary] = []


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


func is_available() -> bool:
	return vfs != null and vfs.is_available() and not OpenStrikeAssetDiagnosticsRef.has_errors(diagnostics)


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


func get_diagnostics() -> Array[Dictionary]:
	var entries := diagnostics.duplicate(true)
	if vfs != null:
		entries.append_array(vfs.get_diagnostics())
	return entries
