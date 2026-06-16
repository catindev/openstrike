extends SceneTree

const OpenStrikeGoldSrcVFSRef = preload("res://src/core/assets/goldsrc_vfs.gd")


func _init() -> void:
	quit(_run())


func _run() -> int:
	var root := ProjectSettings.globalize_path("user://vfs_list_files_smoke").simplify_path()
	_prepare_tree(root)

	var vfs = OpenStrikeGoldSrcVFSRef.new()
	vfs.configure([root.path_join("cstrike"), root.path_join("valve")])
	if not _assert(vfs.is_available(), "vfs should be available with prepared roots", vfs.get_diagnostics()):
		return 1

	var maps := vfs.list_files("maps", ["bsp"])
	var names := _names(maps)

	# Extension filter: only .bsp, never the stray .txt.
	if not _assert(not names.has("readme.txt"), "list_files should filter by extension", names):
		return 1
	# Case-insensitive directory + filename, deduped across roots by filename.
	if not _assert(names.has("de_dust2.bsp"), "list_files should find cstrike map via case-insensitive MAPS dir", names):
		return 1
	if not _assert(names.has("cs_assault.bsp"), "list_files should find valve-root map", names):
		return 1
	if not _assert(names.count("de_dust2.bsp") == 1, "list_files should dedupe same map name across roots", names):
		return 1
	# Natural case-insensitive sort.
	if not _assert(names == ["cs_assault.bsp", "de_dust2.bsp"], "list_files should sort results naturally", names):
		return 1
	# Relative path is usable by the resolver downstream.
	if not _assert(str(maps[1].get("relative_path", "")) == "maps/de_dust2.bsp", "list_files should report resolver-ready relative paths", maps):
		return 1
	# Empty / invalid inputs stay safe.
	if not _assert(vfs.list_files("", ["bsp"]).is_empty(), "empty dir should return no files", null):
		return 1
	if not _assert(vfs.list_files("../escape", ["bsp"]).is_empty(), "parent traversal should return no files", null):
		return 1

	print("VFS list_files smoke passed.")
	return 0


func _prepare_tree(root: String) -> void:
	DirAccess.make_dir_recursive_absolute(root.path_join("cstrike/maps"))
	DirAccess.make_dir_recursive_absolute(root.path_join("valve/maps"))
	# Mixed case dir + file to prove case-insensitive resolution.
	DirAccess.make_dir_recursive_absolute(root.path_join("valve/MAPS"))

	_write(root.path_join("cstrike/maps/de_dust2.bsp"), "")
	_write(root.path_join("cstrike/maps/readme.txt"), "")
	# Same map name in valve root must be deduped, not duplicated.
	_write(root.path_join("valve/maps/DE_DUST2.bsp"), "")
	_write(root.path_join("valve/MAPS/cs_assault.bsp"), "")


func _names(entries: Array) -> Array:
	var output: Array = []
	for entry in entries:
		if entry is Dictionary:
			output.append(str(entry.get("name", "")).to_lower())
	return output


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
