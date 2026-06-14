extends SceneTree

const DEFAULT_CATALOG_PATH := "res://data/assets/cs16_pilot_weapon_assets.json"
const TOOL_NAME := "asset_catalog_inspect_local"

const OpenStrikeAssetManagerRef = preload("res://src/core/assets/asset_manager.gd")
const OpenStrikeGoldSrcLocalConfigRef = preload("res://src/core/assets/goldsrc_local_config.gd")

const SENSITIVE_CONTEXT_KEYS := [
	"cstrike_dir",
	"dir",
	"directory",
	"half_life_dir",
	"path",
	"root",
	"roots",
	"resolved_path",
	"search_roots",
	"source_path",
	"tried",
	"valve_dir",
]


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var options := _parse_args()
	if bool(options.get("help", false)):
		_print_usage()
		return 0

	var catalog_path := str(options.get("catalog", DEFAULT_CATALOG_PATH))
	if bool(options.get("synthetic_smoke", false)):
		return _run_synthetic_smoke(catalog_path, bool(options.get("summary_only", false)))

	return _run_local_config(
		catalog_path,
		str(options.get("config", OpenStrikeGoldSrcLocalConfigRef.DEFAULT_CONFIG_PATH)),
		bool(options.get("summary_only", false))
	)


func _run_local_config(catalog_path: String, config_path: String, summary_only: bool) -> int:
	var manager = OpenStrikeAssetManagerRef.new()
	manager.configure_from_config_path(config_path)
	manager.configure_asset_manifest_from_file(catalog_path)

	return _inspect_and_print(manager, catalog_path, config_path, "local_config", summary_only)


func _run_synthetic_smoke(catalog_path: String, summary_only: bool) -> int:
	var catalog := _load_catalog(catalog_path)
	if catalog.is_empty():
		_print_failure("catalog_unavailable", "Cannot load asset catalog for synthetic inspection.", {
			"catalog": _path_label(catalog_path, "<custom-catalog>"),
		})
		return 1

	var root := ProjectSettings.globalize_path("user://asset_catalog_inspect_local_synthetic").simplify_path()
	_prepare_synthetic_install(root, catalog)

	var config = OpenStrikeGoldSrcLocalConfigRef.new()
	config.configure_from_dictionary({
		"cstrike_dir": root.path_join("cstrike"),
		"valve_dir": root.path_join("valve"),
	}, "asset_catalog_inspect_local_synthetic")

	var manager = OpenStrikeAssetManagerRef.new()
	manager.configure_from_local_config(config)
	manager.configure_asset_manifest_from_file(catalog_path)

	return _inspect_and_print(manager, catalog_path, "<synthetic>", "synthetic_smoke", summary_only)


func _inspect_and_print(manager, catalog_path: String, config_path: String, mode: String, summary_only: bool) -> int:
	var report = manager.inspect_manifest()
	var manager_diagnostics: Array = manager.get_diagnostics()
	var output := _sanitize_report(report.to_dictionary(), catalog_path, config_path, mode, manager_diagnostics)
	if summary_only:
		output.erase("entries")
	print(JSON.stringify(output))

	if _has_errors(manager_diagnostics) or _has_errors(report.diagnostics):
		return 1
	if not report.is_complete():
		return 2
	return 0


func _parse_args() -> Dictionary:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()

	var options := {
		"catalog": DEFAULT_CATALOG_PATH,
		"config": OpenStrikeGoldSrcLocalConfigRef.DEFAULT_CONFIG_PATH,
		"synthetic_smoke": false,
		"summary_only": false,
		"help": false,
	}

	var index := 0
	while index < args.size():
		var arg := str(args[index])
		if arg == "--":
			index += 1
			continue
		if arg == "--synthetic-smoke":
			options["synthetic_smoke"] = true
		elif arg == "--summary-only":
			options["summary_only"] = true
		elif arg == "--help" or arg == "-h":
			options["help"] = true
		elif arg.begins_with("--catalog="):
			options["catalog"] = arg.trim_prefix("--catalog=")
		elif arg == "--catalog" and index + 1 < args.size():
			index += 1
			options["catalog"] = str(args[index])
		elif arg.begins_with("--config="):
			options["config"] = arg.trim_prefix("--config=")
		elif arg == "--config" and index + 1 < args.size():
			index += 1
			options["config"] = str(args[index])
		index += 1

	return options


