extends SceneTree

const OpenStrikeAssetManagerRef = preload("res://src/core/assets/asset_manager.gd")
const OpenStrikeGoldSrcLocalConfigRef = preload("res://src/core/assets/goldsrc_local_config.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var root := ProjectSettings.globalize_path("user://asset_vfs_smoke").simplify_path()
	_prepare_smoke_tree(root)

	if not _run_derived_config_smoke(root):
		return 1
	if not _run_explicit_roots_smoke(root):
		return 1
	if not _run_invalid_config_smoke(root):
		return 1

	print("Asset VFS smoke passed.")
	return 0


func _run_derived_config_smoke(root: String) -> bool:
	var config = OpenStrikeGoldSrcLocalConfigRef.new()
	config.configure_from_dictionary({
		"half_life_dir": root,
	}, "asset_vfs_smoke_derived")

	if not _assert(config.is_valid(), "half_life_dir-derived local config should be valid", config.to_dictionary()):
		return false
	if not _assert(config.cstrike_dir == root.path_join("cstrike").simplify_path(), "cstrike_dir should derive from half_life_dir", config.to_dictionary()):
		return false
	if not _assert(config.valve_dir == root.path_join("valve").simplify_path(), "valve_dir should derive from half_life_dir", config.to_dictionary()):
		return false

	return _run_vfs_resolution_smoke(config)


func _run_explicit_roots_smoke(root: String) -> bool:
	var config = OpenStrikeGoldSrcLocalConfigRef.new()
	config.configure_from_dictionary({
		"cstrike_dir": root.path_join("cstrike"),
		"valve_dir": root.path_join("valve"),
	}, "asset_vfs_smoke_explicit")

	if not _assert(config.is_valid(), "explicit cstrike_dir + valve_dir config should be valid without half_life_dir", config.to_dictionary()):
		return false
	if not _assert(config.half_life_dir == "", "explicit roots should not require half_life_dir", config.to_dictionary()):
		return false
	if not _assert(config.get_search_roots().size() == 2, "explicit roots should search cstrike then valve only", config.to_dictionary()):
		return false

	return _run_vfs_resolution_smoke(config)


func _run_vfs_resolution_smoke(config) -> bool:
	var manager = OpenStrikeAssetManagerRef.new()
	manager.configure_from_local_config(config)

	if not _assert(manager.is_available(), "asset manager should be available", manager.get_diagnostics()):
		return false

	var hud := manager.resolve_asset("sprites/hud.txt")
	if not _assert(bool(hud["found"]), "VFS should resolve case-insensitive cstrike file", hud):
		return false
	if not _assert(str(hud["root"]).ends_with("/cstrike"), "VFS should resolve from cstrike root first", hud):
		return false
	var hud_content := manager.read_asset_bytes("sprites/hud.txt").get_string_from_utf8()
	if not _assert(hud_content == "hud", "VFS should read case-insensitive cstrike file", {"content": hud_content, "resolution": hud}):
		return false

	var overlay := manager.read_asset_bytes("sound/overlay.txt").get_string_from_utf8()
	if not _assert(overlay == "cstrike", "cstrike root should override valve root", {"content": overlay}):
		return false

	var fallback := manager.read_asset_bytes("sound/fallback.txt").get_string_from_utf8()
	if not _assert(fallback == "valve", "valve root should be used as fallback", {"content": fallback}):
		return false

	var invalid := manager.resolve_asset("../config.cfg")
	if not _assert(not bool(invalid["found"]), "parent traversal should be rejected", invalid):
		return false
	if not _assert(str(invalid["diagnostics"][0]["code"]) == "vfs_invalid_relative_path", "invalid path should report diagnostics", invalid):
		return false

	return true


func _run_invalid_config_smoke(root: String) -> bool:
	var empty_config = OpenStrikeGoldSrcLocalConfigRef.new()
	empty_config.configure_from_dictionary({}, "asset_vfs_smoke_empty")
	if not _assert(not empty_config.is_valid(), "empty local config should be invalid", empty_config.to_dictionary()):
		return false
	if not _assert(_has_diagnostic(empty_config.diagnostics, "local_config_roots_missing"), "empty local config should report missing roots", empty_config.diagnostics):
		return false

	var only_cstrike = OpenStrikeGoldSrcLocalConfigRef.new()
	only_cstrike.configure_from_dictionary({
		"cstrike_dir": root.path_join("cstrike"),
	}, "asset_vfs_smoke_only_cstrike")
	if not _assert(not only_cstrike.is_valid(), "config with only cstrike_dir should be invalid", only_cstrike.to_dictionary()):
		return false
	if not _assert(_has_diagnostic(only_cstrike.diagnostics, "local_config_roots_missing"), "config with only cstrike_dir should report missing root pair", only_cstrike.diagnostics):
		return false
	if not _assert(_has_field_diagnostic(only_cstrike.diagnostics, "local_config_path_missing", "valve_dir"), "config with only cstrike_dir should report missing valve_dir", only_cstrike.diagnostics):
		return false

	var only_valve = OpenStrikeGoldSrcLocalConfigRef.new()
	only_valve.configure_from_dictionary({
		"valve_dir": root.path_join("valve"),
	}, "asset_vfs_smoke_only_valve")
	if not _assert(not only_valve.is_valid(), "config with only valve_dir should be invalid", only_valve.to_dictionary()):
		return false
	if not _assert(_has_diagnostic(only_valve.diagnostics, "local_config_roots_missing"), "config with only valve_dir should report missing root pair", only_valve.diagnostics):
		return false
	if not _assert(_has_field_diagnostic(only_valve.diagnostics, "local_config_path_missing", "cstrike_dir"), "config with only valve_dir should report missing cstrike_dir", only_valve.diagnostics):
		return false

	var missing_config = OpenStrikeGoldSrcLocalConfigRef.new()
	missing_config.load_from_file(root.path_join("missing_local_goldsrc.json"))
	if not _assert(not missing_config.is_valid(), "missing local config file should be invalid", missing_config.to_dictionary()):
		return false
	if not _assert(_has_diagnostic(missing_config.diagnostics, "local_config_missing"), "missing local config file should report local_config_missing", missing_config.diagnostics):
		return false

	var non_object_path := root.path_join("non_object_local_goldsrc.json")
	_write_text(non_object_path, "[\"not\", \"an\", \"object\"]")
	var non_object_config = OpenStrikeGoldSrcLocalConfigRef.new()
	non_object_config.load_from_file(non_object_path)
	if not _assert(not non_object_config.is_valid(), "non-object local config JSON should be invalid", non_object_config.to_dictionary()):
		return false
	return _assert(_has_diagnostic(non_object_config.diagnostics, "local_config_invalid_json"), "non-object local config JSON should report local_config_invalid_json", non_object_config.diagnostics)


func _prepare_smoke_tree(root: String) -> void:
	DirAccess.make_dir_recursive_absolute(root.path_join("cstrike/Sprites"))
	DirAccess.make_dir_recursive_absolute(root.path_join("cstrike/sound"))
	DirAccess.make_dir_recursive_absolute(root.path_join("valve/sound"))

	_write_text(root.path_join("cstrike/Sprites/HUD.TXT"), "hud")
	_write_text(root.path_join("cstrike/sound/overlay.txt"), "cstrike")
	_write_text(root.path_join("valve/sound/overlay.txt"), "valve")
	_write_text(root.path_join("valve/sound/fallback.txt"), "valve")


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)


func _has_diagnostic(entries: Array, code: String) -> bool:
	for entry in entries:
		if entry is Dictionary and str(entry.get("code", "")) == code:
			return true
	return false


func _has_field_diagnostic(entries: Array, code: String, field_name: String) -> bool:
	for entry in entries:
		if not (entry is Dictionary):
			continue
		if str(entry.get("code", "")) != code:
			continue
		var context = entry.get("context", {})
		if context is Dictionary and str(context.get("field", "")) == field_name:
			return true
	return false


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
