extends SceneTree

const DEFAULT_MAP_PATH := "maps/de_dust2.bsp"
const SYNTHETIC_MAP_PATH := "maps/synthetic_contract_a.bsp"
const TOOL_NAME := "bsp30_real_map_contract_a_inspect"

const AssetManagerRef = preload("res://src/core/assets/asset_manager.gd")
const BspMapResourceRef = preload("res://src/core/bsp/bsp_map_resource.gd")
const CollisionLumpsRef = preload("res://src/core/bsp/bsp_collision_lumps.gd")
const GoldSrcLocalConfigRef = preload("res://src/core/assets/goldsrc_local_config.gd")
const LumpTableRef = preload("res://src/core/bsp/bsp_lump_table.gd")

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
	if bool(options.get("synthetic_smoke", false)):
		return _run_synthetic_smoke(bool(options.get("summary_only", false)))

	return _run_local_config(
		str(options.get("config", GoldSrcLocalConfigRef.DEFAULT_CONFIG_PATH)),
		str(options.get("map", DEFAULT_MAP_PATH)),
		bool(options.get("summary_only", false))
	)


func _run_local_config(config_path: String, map_path: String, summary_only: bool) -> int:
	var manager = AssetManagerRef.new()
	manager.configure_from_config_path(config_path)
	return _inspect_and_print(manager, map_path, config_path, "local_config", summary_only)


func _run_synthetic_smoke(summary_only: bool) -> int:
	var root := ProjectSettings.globalize_path("user://bsp30_real_map_contract_a_synthetic").simplify_path()
	_prepare_synthetic_install(root)

	var config = GoldSrcLocalConfigRef.new()
	config.configure_from_dictionary({
		"cstrike_dir": root.path_join("cstrike"),
		"valve_dir": root.path_join("valve"),
	}, "bsp30_real_map_contract_a_synthetic")

	var manager = AssetManagerRef.new()
	manager.configure_from_local_config(config)
	return _inspect_and_print(manager, SYNTHETIC_MAP_PATH, "<synthetic>", "synthetic_smoke", summary_only)


func _inspect_and_print(manager, map_path: String, config_path: String, mode: String, summary_only: bool) -> int:
	var output := _inspect(manager, map_path, config_path, mode)
	if summary_only:
		output.erase("hulls")
	print(JSON.stringify(output))

	if _has_asset_errors(output.get("manager_diagnostics", [])):
		return 1
	if _has_bsp_errors(output.get("reader", {}).get("diagnostics", [])):
		return 1
	if not bool(output.get("complete", false)):
		return 2
	return 0


func _inspect(manager, map_path: String, config_path: String, mode: String) -> Dictionary:
	var output := {
		"tool": TOOL_NAME,
		"mode": mode,
		"complete": false,
		"config": _path_label(config_path, "<custom-config>"),
		"map": _sanitize_map_path(map_path),
		"asset": {},
		"reader": {},
		"world_model": {},
		"hulls": {},
		"contract_a_assessment": {},
		"manager_diagnostics": _sanitize_asset_diagnostics(manager.get_diagnostics()),
	}

	var resolved: Dictionary = manager.resolve_asset(map_path)
	output["asset"] = _sanitize_resolve_result(resolved)
	if not bool(resolved.get("found", false)):
		output["contract_a_assessment"] = _contract_assessment("map_unavailable", "The requested BSP could not be resolved through the local GoldSrc VFS.")
		return output

	var bytes: PackedByteArray = manager.read_asset_bytes(map_path)
	if bytes.is_empty():
		output["contract_a_assessment"] = _contract_assessment("map_unreadable", "The requested BSP resolved but could not be read as bytes.")
		output["manager_diagnostics"] = _sanitize_asset_diagnostics(manager.get_diagnostics())
		return output

	var map_resource = BspMapResourceRef.new()
	var loaded := map_resource.load_from_bytes(bytes)
	output["reader"] = _reader_report(map_resource, loaded)
	if not loaded or map_resource.has_errors():
		output["contract_a_assessment"] = _contract_assessment("reader_failed", "The BSP30 reader rejected the file or reported errors.")
		return output

	output["world_model"] = _world_model_report(map_resource)
	output["hulls"] = _hull_reports(map_resource)
	output["contract_a_assessment"] = _assess_contract_a(map_resource, output["hulls"])
	output["complete"] = str(output["contract_a_assessment"].get("status", "")) != "reader_failed"
	return output


