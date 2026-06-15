extends RefCounted

class_name OpenStrikeGoldSrcBspRuntimeProvider

const OpenStrikeAssetDiagnosticsRef = preload("res://src/core/assets/asset_diagnostics.gd")

const PROVIDER_ID := "alanfischer/goldsrc-godot"
const PROVIDER_URL := "https://github.com/alanfischer/goldsrc-godot"
const GOLDSRC_BSP_CLASS := "GoldSrcBSP"
const GOLDSRC_WAD_CLASS := "GoldSrcWAD"

const CAP_SUPPORTED_BY_LOADER_API := "supported_by_loader_api"
const CAP_AVAILABLE_AFTER_IMPORTED_SCENE_INSPECTION := "available_after_imported_scene_inspection"
const CAP_REQUIRES_OPENSTRIKE_BSP_READER := "requires_openstrike_bsp_reader"
const CAP_DEFERRED := "deferred"
const CAP_EXTENSION_MISSING := "extension_missing"

const COLLISION_SOURCE_GODOT_SCENE := "godot_scene_collision"
const COLLISION_SOURCE_GOLDSRC_HULL_TRACE := "goldsrc_hull_trace"

const DEFAULT_WAD_PATHS: Array[String] = [
	"cstrike.wad",
	"halflife.wad",
	"decals.wad",
]


func inspect_capabilities() -> Dictionary:
	var extension_available := _has_class(GOLDSRC_BSP_CLASS)
	var wad_available := _has_class(GOLDSRC_WAD_CLASS)
	var bsp = _instantiate_class(GOLDSRC_BSP_CLASS)
	var wad = _instantiate_class(GOLDSRC_WAD_CLASS)
	var report := {
		"provider": PROVIDER_ID,
		"source_url": PROVIDER_URL,
		"extension_available": extension_available,
		"classes": {
			GOLDSRC_BSP_CLASS: extension_available,
			GOLDSRC_WAD_CLASS: wad_available,
		},
		"bsp_api": _inspect_methods(bsp, [
			"load_bsp",
			"load_bsp_from_data",
			"set_scale_factor",
			"build_mesh",
			"add_wad",
			"set_wad",
			"get_pvs_blob",
			"get_leaf_pvs",
		]),
		"wad_api": _inspect_methods(wad, [
			"load_wad",
		]),
		"coverage_capability": {},
		"collision_contract": {
			"runtime_collision_source": COLLISION_SOURCE_GODOT_SCENE if extension_available else CAP_EXTENSION_MISSING,
			"goldsrc_parity_collision_source": COLLISION_SOURCE_GOLDSRC_HULL_TRACE,
			"goldsrc_hull_trace": CAP_REQUIRES_OPENSTRIKE_BSP_READER,
			"note": "goldsrc-godot imports renderable BSP scenes and Godot collision, but does not expose a GoldSrc clipnode/hull trace API to GDScript.",
		},
	}
	report["coverage_capability"] = _build_coverage_capability(report)
	_free_if_node(bsp)
	_free_if_node(wad)
	return report


