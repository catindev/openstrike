extends SceneTree

const AssetManagerRef = preload("res://src/core/assets/asset_manager.gd")
const GoldSrcLocalConfigRef = preload("res://src/core/assets/goldsrc_local_config.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var root := ProjectSettings.globalize_path("user://asset_vfs_smoke").simplify_path()
	_prepare_smoke_tree(root)

	var config = GoldSrcLocalConfigRef.new()
	config.configure_from_dictionary({
		"half_life_dir": root,
		"cstrike_dir": root.path_join("cstrike"),
		"valve_dir": root.path_join("valve"),
	}, "asset_vfs_smoke")

	if not _assert(config.is_valid(), "local config should be valid", config.diagnostics):
		return 1

	var manager = AssetManagerRef.new()
	manager.configure_from_local_config(config)

	if not _assert(manager.is_available(), "asset manager should be available", manager.get_diagnostics()):
		return 1

	var hud := manager.resolve_asset("sprites/hud.txt")
	if not _assert(bool(hud["found"]), "VFS should resolve case-insensitive cstrike file", hud):
		return 1
	if not _assert(str(hud["root"]).ends_with("/cstrike"), "VFS should resolve from cstrike root first", hud):
		return 1
	var hud_content := manager.read_asset_bytes("sprites/hud.txt").get_string_from_utf8()
	if not _assert(hud_content == "hud", "VFS should read case-insensitive cstrike file", {"content": hud_content, "resolution": hud}):
		return 1

	var overlay := manager.read_asset_bytes("sound/overlay.txt").get_string_from_utf8()
	if not _assert(overlay == "cstrike", "cstrike root should override valve root", {"content": overlay}):
		return 1

	var fallback := manager.read_asset_bytes("sound/fallback.txt").get_string_from_utf8()
	if not _assert(fallback == "valve", "valve root should be used as fallback", {"content": fallback}):
		return 1

	var invalid := manager.resolve_asset("../config.cfg")
	if not _assert(not bool(invalid["found"]), "parent traversal should be rejected", invalid):
		return 1
	if not _assert(str(invalid["diagnostics"][0]["code"]) == "vfs_invalid_relative_path", "invalid path should report diagnostics", invalid):
		return 1

	print("Asset VFS smoke passed.")
	return 0


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


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
