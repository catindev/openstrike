extends "res://src/core/collision/openstrike_trace_backend.gd"

class_name OpenStrikeBspClipnodeTraceBackend

const CollisionLumpsRef = preload("res://src/core/bsp/bsp_collision_lumps.gd")
const HullRef = preload("res://src/core/collision/openstrike_collision_hull.gd")

const HULL_EXTENT_CONTRACT_RUNTIME_PLANE_OFFSET := "runtime_plane_offset_point_space"
const MODEL_INDEX_WORLD := 0

var _map_resource = null
var _hull_extent_contract := HULL_EXTENT_CONTRACT_RUNTIME_PLANE_OFFSET


func setup(map_resource, hull_extent_contract: String = HULL_EXTENT_CONTRACT_RUNTIME_PLANE_OFFSET) -> void:
	_map_resource = map_resource
	_hull_extent_contract = hull_extent_contract


func capabilities() -> Dictionary:
	return {
		"source": SOURCE_GOLDSRC_HULL_TRACE,
		"confidence": CONFIDENCE_SYNTHETIC_VERIFIED,
		"goldsrc_parity": false,
		"goldsrc_parity_scope": "synthetic_clipnode_fixture_only",
		"trace_ray": CAP_DEFERRED,
		"trace_hull": CAP_SUPPORTED_BY_SYNTHETIC_BSP_FIXTURE if _map_resource != null else CAP_REQUIRES_OPENSTRIKE_BSP_READER,
		"point_contents": CAP_DEFERRED,
		"hull_extent_contract": _hull_extent_contract,
		"model_scope": "model_0_only",
	}


func trace_hull(start: Vector3, end: Vector3, hull, collision_mask: int = 0xFFFFFFFF):
	var trace = _new_trace(start, end, SOURCE_GOLDSRC_HULL_TRACE, CONFIDENCE_SYNTHETIC_VERIFIED, false)
	trace.metadata["goldsrc_parity_scope"] = "synthetic_clipnode_fixture_only"
	trace.metadata["hull_extent_contract"] = _hull_extent_contract
	trace.metadata["model_scope"] = "model_0_only"
	if hull != null and hull.has_method("to_dictionary"):
		trace.metadata["hull"] = hull.call("to_dictionary")

	if _map_resource == null:
		trace.mark_unsupported("bsp_clipnode_trace_requires_bsp_map_resource", CAP_REQUIRES_OPENSTRIKE_BSP_READER)
		return trace
	if _map_resource.models.is_empty():
		trace.mark_unsupported("bsp_clipnode_trace_requires_model_0", CAP_SUPPORTED_BY_SYNTHETIC_BSP_FIXTURE)
		return trace

	var diagnostics: Array[Dictionary] = []
	var hull_index := _hull_index(hull)
	var headnode: int = _map_resource.model_headnode(MODEL_INDEX_WORLD, hull_index)
	if headnode < 0 or _map_resource.clipnodes.is_empty():
		trace.metadata["reason"] = "model_has_no_clipnode_tree_for_hull"
		trace.metadata["diagnostics"] = [{
			"severity": "warning",
			"code": "empty_clipnodes_non_solid",
			"lump": "CLIPNODES",
			"field": "headnode[%d]" % hull_index,
			"message": "Empty or missing clipnodes make the model non-solid; no fallback to headnode[0].",
			"expected": "clipnode tree for requested hull",
			"actual": {"headnode": headnode, "clipnodes": _map_resource.clipnodes.size()},
		}]
		return trace

	var extents := _hull_extents(hull)
	var start_contents := _contents_at(headnode, start, extents, diagnostics)
	if _has_diagnostic_errors(diagnostics):
		_mark_trace_diagnostic(trace, diagnostics)
		return trace

	if _is_blocking_contents(start_contents):
		var end_contents := _contents_at(headnode, end, extents, diagnostics)
		if _has_diagnostic_errors(diagnostics):
			_mark_trace_diagnostic(trace, diagnostics)
			return trace
		trace.status = CollisionTraceRef.STATUS_HIT
		trace.fraction = 0.0
		trace.hit_position = start
		trace.normal = Vector3.ZERO
		trace.start_solid = true
		trace.all_solid = _is_blocking_contents(end_contents)
		trace.contents = _contents_name(start_contents)
		trace.contents_code = start_contents
		trace.model_index = MODEL_INDEX_WORLD
		trace.metadata["contents_code"] = start_contents
		if not diagnostics.is_empty():
			trace.metadata["diagnostics"] = diagnostics
		return trace

	var result := _trace_node(headnode, start, end, 0.0, 1.0, extents, Vector3.ZERO, diagnostics)
	if _has_diagnostic_errors(diagnostics) or bool(result.get("invalid", false)):
		_mark_trace_diagnostic(trace, diagnostics)
		return trace

	if bool(result.get("hit", false)):
		var fraction := float(result.get("fraction", 1.0))
		trace.status = CollisionTraceRef.STATUS_HIT
		trace.fraction = fraction
		trace.hit_position = start.lerp(end, fraction)
		trace.normal = result.get("normal", Vector3.ZERO)
		var contents_code := int(result.get("contents", CollisionLumpsRef.CONTENTS_SOLID))
		trace.contents = _contents_name(contents_code)
		trace.contents_code = contents_code
		trace.model_index = MODEL_INDEX_WORLD
		trace.metadata["contents_code"] = contents_code
	return trace