func load_map_from_vfs(vfs, relative_map_path: String, scale_factor: float, wad_paths: Array[String] = DEFAULT_WAD_PATHS) -> Dictionary:
	var output := {
		"ok": false,
		"node": null,
		"relative_map_path": _normalize_report_path(relative_map_path),
		"metadata": {},
		"capabilities": inspect_capabilities(),
		"diagnostics": [],
	}

	if not bool(output["capabilities"].get("extension_available", false)):
		output["diagnostics"].append(OpenStrikeAssetDiagnosticsRef.error(
			"goldsrc_bsp_extension_missing",
			"The vendored goldsrc-godot GDExtension is not available; BSP runtime loading cannot run on this platform until the native library is bootstrapped.",
			{"provider": PROVIDER_ID, "source_url": PROVIDER_URL}
		))
		return output

	if vfs == null or not vfs.is_available():
		output["diagnostics"].append(OpenStrikeAssetDiagnosticsRef.error(
			"goldsrc_bsp_vfs_unavailable",
			"BSP runtime loading requires a configured GoldSrc VFS."
		))
		return output

	var resolved_map: Dictionary = vfs.resolve(relative_map_path)
	output["diagnostics"].append_array(_strip_path_diagnostics(resolved_map.get("diagnostics", [])))
	if not bool(resolved_map.get("found", false)):
		output["diagnostics"].append(OpenStrikeAssetDiagnosticsRef.error(
			"goldsrc_bsp_map_missing",
			"GoldSrc BSP map could not be resolved through the VFS.",
			{"relative_path": _normalize_report_path(relative_map_path)}
		))
		return output

	var bsp = _instantiate_class(GOLDSRC_BSP_CLASS)
	if bsp == null:
		output["diagnostics"].append(OpenStrikeAssetDiagnosticsRef.error(
			"goldsrc_bsp_instantiate_failed",
			"GoldSrcBSP class exists but could not be instantiated."
		))
		return output

	if bsp is Node:
		(bsp as Node).name = _node_safe_name("bsp_" + str(resolved_map.get("normalized_path", "map")))

	if bsp.has_method("set_scale_factor"):
		bsp.call("set_scale_factor", scale_factor)

	var referenced_wad_paths := _extract_referenced_wad_paths(str(resolved_map["resolved_path"]))
	var resolved_wad_paths := _merge_wad_paths(wad_paths, referenced_wad_paths)
	var loaded_wads: Array = []
	var wad_reports := _load_wads(vfs, bsp, resolved_wad_paths, loaded_wads)
	output["diagnostics"].append_array(wad_reports["diagnostics"])

	var load_error := int(bsp.call("load_bsp", str(resolved_map["resolved_path"])))
	if load_error != OK:
		_free_if_node(bsp)
		output["diagnostics"].append(OpenStrikeAssetDiagnosticsRef.error(
			"goldsrc_bsp_load_failed",
			"goldsrc-godot failed to load the resolved BSP.",
			{"relative_path": _normalize_report_path(relative_map_path), "error": load_error}
		))
		return output

	bsp.call("build_mesh")
	if bsp is Node:
		(bsp as Node).set_meta("openstrike_loaded_wads", loaded_wads)
		(bsp as Node).set_meta("openstrike_relative_map_path", _normalize_report_path(relative_map_path))
		(bsp as Node).set_meta("openstrike_collision_source", COLLISION_SOURCE_GODOT_SCENE)

	var metadata := _inspect_scene(bsp, _normalize_report_path(relative_map_path), scale_factor)
	metadata["wad_paths"] = wad_reports["wad_paths"]
	metadata["referenced_wad_paths"] = referenced_wad_paths
	metadata["capabilities"] = output["capabilities"]
	metadata["collision_source"] = COLLISION_SOURCE_GODOT_SCENE

	output["ok"] = true
	output["node"] = bsp
	output["metadata"] = metadata
	return output


func default_wad_paths() -> Array[String]:
	return DEFAULT_WAD_PATHS.duplicate()


func _build_coverage_capability(report: Dictionary) -> Dictionary:
	var extension_available := bool(report.get("extension_available", false))
	var bsp_api: Dictionary = report.get("bsp_api", {})
	var wad_api: Dictionary = report.get("wad_api", {})

	return {
		"bsp_scene": CAP_SUPPORTED_BY_LOADER_API if extension_available and _all_true(bsp_api, ["load_bsp", "build_mesh", "set_scale_factor"]) else CAP_EXTENSION_MISSING,
		"entity_metadata": CAP_AVAILABLE_AFTER_IMPORTED_SCENE_INSPECTION if extension_available else CAP_EXTENSION_MISSING,
		"scene_collision": CAP_AVAILABLE_AFTER_IMPORTED_SCENE_INSPECTION if extension_available else CAP_EXTENSION_MISSING,
		"pvs_blob": CAP_SUPPORTED_BY_LOADER_API if extension_available and bool(bsp_api.get("get_pvs_blob", false)) else CAP_EXTENSION_MISSING,
		"wad_textures": CAP_SUPPORTED_BY_LOADER_API if extension_available and bool(bsp_api.get("add_wad", false)) and bool(wad_api.get("load_wad", false)) else CAP_EXTENSION_MISSING,
		"clipnodes": CAP_REQUIRES_OPENSTRIKE_BSP_READER,
		"hull_trace": CAP_REQUIRES_OPENSTRIKE_BSP_READER,
		"hull_sizes": CAP_REQUIRES_OPENSTRIKE_BSP_READER,
		"lightmap_parity_report": CAP_DEFERRED,
	}


