extends RefCounted

class_name OpenStrikeGoldSrcLocalConfig

const DEFAULT_CONFIG_PATH := "user://local_goldsrc.json"

const OpenStrikeAssetDiagnosticsRef = preload("res://src/core/assets/asset_diagnostics.gd")

var source_path := ""
var half_life_dir := ""
var cstrike_dir := ""
var valve_dir := ""
var diagnostics: Array[Dictionary] = []


func load_from_file(path: String = DEFAULT_CONFIG_PATH) -> void:
	_reset()
	source_path = path

	if not FileAccess.file_exists(path):
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"local_config_missing",
			"GoldSrc local configuration file is missing.",
			{"path": path}
		))
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"local_config_unreadable",
			"GoldSrc local configuration file cannot be opened.",
			{"path": path, "error": FileAccess.get_open_error()}
		))
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"local_config_invalid_json",
			"GoldSrc local configuration must be a JSON object.",
			{"path": path}
		))
		return

	configure_from_dictionary(parsed, path)


func configure_from_dictionary(data: Dictionary, source: String = "") -> void:
	_reset()
	source_path = source
	half_life_dir = _normalize_dir(data.get("half_life_dir", ""))
	cstrike_dir = _normalize_dir(data.get("cstrike_dir", ""))
	valve_dir = _normalize_dir(data.get("valve_dir", ""))

	if half_life_dir != "":
		if cstrike_dir == "":
			cstrike_dir = half_life_dir.path_join("cstrike").simplify_path()
		if valve_dir == "":
			valve_dir = half_life_dir.path_join("valve").simplify_path()

	_validate()


func is_valid() -> bool:
	return not OpenStrikeAssetDiagnosticsRef.has_errors(diagnostics)


func get_search_roots() -> Array[String]:
	var roots: Array[String] = []
	_append_unique_root(roots, cstrike_dir)
	_append_unique_root(roots, valve_dir)
	_append_unique_root(roots, half_life_dir)
	return roots


func to_dictionary() -> Dictionary:
	return {
		"source_path": source_path,
		"half_life_dir": half_life_dir,
		"cstrike_dir": cstrike_dir,
		"valve_dir": valve_dir,
		"search_roots": get_search_roots(),
		"valid": is_valid(),
		"diagnostics": diagnostics,
	}


func _reset() -> void:
	source_path = ""
	half_life_dir = ""
	cstrike_dir = ""
	valve_dir = ""
	diagnostics.clear()


func _validate() -> void:
	var has_half_life_dir := half_life_dir != ""
	var has_explicit_roots := cstrike_dir != "" and valve_dir != ""

	if not has_half_life_dir and not has_explicit_roots:
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"local_config_roots_missing",
			"GoldSrc local configuration requires half_life_dir or both cstrike_dir and valve_dir.",
			{"source_path": source_path}
		))

	if has_half_life_dir:
		_validate_dir("half_life_dir", half_life_dir)
	_validate_dir("cstrike_dir", cstrike_dir)
	_validate_dir("valve_dir", valve_dir)


func _validate_dir(field_name: String, path: String) -> void:
	if path == "":
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"local_config_path_missing",
			"Required GoldSrc directory path is missing.",
			{"field": field_name, "source_path": source_path}
		))
		return

	if not _is_absolute_path(path):
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.warning(
			"local_config_path_relative",
			"GoldSrc directory paths should be absolute.",
			{"field": field_name, "path": path}
		))

	if not DirAccess.dir_exists_absolute(path):
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"local_config_dir_missing",
			"Configured GoldSrc directory does not exist.",
			{"field": field_name, "path": path}
		))


static func _normalize_dir(value) -> String:
	var path := str(value).strip_edges()
	if path == "":
		return ""
	if path.begins_with("user://") or path.begins_with("res://"):
		path = ProjectSettings.globalize_path(path)
	return path.simplify_path()


static func _is_absolute_path(path: String) -> bool:
	return path.begins_with("/") or path.contains("://") or (path.length() > 2 and path.substr(1, 1) == ":")


static func _append_unique_root(roots: Array[String], root: String) -> void:
	if root == "":
		return
	if not roots.has(root):
		roots.append(root)