func _reader_report(map_resource, loaded: bool) -> Dictionary:
	var lump_lengths: Dictionary = {}
	if map_resource.lump_table != null:
		for lump in map_resource.lump_table.lumps:
			lump_lengths[str(lump.get("name", ""))] = int(lump.get("filelen", 0))

	return {
		"loaded": loaded,
		"version": map_resource.version,
		"planes": map_resource.planes.size(),
		"clipnodes": map_resource.clipnodes.size(),
		"models": map_resource.models.size(),
		"has_errors": map_resource.has_errors(),
		"lump_lengths": lump_lengths,
		"diagnostics": _sanitize_bsp_diagnostics(map_resource.diagnostics_to_dictionaries()),
	}


func _world_model_report(map_resource) -> Dictionary:
	if map_resource.models.is_empty():
		return {
			"present": false,
			"headnodes": [],
			"hull_1_present": false,
			"hull_3_present": false,
		}

	var model: Dictionary = map_resource.models[0]
	var headnodes: Array = model.get("headnodes", [])
	return {
		"present": true,
		"headnodes": headnodes.duplicate(true),
		"hull_0_node_head": _headnode_value(headnodes, 0),
		"hull_1_clipnode_head": _headnode_value(headnodes, 1),
		"hull_2_clipnode_head": _headnode_value(headnodes, 2),
		"hull_3_clipnode_head": _headnode_value(headnodes, 3),
		"hull_1_present": _headnode_value(headnodes, 1) >= 0,
		"hull_3_present": _headnode_value(headnodes, 3) >= 0,
		"standing_duck_heads_distinct": _headnode_value(headnodes, 1) != _headnode_value(headnodes, 3),
	}


func _hull_reports(map_resource) -> Dictionary:
	return {
		"standing": _clipnode_tree_report(map_resource, 1),
		"duck": _clipnode_tree_report(map_resource, 3),
	}


func _clipnode_tree_report(map_resource, hull_index: int) -> Dictionary:
	var headnode: int = map_resource.model_headnode(0, hull_index)
	var report := {
		"hull_index": hull_index,
		"headnode": headnode,
		"present": headnode >= 0 and not map_resource.clipnodes.is_empty(),
		"reachable_clipnodes": 0,
		"unique_planes": 0,
		"leaf_contents": {},
		"invalid_references": 0,
		"cycle_detected": false,
		"axis_plane_counts": {
			"x": 0,
			"y": 0,
			"z": 0,
			"other": 0,
		},
		"_visited_nodes": {},
		"_unique_planes": {},
	}
	if headnode < 0 or map_resource.clipnodes.is_empty():
		report.erase("_visited_nodes")
		report.erase("_unique_planes")
		return report

	var stack: Array[int] = [headnode]
	while not stack.is_empty():
		var node_index := int(stack.pop_back())
		if node_index < 0:
			_record_leaf(report, node_index)
			continue
		if node_index >= map_resource.clipnodes.size():
			report["invalid_references"] = int(report.get("invalid_references", 0)) + 1
			continue

		var visited: Dictionary = report.get("_visited_nodes", {})
		var visited_key := str(node_index)
		if visited.has(visited_key):
			continue
		visited[visited_key] = true
		report["_visited_nodes"] = visited

		var clipnode: Dictionary = map_resource.clipnodes[node_index]
		var planenum := int(clipnode.get("planenum", -1))
		if planenum < 0 or planenum >= map_resource.planes.size():
			report["invalid_references"] = int(report.get("invalid_references", 0)) + 1
		else:
			var unique_planes: Dictionary = report.get("_unique_planes", {})
			unique_planes[str(planenum)] = true
			report["_unique_planes"] = unique_planes
			_record_axis_plane(report, map_resource.planes[planenum])

		var children: Array = clipnode.get("children", [])
		if children.size() < 2:
			report["invalid_references"] = int(report.get("invalid_references", 0)) + 1
			continue

		for raw_child in children:
			var child := int(raw_child)
			if child >= 0 and child < map_resource.clipnodes.size():
				if int(report.get("reachable_clipnodes", 0)) > map_resource.clipnodes.size():
					report["cycle_detected"] = true
					continue
				stack.append(child)
			elif child < 0:
				stack.append(child)
			else:
				report["invalid_references"] = int(report.get("invalid_references", 0)) + 1

	var visited_final: Dictionary = report.get("_visited_nodes", {})
	var planes_final: Dictionary = report.get("_unique_planes", {})
	report["reachable_clipnodes"] = visited_final.size()
	report["unique_planes"] = planes_final.size()
	report.erase("_visited_nodes")
	report.erase("_unique_planes")
	return report


