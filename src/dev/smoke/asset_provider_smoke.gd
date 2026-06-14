extends SceneTree

const OpenStrikeAssetManagerRef = preload("res://src/core/assets/asset_manager.gd")
const OpenStrikeGoldSrcLocalConfigRef = preload("res://src/core/assets/goldsrc_local_config.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var root := ProjectSettings.globalize_path("user://asset_provider_smoke").simplify_path()
	_prepare_smoke_tree(root)

	var config = OpenStrikeGoldSrcLocalConfigRef.new()
	config.configure_from_dictionary({
		"cstrike_dir": root.path_join("cstrike"),
		"valve_dir": root.path_join("valve"),
	}, "asset_provider_smoke")

	var manager = OpenStrikeAssetManagerRef.new()
	manager.configure_from_local_config(config)
	manager.configure_asset_manifest_from_dictionary(_synthetic_manifest(), "asset_provider_smoke")

	if not _assert(manager.is_available(), "asset manager should be available for provider smoke", manager.get_diagnostics()):
		return 1

	if not _run_successful_loads(manager):
		return 1
	if not _run_missing_and_mismatch_diagnostics(manager):
		return 1

	print("Asset provider smoke passed.")
	return 0


func _run_successful_loads(manager) -> bool:
	var view_model = manager.load_view_model(&"weapon.ak47.viewmodel")
	if not _assert(view_model.is_success(), "view model should load through semantic asset id", view_model.to_dictionary()):
		return false
	if not _assert(view_model.raw_bytes.get_string_from_utf8() == "synthetic mdl", "view model bytes should come from VFS", view_model.to_dictionary()):
		return false
	if not _assert(view_model.asset_type == &"view_model", "view model result should keep semantic type", view_model.to_dictionary()):
		return false

	var sprite = manager.load_sprite(&"effect.muzzleflash.primary")
	if not _assert(sprite.is_success(), "sprite should load through semantic asset id", sprite.to_dictionary()):
		return false
	if not _assert(sprite.raw_bytes.get_string_from_utf8() == "synthetic spr", "sprite bytes should come from VFS", sprite.to_dictionary()):
		return false

	var sound = manager.load_sound(&"weapon.ak47.fire")
	if not _assert(sound.is_success(), "sound should load through semantic asset id", sound.to_dictionary()):
		return false
	return _assert(sound.raw_bytes.get_string_from_utf8() == "synthetic wav", "sound bytes should come from VFS", sound.to_dictionary())


func _run_missing_and_mismatch_diagnostics(manager) -> bool:
	var missing_id = manager.load_sound(&"weapon.usp.fire")
	if not _assert(not missing_id.is_success(), "missing semantic id should not load", missing_id.to_dictionary()):
		return false
	if not _assert(_has_diagnostic(missing_id.diagnostics, "asset_manifest_entry_missing"), "missing semantic id should report asset_manifest_entry_missing", missing_id.to_dictionary()):
		return false

	var missing_file = manager.load_sound(&"weapon.missing.fire")
	if not _assert(not missing_file.is_success(), "missing physical asset should not load", missing_file.to_dictionary()):
		return false
	if not _assert(_has_diagnostic(missing_file.diagnostics, "vfs_asset_missing"), "missing physical asset should preserve VFS diagnostics", missing_file.to_dictionary()):
		return false

	var type_mismatch = manager.load_sprite(&"weapon.ak47.fire")
	if not _assert(not type_mismatch.is_success(), "requesting a sound through sprite provider should fail", type_mismatch.to_dictionary()):
		return false
	return _assert(_has_diagnostic(type_mismatch.diagnostics, "asset_provider_type_mismatch"), "type mismatch should report asset_provider_type_mismatch", type_mismatch.to_dictionary())


func _synthetic_manifest() -> Dictionary:
	return {
		"assets": {
			"weapon.ak47.viewmodel": {
				"type": "view_model",
				"path": "models/v_ak47.mdl",
				"metadata": {"format": "mdl"},
			},
			"effect.muzzleflash.primary": {
				"type": "sprite",
				"path": "sprites/muzzleflash1.spr",
				"metadata": {"format": "spr"},
			},
			"weapon.ak47.fire": {
				"type": "sound",
				"path": "sound/weapons/ak47-1.wav",
				"metadata": {"format": "wav"},
			},
			"weapon.missing.fire": {
				"type": "sound",
				"path": "sound/weapons/missing.wav",
				"metadata": {"format": "wav"},
			},
		},
	}


func _prepare_smoke_tree(root: String) -> void:
	DirAccess.make_dir_recursive_absolute(root.path_join("cstrike/models"))
	DirAccess.make_dir_recursive_absolute(root.path_join("cstrike/sprites"))
	DirAccess.make_dir_recursive_absolute(root.path_join("cstrike/sound/weapons"))
	DirAccess.make_dir_recursive_absolute(root.path_join("valve/sound/weapons"))

	_write_text(root.path_join("cstrike/models/v_ak47.mdl"), "synthetic mdl")
	_write_text(root.path_join("cstrike/sprites/muzzleflash1.spr"), "synthetic spr")
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