func _load_wads(vfs, bsp, wad_paths: Array[String], loaded_wads: Array) -> Dictionary:
	var output := {
		"diagnostics": [],
		"wad_paths": [],
	}

	if not _has_class(GOLDSRC_WAD_CLASS):
		output["diagnostics"].append(OpenStrikeAssetDiagnosticsRef.warning(
			"goldsrc_wad_extension_missing",
			"GoldSrcWAD class is not available; BSP will load without WAD texture injection.",
			{"provider": PROVIDER_ID}
		))
		return output

	for wad_path in wad_paths:
		var relative_path := _normalize_report_path(wad_path)
		var wad_entry := {
			"relative_path": relative_path,
			"found": false,
			"loaded": false,
		}
		var resolved: Dictionary = vfs.resolve(wad_path)
		if not bool(resolved.get("found", false)):
			output["wad_paths"].append(wad_entry)
			continue

		wad_entry["found"] = true
		var wad = _instantiate_class(GOLDSRC_WAD_CLASS)
		if wad == null:
			output["diagnostics"].append(OpenStrikeAssetDiagnosticsRef.warning(
				"goldsrc_wad_instantiate_failed",
				"GoldSrcWAD class exists but could not be instantiated.",
				{"relative_path": relative_path}
			))
			output["wad_paths"].append(wad_entry)
			continue

		var load_error := int(wad.call("load_wad", str(resolved["resolved_path"])))
		if load_error != OK:
			output["diagnostics"].append(OpenStrikeAssetDiagnosticsRef.warning(
				"goldsrc_wad_load_failed",
				"goldsrc-godot failed to load a resolved WAD.",
				{"relative_path": relative_path, "error": load_error}
			))
			_free_if_node(wad)
			output["wad_paths"].append(wad_entry)
			continue

		if bsp.has_method("add_wad"):
			bsp.call("add_wad", wad)
		wad_entry["loaded"] = true
		loaded_wads.append(wad)
		output["wad_paths"].append(wad_entry)

	return output


func _extract_referenced_wad_paths(resolved_bsp_path: String) -> Array[String]:
	var output: Array[String] = []
	var file := FileAccess.open(resolved_bsp_path, FileAccess.READ)
	if file == null:
		return output

	var bytes := file.get_buffer(file.get_length())
	for index in range(bytes.size()):
		var value := int(bytes[index])
		if value < 32 or value > 126:
			bytes[index] = 32
	var text := bytes.get_string_from_ascii().replace("\\", "/")
	var regex := RegEx.new()
	if regex.compile("([A-Za-z0-9_./:-]+\\.wad)") != OK:
		return output

	for match_result in regex.search_all(text):
		var full_path := str(match_result.get_string(1)).strip_edges()
		var filename := full_path.get_file().to_lower()
		if filename == "" or output.has(filename):
			continue
		output.append(filename)
	return output


func _merge_wad_paths(base_paths: Array[String], referenced_paths: Array[String]) -> Array[String]:
	var output: Array[String] = []
	for path in base_paths:
		_append_unique_wad_path(output, path)
	for path in referenced_paths:
		_append_unique_wad_path(output, path)
	return output


func _append_unique_wad_path(paths: Array[String], path: String) -> void:
	var normalized := _normalize_report_path(path).get_file().to_lower()
	if normalized == "" or paths.has(normalized):
		return
	paths.append(normalized)