func _assess_contract_a(map_resource, hulls) -> Dictionary:
	if map_resource.models.is_empty():
		return _contract_assessment("missing_world_model", "The BSP reader found no model 0, so real-map hull contract verification cannot proceed.")
	if map_resource.clipnodes.is_empty():
		return _contract_assessment("missing_clipnodes", "The BSP reader found no clipnodes; this cannot verify a player hull contract.")

	var world := _world_model_report(map_resource)
	var standing: Dictionary = hulls.get("standing", {})
	var duck: Dictionary = hulls.get("duck", {})
	var standing_present := bool(standing.get("present", false))
	var duck_present := bool(duck.get("present", false))
	var heads_distinct := bool(world.get("standing_duck_heads_distinct", false))
	var standing_nodes := int(standing.get("reachable_clipnodes", 0))
	var duck_nodes := int(duck.get("reachable_clipnodes", 0))

	if not standing_present:
		return _contract_assessment("missing_standing_hull", "Model 0 does not expose a standing hull clipnode tree.")

	var message := "Real BSP30 data exposes model-0 clipnode hulls. PR-08B Contract A remains valid only for synthetic point-space fixtures until a later contact-level real-map verification proves where hull offsets live."
	var assessment_signal := "standing_hull_only"
	if duck_present and heads_distinct:
		assessment_signal = "separate_hull_clipnode_trees_detected"
		message = "Model 0 exposes distinct standing and duck clipnode trees. That is a real-map signal for compiled hull-specific collision data, so OpenStrike must not promote PR-08B runtime plane offsets beyond synthetic fixtures without contact-level verification."
	elif duck_present:
		assessment_signal = "shared_hull_headnode_detected"
		message = "Model 0 exposes standing and duck hull data, but their headnodes are not distinct in this inspection. Keep Contract A synthetic-only until a contact-level real-map check explains the hull-space behavior."

	return {
		"status": "real_map_inspected",
		"signal": assessment_signal,
		"synthetic_contract_a": "runtime_plane_offset_point_space",
		"real_map_promotion": "blocked",
		"standing_reachable_clipnodes": standing_nodes,
		"duck_reachable_clipnodes": duck_nodes,
		"standing_duck_heads_distinct": heads_distinct,
		"message": message,
		"next_action": "Do not use runtime hull extents on real BSP clipnodes until a separate real-map contact diagnostic proves the plane-space contract.",
	}


func _contract_assessment(status: String, message: String) -> Dictionary:
	return {
		"status": status,
		"synthetic_contract_a": "runtime_plane_offset_point_space",
		"real_map_promotion": "blocked",
		"message": message,
	}


func _record_leaf(report: Dictionary, contents_code: int) -> void:
	var leaf_contents: Dictionary = report.get("leaf_contents", {})
	var key := _contents_name(contents_code)
	leaf_contents[key] = int(leaf_contents.get(key, 0)) + 1
	report["leaf_contents"] = leaf_contents


