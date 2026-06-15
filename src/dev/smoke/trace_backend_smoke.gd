extends SceneTree

const GodotSceneTraceBackendRef = preload("res://src/core/collision/godot_scene_trace_backend.gd")
const TraceBackendRef = preload("res://src/core/collision/openstrike_trace_backend.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var backend = GodotSceneTraceBackendRef.new()
	var capabilities: Dictionary = backend.capabilities()

	if not _assert(str(capabilities.get("source", "")) == TraceBackendRef.SOURCE_GODOT_SCENE, "Godot trace backend should identify the temporary scene-collision source", capabilities):
		return 1
	if not _assert(str(capabilities.get("confidence", "")) == TraceBackendRef.CONFIDENCE_GODOT_COLLISION_UNVERIFIED, "Godot trace backend confidence should stay unverified", capabilities):
		return 1
	if not _assert(not bool(capabilities.get("goldsrc_parity", true)), "Godot trace backend must not claim GoldSrc parity", capabilities):
		return 1
	if not _assert(str(capabilities.get("trace_ray", "")) == TraceBackendRef.CAP_REQUIRES_WORLD_3D, "Trace ray should require a World3D before setup", capabilities):
		return 1
	if not _assert(str(capabilities.get("trace_hull", "")) == TraceBackendRef.CAP_REQUIRES_OPENSTRIKE_BSP_READER, "Trace hull should stay blocked on OpenStrike BSP reader", capabilities):
		return 1
	if not _assert(str(capabilities.get("point_contents", "")) == TraceBackendRef.CAP_REQUIRES_OPENSTRIKE_BSP_READER, "Point contents should stay blocked on OpenStrike BSP reader", capabilities):
		return 1

	var ray_trace = backend.trace_ray(Vector3.ZERO, Vector3.FORWARD)
	var ray_report: Dictionary = ray_trace.to_dictionary()
	if not _assert(not bool(ray_report.get("supported", true)), "Trace ray without World3D should fail honestly", ray_report):
		return 1
	if not _assert(str(ray_report.get("metadata", {}).get("capability", "")) == TraceBackendRef.CAP_REQUIRES_WORLD_3D, "Trace ray unsupported reason should be World3D capability", ray_report):
		return 1

	backend.setup(root.get_world_3d())
	capabilities = backend.capabilities()
	if not _assert(str(capabilities.get("trace_ray", "")) == TraceBackendRef.CAP_SUPPORTED_BY_GODOT_SPACE_STATE, "Trace ray should be available after World3D setup", capabilities):
		return 1
	var clear_ray = backend.trace_ray(Vector3.ZERO, Vector3.UP)
	var clear_ray_report: Dictionary = clear_ray.to_dictionary()
	if not _assert(bool(clear_ray_report.get("supported", false)), "Trace ray with World3D should be supported by Godot space state", clear_ray_report):
		return 1
	if not _assert(str(clear_ray_report.get("status", "")) == "clear", "Empty trace ray should report clear status", clear_ray_report):
		return 1

	var hull_trace = backend.trace_hull(Vector3.ZERO, Vector3.FORWARD, null)
	var hull_report: Dictionary = hull_trace.to_dictionary()
	if not _assert(not bool(hull_report.get("supported", true)), "Trace hull should not be faked through Godot scene collision", hull_report):
		return 1
	if not _assert(str(hull_report.get("metadata", {}).get("capability", "")) == TraceBackendRef.CAP_REQUIRES_OPENSTRIKE_BSP_READER, "Trace hull unsupported reason should be BSP reader capability", hull_report):
		return 1

	var contents_report: Dictionary = backend.point_contents(Vector3.ZERO)
	if not _assert(not bool(contents_report.get("supported", true)), "Point contents should not be faked through Godot scene collision", contents_report):
		return 1
	if not _assert(str(contents_report.get("contents", "")) == "unknown", "Point contents should report unknown until a BSP reader exists", contents_report):
		return 1

	print("Trace backend smoke passed.")
	return 0


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
