extends RefCounted

class_name GoldSrcVFS

const AssetDiagnosticsRef = preload("res://src/core/assets/asset_diagnostics.gd")

var search_roots: Array[String] = []
var diagnostics: Array[Dictionary] = []


func configure(roots: Array[String]) -> void:
	search_roots.clear()
	diagnostics.clear()

	for root in roots:
		var normalized := _normalize_root(root)
		if normalized == "":
			continue
		if not DirAccess.dir_exists_absolute(normalized):
			diagnostics.append(AssetDiagnosticsRef.warning(
				"vfs_root_missing",
				"Configured VFS root does not exist.",
				{"root": normalized}
			))
			continue
		if not search_roots.has(normalized):
			search_roots.append(normalized)


func is_available() -> bool:
	return not search_roots.is_empty()


func normalize_relative_path(path: String) -> String:
	var normalized := path.strip_edges().replace("\\", "/")

	if normalized == "":
		return ""
	if normalized.contains("://") or normalized.begins_with("/") or _looks_like_windows_absolute_path(normalized):
		return ""

	while normalized.begins_with("./"):
		normalized = normalized.substr(2)

	var output: Array[String] = []
	for part in normalized.split("/", false):
		var clean_part := String(part).strip_edges()
		if clean_part == "" or clean_part == ".":
			continue
		if clean_part == "..":
			return ""
		output.append(clean_part.to_lower())

	return "/".join(output)


func resolve(relative_path: String) -> Dictionary:
	var normalized := normalize_relative_path(relative_path)
	var result := {
		"found": false,
		"requested_path": relative_path,
		"normalized_path": normalized,
		"resolved_path": "",
		"root": "",
		"tried": [],
		"diagnostics": [],
	}

	if normalized == "":
		result["diagnostics"].append(AssetDiagnosticsRef.error(
			"vfs_invalid_relative_path",
			"GoldSrc VFS paths must be non-empty relative paths without parent traversal.",
			{"requested_path": relative_path}
		))
		return result

	if search_roots.is_empty():
		result["diagnostics"].append(AssetDiagnosticsRef.error(
			"vfs_no_roots",
			"GoldSrc VFS has no configured search roots.",
			{"requested_path": relative_path}
		))
		return result

	for root in search_roots:
		result["tried"].append(root.path_join(normalized))
		var resolved_path := _resolve_case_insensitive(root, normalized)
		if resolved_path != "":
			result["found"] = true
			result["resolved_path"] = resolved_path
			result["root"] = root
			return result

	result["diagnostics"].append(AssetDiagnosticsRef.warning(
		"vfs_asset_missing",
		"GoldSrc VFS could not resolve the requested file.",
		{"requested_path": relative_path, "normalized_path": normalized, "tried": result["tried"]}
	))
	return result


func file_exists(relative_path: String) -> bool:
	return bool(resolve(relative_path).get("found", false))


func read_file_bytes(relative_path: String) -> PackedByteArray:
	var resolved := resolve(relative_path)
	if not bool(resolved.get("found", false)):
		return PackedByteArray()
	var file := FileAccess.open(str(resolved["resolved_path"]), FileAccess.READ)
	if file == null:
		diagnostics.append(AssetDiagnosticsRef.error(
			"vfs_read_failed",
			"Resolved GoldSrc file could not be opened.",
			{"resolved_path": resolved["resolved_path"], "error": FileAccess.get_open_error()}
		))
		return PackedByteArray()
	return file.get_buffer(file.get_length())


func get_diagnostics() -> Array[Dictionary]:
	return diagnostics.duplicate(true)


func _resolve_case_insensitive(root: String, normalized_path: String) -> String:
	var current := root
	var parts := normalized_path.split("/", false)

	for part_index in range(parts.size()):
		var wanted := String(parts[part_index])
		var is_last := part_index == parts.size() - 1

		var matched := _find_case_insensitive_child(current, wanted, is_last)
		if matched == "":
			return ""
		current = current.path_join(matched)

	if FileAccess.file_exists(current):
		return current
	return ""


func _find_case_insensitive_child(directory_path: String, wanted: String, final_part: bool) -> String:
	var dir := DirAccess.open(directory_path)
	if dir == null:
		return ""

	var wanted_lower := wanted.to_lower()
	var matches: Array[String] = []

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with(".") and entry.to_lower() == wanted_lower:
			var child_path := directory_path.path_join(entry)
			if final_part and FileAccess.file_exists(child_path):
				matches.append(entry)
			elif not final_part and DirAccess.dir_exists_absolute(child_path):
				matches.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()

	if matches.size() > 1:
		diagnostics.append(AssetDiagnosticsRef.warning(
			"vfs_ambiguous_case_match",
			"Multiple files or directories match a GoldSrc path case-insensitively.",
			{"directory": directory_path, "wanted": wanted, "matches": matches}
		))

	if matches.is_empty():
		return ""
	return matches[0]


static func _normalize_root(root) -> String:
	var normalized := str(root).strip_edges()
	if normalized == "":
		return ""
	if normalized.begins_with("user://") or normalized.begins_with("res://"):
		normalized = ProjectSettings.globalize_path(normalized)
	return normalized.simplify_path()


static func _looks_like_windows_absolute_path(path: String) -> bool:
	return path.length() > 2 and path.substr(1, 1) == ":"