func point_contents(position: Vector3, collision_mask: int = 0xFFFFFFFF) -> Dictionary:
	return {
		"supported": false,
		"source": SOURCE_GOLDSRC_HULL_TRACE,
		"confidence": CONFIDENCE_SYNTHETIC_VERIFIED,
		"goldsrc_parity": false,
		"status": "unsupported",
		"contents": "unknown",
		"position": _vector_to_array(position),
		"capability": CAP_DEFERRED,
		"reason": "BSP clipnode point_contents remains deferred; PR-08C only exposes synthetic trace_hull selection.",
		"goldsrc_parity_scope": "synthetic_clipnode_fixture_only",
	}


func _trace_node(
	node_index: int,
	p1: Vector3,
	p2: Vector3,
	t1: float,
	t2: float,
	extents: Vector3,
	entry_normal: Vector3,
	diagnostics: Array[Dictionary]
) -> Dictionary:
	if node_index < 0:
		if _is_blocking_contents(node_index):
			return {
				"hit": true,
				"fraction": t1,
				"normal": entry_normal,
				"contents": node_index,
			}
		return {"hit": false}

	if node_index >= _map_resource.clipnodes.size():
		_add_trace_diagnostic(diagnostics, "invalid_clipnode_index", "CLIPNODES", "node_index", "Clipnode index is outside the parsed clipnode array.", "0..%d" % (_map_resource.clipnodes.size() - 1), node_index)
		return {"invalid": true}

	var clipnode: Dictionary = _map_resource.clipnodes[node_index]
	var planenum := int(clipnode.get("planenum", -1))
	if planenum < 0 or planenum >= _map_resource.planes.size():
		_add_trace_diagnostic(diagnostics, "invalid_planenum", "CLIPNODES", "planenum", "Clipnode planenum is outside the parsed plane array.", "0..%d" % (_map_resource.planes.size() - 1), planenum)
		return {"invalid": true}

	var plane: Dictionary = _map_resource.planes[planenum]
	var normal: Vector3 = plane.get("normal", Vector3.ZERO)
	var dist := float(plane.get("dist", 0.0))
	var offset := _plane_offset(normal, extents)
	var d1 := normal.dot(p1) - dist - offset
	var d2 := normal.dot(p2) - dist - offset
	var children: Array = clipnode.get("children", [])
	if children.size() < 2:
		_add_trace_diagnostic(diagnostics, "clipnode_children_missing", "CLIPNODES", "children", "Clipnode must contain two children.", 2, children.size())
		return {"invalid": true}

	if d1 >= 0.0 and d2 >= 0.0:
		return _trace_child(int(children[0]), p1, p2, t1, t2, extents, entry_normal, diagnostics)
	if d1 < 0.0 and d2 < 0.0:
		return _trace_child(int(children[1]), p1, p2, t1, t2, extents, entry_normal, diagnostics)

	var frac := clampf(d1 / (d1 - d2), 0.0, 1.0)
	var mid := p1.lerp(p2, frac)
	var mid_t := lerpf(t1, t2, frac)
	var near_child := int(children[0]) if d1 >= 0.0 else int(children[1])
	var far_child := int(children[1]) if d1 >= 0.0 else int(children[0])
	var crossing_normal := normal if d1 >= 0.0 else -normal

	var near_result := _trace_child(near_child, p1, mid, t1, mid_t, extents, entry_normal, diagnostics)
	if bool(near_result.get("invalid", false)) or bool(near_result.get("hit", false)):
		return near_result
	return _trace_child(far_child, mid, p2, mid_t, t2, extents, crossing_normal, diagnostics)


func _trace_child(
	child: int,
	p1: Vector3,
	p2: Vector3,
	t1: float,
	t2: float,
	extents: Vector3,
	entry_normal: Vector3,
	diagnostics: Array[Dictionary]
) -> Dictionary:
	if child >= _map_resource.clipnodes.size():
		_add_trace_diagnostic(diagnostics, "invalid_child_index", "CLIPNODES", "children", "Clipnode child index is outside the parsed clipnode array.", "leaf contents code or 0..%d" % (_map_resource.clipnodes.size() - 1), child)
		return {"invalid": true}
	return _trace_node(child, p1, p2, t1, t2, extents, entry_normal, diagnostics)