func _print_usage() -> void:
	print("Usage: Godot --headless --path . --script res://src/dev/tools/asset_catalog_inspect_local.gd -- [--config=user://local_goldsrc.json] [--catalog=res://data/assets/cs16_pilot_weapon_assets.json] [--summary-only]")
	print("       Add --synthetic-smoke to validate the tool against synthetic user:// fixtures.")


func _load_catalog(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
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
		_write_text(file_path, "synthetic local inspection fixture for %s" % str(raw_asset_id))


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)


func _sanitize_report(report: Dictionary, catalog_path: String, config_path: String, mode: String, manager_diagnostics: Array) -> Dictionary:
	return {
		"tool": TOOL_NAME,
		"mode": mode,
		"catalog": _path_label(catalog_path, "<custom-catalog>"),
		"config": _path_label(config_path, "<custom-config>"),
		"source_path": _path_label(str(report.get("source_path", "")), "<custom-catalog>"),
		"metadata": report.get("metadata", {}),
		"total": int(report.get("total", 0)),
		"resolved": int(report.get("resolved", 0)),
		"missing": int(report.get("missing", 0)),
		"invalid": int(report.get("invalid", 0)),
		"type_counts": report.get("type_counts", {}),
		"complete": bool(report.get("complete", false)),
		"entries": _sanitize_entries(report.get("entries", [])),
		"diagnostics": _sanitize_diagnostics(report.get("diagnostics", [])),
		"manager_diagnostics": _sanitize_diagnostics(manager_diagnostics),
	}


func _sanitize_entries(entries) -> Array:
	var sanitized: Array = []
	if not entries is Array:
		return sanitized

	for raw_entry in entries:
		if not raw_entry is Dictionary:
			continue

		sanitized.append({
			"asset_id": str(raw_entry.get("asset_id", "")),
			"type": str(raw_entry.get("type", "")),
			"provider": str(raw_entry.get("provider", "")),
			"relative_path": str(raw_entry.get("relative_path", "")),
			"normalized_path": str(raw_entry.get("normalized_path", "")),
			"found": bool(raw_entry.get("found", false)),
			"loaded": bool(raw_entry.get("loaded", false)),
			"resolved": bool(raw_entry.get("resolved", false)),
			"bytes": int(raw_entry.get("bytes", 0)),
			"metadata": raw_entry.get("metadata", {}),
			"diagnostics": _sanitize_diagnostics(raw_entry.get("diagnostics", [])),
		})

	return sanitized


func _sanitize_diagnostics(entries) -> Array:
	var sanitized: Array = []
	if not entries is Array:
		return sanitized

	for raw_entry in entries:
		if not raw_entry is Dictionary:
			continue

		sanitized.append({
			"level": str(raw_entry.get("level", "")),
			"code": str(raw_entry.get("code", "")),
			"message": str(raw_entry.get("message", "")),
			"context": _sanitize_context(raw_entry.get("context", {})),
		})

	return sanitized


func _sanitize_context(context) -> Dictionary:
	var sanitized := {}
	if not context is Dictionary:
		return sanitized

	for key in context.keys():
		var key_text := str(key)
		if SENSITIVE_CONTEXT_KEYS.has(key_text):
			continue
		sanitized[key_text] = context[key]

	return sanitized


func _path_label(path: String, fallback: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://") or path.begins_with("<"):
		return path
	if path == "":
		return ""
	return fallback


func _has_errors(entries: Array) -> bool:
	for entry in entries:
		if entry is Dictionary and str(entry.get("level", "")) == "error":
			return true
	return false


func _print_failure(code: String, message: String, context: Dictionary) -> void:
	print(JSON.stringify({
		"tool": TOOL_NAME,
		"complete": false,
		"diagnostics": [{
			"level": "error",
			"code": code,
			"message": message,
			"context": context,
		}],
	}))
