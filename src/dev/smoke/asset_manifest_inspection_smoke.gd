extends SceneTree

const OpenStrikeAssetManagerRef = preload("res://src/core/assets/asset_manager.gd")
const OpenStrikeAssetManifestRef = preload("res://src/core/assets/asset_manifest.gd")
const OpenStrikeGoldSrcLocalConfigRef = preload("res://src/core/assets/goldsrc_local_config.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var root := ProjectSettings.globalize_path("user://asset_manifest_inspection_smoke").simplify_path()
	_prepare_smoke_tree(root)

	var config = OpenStrikeGoldSrcLocalConfigRef.new()
	config.configure_from_dictionary({
		"cstrike_dir": root.path_join("cstrike"),
		"valve_dir": root.path_join("valve"),
	}, "asset_manifest_inspection_smoke")

	var manager = OpenStrikeAssetManagerRef.new()
	manager.configure_from_local_config(config)
	manager.configure_asset_manifest_from_dictionary(_synthetic_manifest(), "asset_manifest_inspection_smoke")

	if not _assert(manager.is_available(), "asset manager should be available for manifest inspection", manager.get_diagnostics()):
		return 1

	var view_model = manager.inspect_view_model(&"weapon.ak47.viewmodel")
	if not _assert(view_model.is_resolved(), "view model inspection should resolve without loading bytes", view_model.to_dictionary()):
		return 1
	if not _assert(not view_model.loaded and view_model.raw_bytes.is_empty(), "inspection should not read asset bytes", view_model.to_dictionary()):
		return 1

	var missing_sound = manager.inspect_sound(&"weapon.missing.fire")
	if not _assert(not missing_sound.is_resolved(), "missing sound inspection should not resolve", missing_sound.to_dictionary()):
		return 1
	if not _assert(_has_diagnostic(missing_sound.diagnostics, "vfs_asset_missing"), "missing sound should preserve VFS diagnostics", missing_sound.to_dictionary()):
		return 1

	var report = manager.inspect_manifest()
	var summary: Dictionary = report.to_dictionary()
	if not _assert(str(summary["metadata"].get("catalog_id", "")) == "asset_manifest_inspection_smoke", "inspection report should retain manifest metadata", summary):
		return 1
	if not _assert(not report.is_complete(), "inspection report should be incomplete when one file is missing", summary):
		return 1
	if not _assert(report.total_count == 3, "inspection report should count all manifest entries", summary):
		return 1
	if not _assert(report.resolved_count == 2, "inspection report should count resolved entries", summary):
		return 1
	if not _assert(report.missing_count == 1, "inspection report should count missing entries", summary):
		return 1
	if not _assert(report.invalid_count == 0, "missing files are not invalid manifest entries", summary):
		return 1
	if not _assert(int(report.type_counts.get("view_model", 0)) == 1, "inspection report should count view models by type", summary):
		return 1
	if not _assert(int(report.type_counts.get("sound", 0)) == 2, "inspection report should count sounds by type", summary):
		return 1

	if not _run_manifest_contract_validation_smoke():
		return 1

	print("Asset manifest inspection smoke passed.")
	return 0


func _run_manifest_contract_validation_smoke() -> bool:
	var cases: Array[Dictionary] = [
		{
			"name": "unsupported_provider",
			"entry": {
				"type": "sound",
				"provider": "unknown",
				"path": "sound/weapons/ak47-1.wav",
			},
			"code": "asset_reference_provider_unsupported",
		},
		{
			"name": "unsupported_type",
			"entry": {
				"type": "texture",
				"path": "sprites/muzzleflash1.spr",
			},
			"code": "asset_reference_type_unsupported",
		},
		{
			"name": "extension_mismatch",
			"entry": {
				"type": "sound",
				"path": "models/v_ak47.mdl",
			},
			"code": "asset_reference_extension_mismatch",
		},
		{
			"name": "parent_traversal",
			"entry": {
				"type": "sound",
				"path": "sound/../weapons/ak47-1.wav",
			},
			"code": "asset_reference_path_traversal",
		},
		{
			"name": "absolute_path",
			"entry": {
				"type": "sound",
				"path": "/tmp/ak47-1.wav",
			},
			"code": "asset_reference_path_absolute",
		},
		{
			"name": "backslash_path",
			"entry": {
				"type": "sound",
				"path": "sound\\weapons\\ak47-1.wav",
			},
			"code": "asset_reference_path_backslash",
		},
	]

	for test_case in cases:
		var manifest = OpenStrikeAssetManifestRef.new()
		manifest.configure_from_dictionary({
			"assets": {
				"bad.%s" % str(test_case["name"]): test_case["entry"],
			},
		}, "asset_manifest_contract_%s" % str(test_case["name"]))

		if not _assert(not manifest.is_valid(), "invalid manifest case should fail validation: %s" % str(test_case["name"]), manifest.to_dictionary()):
			return false
		if not _assert(_has_diagnostic(manifest.diagnostics, str(test_case["code"])), "invalid manifest case should report expected diagnostic: %s" % str(test_case["name"]), manifest.to_dictionary()):
			return false

	return true


func _synthetic_manifest() -> Dictionary:
	return {
		"metadata": {
			"catalog_id": "asset_manifest_inspection_smoke",
			"scope": "Synthetic inspection smoke manifest.",
		},
		"assets": {
			"weapon.ak47.viewmodel": {
				"type": "view_model",
				"path": "models/v_ak47.mdl",
			},
			"weapon.ak47.fire": {
				"type": "sound",
				"path": "sound/weapons/ak47-1.wav",
			},
			"weapon.missing.fire": {
				"type": "sound",
				"path": "sound/weapons/missing.wav",
			},
		},
	}


func _prepare_smoke_tree(root: String) -> void:
	DirAccess.make_dir_recursive_absolute(root.path_join("cstrike/models"))
	DirAccess.make_dir_recursive_absolute(root.path_join("cstrike/sound/weapons"))
	DirAccess.make_dir_recursive_absolute(root.path_join("valve/sound/weapons"))

	_write_text(root.path_join("cstrike/models/v_ak47.mdl"), "synthetic mdl")
	_write_text(root.path_join("cstrike/sound/weapons/ak47-1.wav"), "synthetic wav")


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)


func _has_diagnostic(entries: Array, code: String) -> bool:
	for entry in entries:
		if entry is Dictionary and str(entry.get("code", "")) == code:
			return true
	return false


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
