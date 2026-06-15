extends "res://src/core/collision/openstrike_trace_backend.gd"

class_name OpenStrikeGodotSceneTraceBackend

var _world: World3D = null


func setup(world: World3D) -> void:
	_world = world


func capabilities() -> Dictionary:
	return {
		"source": SOURCE_GODOT_SCENE,
		"confidence": CONFIDENCE_GODOT_COLLISION_UNVERIFIED,
		"goldsrc_parity": false,
		"trace_ray": CAP_SUPPORTED_BY_GODOT_SPACE_STATE if _world != null else CAP_REQUIRES_WORLD_3D,
		"trace_hull": CAP_REQUIRES_OPENSTRIKE_BSP_READER,
		"point_contents": CAP_REQUIRES_OPENSTRIKE_BSP_READER,
		"note": "Godot scene collision is a temporary walkable-lab backend and is not GoldSrc clipnode/hull parity.",
	}


func trace_ray(start: Vector3, end: Vector3, collision_mask: int = 0xFFFFFFFF):
	var trace = _new_trace(start, end, SOURCE_GODOT_SCENE, CONFIDENCE_GODOT_COLLISION_UNVERIFIED, false)
	if _world == null:
		trace.mark_unsupported("godot_scene_trace_requires_world_3d", CAP_REQUIRES_WORLD_3D)
		return trace

	var query := PhysicsRayQueryParameters3D.create(start, end, collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result := _world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return trace

	trace.mark_hit(result)
	return trace


func trace_hull(start: Vector3, end: Vector3, hull, collision_mask: int = 0xFFFFFFFF):
	var trace = _new_trace(start, end, SOURCE_GODOT_SCENE, CONFIDENCE_GODOT_COLLISION_UNVERIFIED, false)
	trace.mark_unsupported("godot_scene_backend_does_not_provide_goldsrc_hull_trace", CAP_REQUIRES_OPENSTRIKE_BSP_READER)
	if hull != null and hull.has_method("to_dictionary"):
		trace.metadata["hull"] = hull.call("to_dictionary")
	return trace


func point_contents(position: Vector3, collision_mask: int = 0xFFFFFFFF) -> Dictionary:
	return {
		"supported": false,
		"source": SOURCE_GODOT_SCENE,
		"confidence": CONFIDENCE_GODOT_COLLISION_UNVERIFIED,
		"goldsrc_parity": false,
		"status": "unsupported",
		"contents": "unknown",
		"position": _vector_to_array(position),
		"capability": CAP_REQUIRES_OPENSTRIKE_BSP_READER,
		"reason": "point_contents requires a GoldSrc BSP contents/clipnode reader, not imported Godot scene collision.",
	}
