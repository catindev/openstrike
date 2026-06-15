extends RefCounted

class_name OpenStrikeTraceBackend

const CollisionTraceRef = preload("res://src/core/collision/openstrike_collision_trace.gd")

const SOURCE_NONE := "none"
const SOURCE_GODOT_SCENE := "godot_scene_collision"
const SOURCE_GOLDSRC_HULL_TRACE := "goldsrc_hull_trace"

const CONFIDENCE_UNAVAILABLE := "unavailable"
const CONFIDENCE_GODOT_COLLISION_UNVERIFIED := "godot_collision_unverified"

const CAP_DEFERRED := "deferred"
const CAP_REQUIRES_WORLD_3D := "requires_world_3d"
const CAP_REQUIRES_OPENSTRIKE_BSP_READER := "requires_openstrike_bsp_reader"
const CAP_SUPPORTED_BY_GODOT_SPACE_STATE := "supported_by_godot_space_state"


func capabilities() -> Dictionary:
	return {
		"source": SOURCE_NONE,
		"confidence": CONFIDENCE_UNAVAILABLE,
		"goldsrc_parity": false,
		"trace_ray": CAP_DEFERRED,
		"trace_hull": CAP_REQUIRES_OPENSTRIKE_BSP_READER,
		"point_contents": CAP_REQUIRES_OPENSTRIKE_BSP_READER,
	}


func trace_ray(start: Vector3, end: Vector3, collision_mask: int = 0xFFFFFFFF):
	var trace = _new_trace(start, end, SOURCE_NONE, CONFIDENCE_UNAVAILABLE, false)
	trace.mark_unsupported("base_trace_backend_has_no_runtime", CAP_DEFERRED)
	return trace


func trace_hull(start: Vector3, end: Vector3, hull, collision_mask: int = 0xFFFFFFFF):
	var trace = _new_trace(start, end, SOURCE_NONE, CONFIDENCE_UNAVAILABLE, false)
	trace.mark_unsupported("goldsrc_hull_trace_requires_openstrike_bsp_reader", CAP_REQUIRES_OPENSTRIKE_BSP_READER)
	if hull != null and hull.has_method("to_dictionary"):
		trace.metadata["hull"] = hull.call("to_dictionary")
	return trace


func point_contents(position: Vector3, collision_mask: int = 0xFFFFFFFF) -> Dictionary:
	return {
		"supported": false,
		"source": SOURCE_NONE,
		"confidence": CONFIDENCE_UNAVAILABLE,
		"goldsrc_parity": false,
		"status": "unsupported",
		"contents": "unknown",
		"position": _vector_to_array(position),
		"capability": CAP_REQUIRES_OPENSTRIKE_BSP_READER,
	}


func _new_trace(start: Vector3, end: Vector3, trace_source: String, trace_confidence: String, parity: bool):
	var trace = CollisionTraceRef.new()
	trace.setup(start, end, trace_source, trace_confidence, parity)
	return trace


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