func _contents_at(node_index: int, position: Vector3, extents: Vector3, diagnostics: Array[Dictionary]) -> int:
	var current := node_index
	var guard := 0
	while current >= 0:
		if current >= _map_resource.clipnodes.size():
			_add_trace_diagnostic(diagnostics, "invalid_clipnode_index", "CLIPNODES", "node_index", "Clipnode index is outside the parsed clipnode array.", "0..%d" % (_map_resource.clipnodes.size() - 1), current)
			return CollisionLumpsRef.CONTENTS_EMPTY
		var clipnode: Dictionary = _map_resource.clipnodes[current]
		var planenum := int(clipnode.get("planenum", -1))
		if planenum < 0 or planenum >= _map_resource.planes.size():
			_add_trace_diagnostic(diagnostics, "invalid_planenum", "CLIPNODES", "planenum", "Clipnode planenum is outside the parsed plane array.", "0..%d" % (_map_resource.planes.size() - 1), planenum)
			return CollisionLumpsRef.CONTENTS_EMPTY
		var plane: Dictionary = _map_resource.planes[planenum]
		var normal: Vector3 = plane.get("normal", Vector3.ZERO)
		var dist := float(plane.get("dist", 0.0))
		var offset := _plane_offset(normal, extents)
		var signed_distance := normal.dot(position) - dist - offset
		var children: Array = clipnode.get("children", [])
		if children.size() < 2:
			_add_trace_diagnostic(diagnostics, "clipnode_children_missing", "CLIPNODES", "children", "Clipnode must contain two children.", 2, children.size())
			return CollisionLumpsRef.CONTENTS_EMPTY
		var chosen_child := int(children[0]) if signed_distance >= 0.0 else int(children[1])
		if chosen_child >= _map_resource.clipnodes.size():
			_add_trace_diagnostic(diagnostics, "invalid_child_index", "CLIPNODES", "children", "Clipnode child index is outside the parsed clipnode array.", "leaf contents code or 0..%d" % (_map_resource.clipnodes.size() - 1), chosen_child)
			return CollisionLumpsRef.CONTENTS_EMPTY
		current = chosen_child
		guard += 1
		if guard > _map_resource.clipnodes.size():
			_add_trace_diagnostic(diagnostics, "clipnode_cycle_detected", "CLIPNODES", "children", "Clipnode tree appears cyclic.", "acyclic tree", guard)
			return CollisionLumpsRef.CONTENTS_EMPTY
	return current


func _hull_index(hull) -> int:
	if hull == null:
		return 0
	var kind := str(hull.get("kind"))
	if kind == HullRef.KIND_PLAYER_STANDING:
		return 1
	if kind == HullRef.KIND_PLAYER_DUCKING:
		return 3
	return 0


func _hull_extents(hull) -> Vector3:
	if hull == null:
		return Vector3.ZERO
	var mins: Vector3 = hull.get("mins")
	var maxs: Vector3 = hull.get("maxs")
	return Vector3(
		max(absf(mins.x), absf(maxs.x)),
		max(absf(mins.y), absf(maxs.y)),
		max(absf(mins.z), absf(maxs.z))
	)


func _plane_offset(normal: Vector3, extents: Vector3) -> float:
	if _hull_extent_contract != HULL_EXTENT_CONTRACT_RUNTIME_PLANE_OFFSET:
		return 0.0
	return absf(normal.x) * extents.x + absf(normal.y) * extents.y + absf(normal.z) * extents.z


func _is_blocking_contents(contents_code: int) -> bool:
	return contents_code == CollisionLumpsRef.CONTENTS_SOLID or contents_code == CollisionLumpsRef.CONTENTS_CLIP


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


func _add_trace_diagnostic(
	diagnostics: Array[Dictionary],
	code: String,
	lump: String,
	field: String,
	message: String,
	expected,
	actual
) -> void:
	diagnostics.append({
		"severity": "error",
		"code": code,
		"lump": lump,
		"field": field,
		"message": message,
		"expected": expected,
		"actual": actual,
	})


func _has_diagnostic_errors(diagnostics: Array[Dictionary]) -> bool:
	for diagnostic in diagnostics:
		if str(diagnostic.get("severity", "")) == "error":
			return true
	return false


func _mark_trace_diagnostic(trace, diagnostics: Array[Dictionary]) -> void:
	trace.mark_unsupported("bsp_clipnode_trace_diagnostic", CAP_SUPPORTED_BY_SYNTHETIC_BSP_FIXTURE)
	trace.metadata["diagnostics"] = diagnostics.duplicate(true)