func _inspect_scene(root, relative_map_path: String, scale_factor: float) -> Dictionary:
	var counts := {
		"nodes": 0,
		"mesh_instances": 0,
		"collision_shapes": 0,
		"static_bodies": 0,
		"animatable_bodies": 0,
		"areas": 0,
		"entity_nodes": 0,
	}
	var class_counts := {}
	var spawn_points: Array[Dictionary] = []
	var entity_classes := {}
	var worldspawn := {}
	var pvs_blob_size := 0

	if root != null and root.has_method("get_pvs_blob"):
		var pvs_blob = root.call("get_pvs_blob")
		if pvs_blob is PackedByteArray:
			pvs_blob_size = pvs_blob.size()

	var stack: Array[Node] = []
	if root is Node:
		stack.append(root as Node)

	while not stack.is_empty():
		var current: Node = stack.pop_back()
		counts["nodes"] = int(counts["nodes"]) + 1
		var current_class := current.get_class()
		class_counts[current_class] = int(class_counts.get(current_class, 0)) + 1

		if current is MeshInstance3D:
			counts["mesh_instances"] = int(counts["mesh_instances"]) + 1
		if current is CollisionShape3D:
			counts["collision_shapes"] = int(counts["collision_shapes"]) + 1
		if current is StaticBody3D:
			counts["static_bodies"] = int(counts["static_bodies"]) + 1
		if current is AnimatableBody3D:
			counts["animatable_bodies"] = int(counts["animatable_bodies"]) + 1
		if current is Area3D:
			counts["areas"] = int(counts["areas"]) + 1

		if current.has_meta("entity"):
			var entity = current.get_meta("entity")
			if entity is Dictionary:
				counts["entity_nodes"] = int(counts["entity_nodes"]) + 1
				var classname := str(entity.get("classname", ""))
				if classname != "":
					entity_classes[classname] = int(entity_classes.get(classname, 0)) + 1
				if classname == "worldspawn":
					worldspawn = _worldspawn_report(entity)
				if ["info_player_start", "info_player_deathmatch"].has(classname):
					spawn_points.append(_spawn_report(current, entity))

		for child in current.get_children():
			if child is Node:
				stack.append(child)

	return {
		"relative_map_path": relative_map_path,
		"scale_factor": scale_factor,
		"scene_counts": counts,
		"class_counts": class_counts,
		"entity_classes": entity_classes,
		"worldspawn": worldspawn,
		"spawn_points": spawn_points,
		"spawn_count": spawn_points.size(),
		"pvs_blob_size": pvs_blob_size,
	}


func _worldspawn_report(entity: Dictionary) -> Dictionary:
	var output := {}
	for key in ["classname", "mapversion", "skyname", "wad", "MaxRange"]:
		if entity.has(key):
			var value := str(entity.get(key, ""))
			output[key] = _sanitize_worldspawn_wad_value(value) if key == "wad" else value
	return output


func _sanitize_worldspawn_wad_value(value: String) -> String:
	var basenames: Array[String] = []
	for raw_path in value.replace("\\", "/").split(";", false):
		var basename := String(raw_path).strip_edges().get_file().to_lower()
		if basename != "" and not basenames.has(basename):
			basenames.append(basename)
	return ";".join(basenames)


func _spawn_report(node: Node, entity: Dictionary) -> Dictionary:
	var position := _node_position(node)
	return {
		"classname": str(entity.get("classname", "")),
		"targetname": str(entity.get("targetname", "")),
		"angles": str(entity.get("angles", "")),
		"origin": str(entity.get("origin", "")),
		"position_godot": _vector_to_array(position),
	}


func _node_position(node: Node) -> Vector3:
	if not node is Node3D:
		return Vector3.ZERO
	var node_3d := node as Node3D
	if node_3d.is_inside_tree():
		return node_3d.global_position
	return node_3d.transform.origin


func _inspect_methods(object, methods: Array[String]) -> Dictionary:
	var result := {}
	for method in methods:
		result[method] = object != null and object.has_method(method)
	return result


func _has_class(class_name_text: String) -> bool:
	return ClassDB.class_exists(class_name_text)


func _instantiate_class(class_name_text: String):
	if not _has_class(class_name_text):
		return null
	return ClassDB.instantiate(class_name_text)


func _all_true(values: Dictionary, keys: Array[String]) -> bool:
	for key in keys:
		if not bool(values.get(key, false)):
			return false
	return true


func _normalize_report_path(path: String) -> String:
	return path.strip_edges().replace("\\", "/").trim_prefix("/")


func _node_safe_name(text: String) -> String:
	return text.replace("/", "_").replace("\\", "_").replace(".", "_").replace(" ", "_")


func _strip_path_diagnostics(diagnostics: Array) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for diagnostic in diagnostics:
		if not diagnostic is Dictionary:
			continue
		var clone: Dictionary = diagnostic.duplicate(true)
		var context = clone.get("context", {})
		if context is Dictionary:
			context.erase("tried")
			context.erase("root")
			context.erase("resolved_path")
			clone["context"] = context
		output.append(clone)
	return output


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _free_if_node(object) -> void:
	if object is Node:
		(object as Node).queue_free()