func _record_axis_plane(report: Dictionary, plane: Dictionary) -> void:
	var normal: Vector3 = plane.get("normal", Vector3.ZERO)
	var axis := "other"
	if absf(absf(normal.x) - 1.0) <= 0.001 and absf(normal.y) <= 0.001 and absf(normal.z) <= 0.001:
		axis = "x"
	elif absf(absf(normal.y) - 1.0) <= 0.001 and absf(normal.x) <= 0.001 and absf(normal.z) <= 0.001:
		axis = "y"
	elif absf(absf(normal.z) - 1.0) <= 0.001 and absf(normal.x) <= 0.001 and absf(normal.y) <= 0.001:
		axis = "z"

	var axis_counts: Dictionary = report.get("axis_plane_counts", {})
	axis_counts[axis] = int(axis_counts.get(axis, 0)) + 1
	report["axis_plane_counts"] = axis_counts


func _prepare_synthetic_install(root: String) -> void:
	var cstrike := root.path_join("cstrike")
	var valve := root.path_join("valve")
	DirAccess.make_dir_recursive_absolute(cstrike.path_join("maps"))
	DirAccess.make_dir_recursive_absolute(valve)

	var file_path := cstrike.path_join(SYNTHETIC_MAP_PATH).simplify_path()
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_build_synthetic_bsp30_fixture())


func _build_synthetic_bsp30_fixture() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(LumpTableRef.HEADER_SIZE)
	bytes.encode_s32(0, LumpTableRef.BSP_VERSION)

	var entries: Array[Dictionary] = []
	for index in range(LumpTableRef.HEADER_LUMPS):
		entries.append({"offset": 0, "length": 0})

	_append_lump(bytes, entries, LumpTableRef.LUMP_PLANES, _build_plane_lump())
	_append_lump(bytes, entries, LumpTableRef.LUMP_CLIPNODES, _build_clipnode_lump())
	_append_lump(bytes, entries, LumpTableRef.LUMP_MODELS, _build_model_lump())

	for index in range(entries.size()):
		var header_offset := 4 + index * 8
		bytes.encode_s32(header_offset, int(entries[index].get("offset", 0)))
		bytes.encode_s32(header_offset + 4, int(entries[index].get("length", 0)))
	return bytes


func _build_plane_lump() -> PackedByteArray:
	var bytes := PackedByteArray()
	_append_f32(bytes, 1.0)
	_append_f32(bytes, 0.0)
	_append_f32(bytes, 0.0)
	_append_f32(bytes, 0.0)
	_append_i32(bytes, 0)
	return bytes


func _build_clipnode_lump() -> PackedByteArray:
	var bytes := PackedByteArray()
	_append_i32(bytes, 0)
	_append_i16(bytes, CollisionLumpsRef.CONTENTS_EMPTY)
	_append_i16(bytes, CollisionLumpsRef.CONTENTS_SOLID)
	return bytes


func _build_model_lump() -> PackedByteArray:
	var bytes := PackedByteArray()
	for value in [0.0, 0.0, 0.0]:
		_append_f32(bytes, value)
	for value in [0.0, 0.0, 0.0]:
		_append_f32(bytes, value)
	for value in [0.0, 0.0, 0.0]:
		_append_f32(bytes, value)
	_append_i32(bytes, 0)
	_append_i32(bytes, 0)
	_append_i32(bytes, -1)
	_append_i32(bytes, 0)
	_append_i32(bytes, 0)
	_append_i32(bytes, 0)
	_append_i32(bytes, 0)
	return bytes


func _append_lump(bytes: PackedByteArray, entries: Array[Dictionary], index: int, lump_bytes: PackedByteArray) -> void:
	var offset := bytes.size()
	bytes.append_array(lump_bytes)
	entries[index] = {"offset": offset, "length": lump_bytes.size()}


func _append_i32(bytes: PackedByteArray, value: int) -> void:
	var offset := bytes.size()
	bytes.resize(offset + 4)
	bytes.encode_s32(offset, value)


func _append_i16(bytes: PackedByteArray, value: int) -> void:
	var offset := bytes.size()
	bytes.resize(offset + 2)
	bytes.encode_s16(offset, value)


