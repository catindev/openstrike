extends SceneTree

const CATALOG_PATH := "res://data/assets/cs16_pilot_weapon_assets.json"
const EXPECTED_TOTAL := 32

const OpenStrikeAssetManagerRef = preload("res://src/core/assets/asset_manager.gd")
const OpenStrikeGoldSrcLocalConfigRef = preload("res://src/core/assets/goldsrc_local_config.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var catalog := _load_catalog()
	if catalog.is_empty():
		return 1

	var root := ProjectSettings.globalize_path("user://asset_catalog_smoke").simplify_path()
	_prepare_synthetic_install(root, catalog)

	var config = OpenStrikeGoldSrcLocalConfigRef.new()
	config.configure_from_dictionary({
		"cstrike_dir": root.path_join("cstrike"),
		"valve_dir": root.path_join("valve"),
	}, "asset_catalog_smoke")

	var manager = OpenStrikeAssetManagerRef.new()
	manager.configure_from_local_config(config)
	manager.configure_asset_manifest_from_file(CATALOG_PATH)

	if not _assert(manager.is_available(), "asset manager should be available for pilot catalog", manager.get_diagnostics()):
		return 1

	var report = manager.inspect_manifest()
	var summary: Dictionary = report.to_dictionary()
	if not _assert(report.is_complete(), "pilot weapon asset catalog should fully resolve against synthetic install", summary):
		return 1
	if not _assert(report.total_count == EXPECTED_TOTAL, "pilot catalog entry count should stay intentional", summary):
		return 1
	if not _assert(report.resolved_count == EXPECTED_TOTAL, "all pilot catalog entries should resolve", summary):
		return 1
	if not _assert(int(report.type_counts.get("view_model", 0)) == 4, "pilot catalog should contain four viewmodels", summary):
		return 1
	if not _assert(int(report.type_counts.get("sprite", 0)) == 4, "pilot catalog should contain four sprites", summary):
		return 1
	if not _assert(int(report.type_counts.get("sound", 0)) == 24, "pilot catalog should contain 24 sounds", summary):
		return 1

	if not _assert(manager.inspect_view_model(&"weapon.ak47.viewmodel").is_resolved(), "AK-47 viewmodel should resolve", summary):
		return 1
	if not _assert(manager.inspect_view_model(&"weapon.usp.viewmodel").is_resolved(), "USP viewmodel should resolve", summary):
		return 1
	if not _assert(manager.inspect_view_model(&"weapon.knife.viewmodel").is_resolved(), "knife viewmodel should resolve", summary):
		return 1
	if not _assert(manager.inspect_view_model(&"weapon.hegrenade.viewmodel").is_resolved(), "HE viewmodel should resolve", summary):
		return 1

	print("Asset catalog smoke passed.")
	return 0


func _load_catalog() -> Dictionary:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open pilot asset catalog: %s" % CATALOG_PATH)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Pilot asset catalog must be a JSON object.")
		return {}
	return parsed


func _prepare_synthetic_install(root: String, catalog: Dictionary) -> void:
	var raw_assets = catalog.get("assets", {})
	if not raw_assets is Dictionary:
		return

	DirAccess.make_dir_recursive_absolute(root.path_join("cstrike"))
	DirAccess.make_dir_recursive_absolute(root.path_join("valve"))

	for raw_asset_id in raw_assets.keys():
		var entry = raw_assets[raw_asset_id]
		if not entry is Dictionary:
			continue
		var relative_path := str(entry.get("path", "")).strip_edges()
		if relative_path == "":
			continue
		var file_path := root.path_join("cstrike").path_join(relative_path).simplify_path()
		DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())
		_write_text(file_path, "synthetic catalog fixture for %s" % str(raw_asset_id))


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