func _append_f32(bytes: PackedByteArray, value: float) -> void:
	var offset := bytes.size()
	bytes.resize(offset + 4)
	bytes.encode_float(offset, value)


func _parse_args() -> Dictionary:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()

	var options := {
		"config": GoldSrcLocalConfigRef.DEFAULT_CONFIG_PATH,
		"map": DEFAULT_MAP_PATH,
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
		elif arg.begins_with("--config="):
			options["config"] = arg.trim_prefix("--config=")
		elif arg == "--config" and index + 1 < args.size():
			index += 1
			options["config"] = str(args[index])
		elif arg.begins_with("--map="):
			options["map"] = arg.trim_prefix("--map=")
		elif arg == "--map" and index + 1 < args.size():
			index += 1
			options["map"] = str(args[index])
		index += 1

	return options


func _print_usage() -> void:
	print("Usage: Godot --headless --path . --script res://src/dev/tools/bsp30_real_map_contract_a_inspect.gd -- [--config=user://local_goldsrc.json] [--map=maps/de_dust2.bsp] [--summary-only]")
	print("       Add --synthetic-smoke to validate the tool against synthetic user:// fixtures.")


func _sanitize_resolve_result(result: Dictionary) -> Dictionary:
	return {
		"requested_path": _sanitize_map_path(str(result.get("requested_path", ""))),
		"normalized_path": str(result.get("normalized_path", "")),
		"found": bool(result.get("found", false)),
		"diagnostics": _sanitize_asset_diagnostics(result.get("diagnostics", [])),
	}


func _sanitize_asset_diagnostics(entries) -> Array:
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


func _sanitize_bsp_diagnostics(entries) -> Array:
	var sanitized: Array = []
	if not entries is Array:
		return sanitized

	for raw_entry in entries:
		if not raw_entry is Dictionary:
			continue
		sanitized.append({
			"severity": str(raw_entry.get("severity", "")),
			"code": str(raw_entry.get("code", "")),
			"lump": str(raw_entry.get("lump", "")),
			"field": str(raw_entry.get("field", "")),
			"message": str(raw_entry.get("message", "")),
			"expected": raw_entry.get("expected", null),
			"actual": raw_entry.get("actual", null),
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


func _sanitize_map_path(path: String) -> String:
	var normalized := path.strip_edges().replace("\\", "/")
	if normalized.contains("://") or normalized.begins_with("/") or _looks_like_windows_absolute_path(normalized):
		return "<custom-map>"
	return normalized


func _path_label(path: String, fallback: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://") or path.begins_with("<"):
		return path
	if path == "":
		return ""
	return fallback


func _headnode_value(headnodes: Array, index: int) -> int:
	if index < 0 or index >= headnodes.size():
		return -1
	return int(headnodes[index])


func _contents_name(contents_code: int) -> String:
	match contents_code:
		CollisionLumpsRef.CONTENTS_EMPTY:
			return "empty"
		CollisionLumpsRef.CONTENTS_SOLID:
			return "solid"
		CollisionLumpsRef.CONTENTS_WATER:
			return "water"
		CollisionLumpsRef.CONTENTS_SLIME:
			return "slime"
		CollisionLumpsRef.CONTENTS_LAVA:
			return "lava"
		CollisionLumpsRef.CONTENTS_SKY:
			return "sky"
		CollisionLumpsRef.CONTENTS_CLIP:
			return "clip"
		_:
			return "contents_%d" % contents_code


func _has_asset_errors(entries) -> bool:
	if not entries is Array:
		return false
	for entry in entries:
		if entry is Dictionary and str(entry.get("level", "")) == "error":
			return true
	return false


func _has_bsp_errors(entries) -> bool:
	if not entries is Array:
		return false
	for entry in entries:
		if entry is Dictionary and str(entry.get("severity", "")) == "error":
			return true
	return false


func _looks_like_windows_absolute_path(path: String) -> bool:
	return path.length() > 2 and path.substr(1, 1) == ":"
