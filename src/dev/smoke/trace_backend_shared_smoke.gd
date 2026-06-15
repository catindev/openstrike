extends SceneTree

const SelectorRef = preload("res://src/dev/smoke/trace_backend_dev_selector.gd")
const TraceBackendRef = preload("res://src/core/collision/openstrike_trace_backend.gd")

const REQUIRED_TRACE_FIELDS := [
	"supported",
	"status",
	"source",
	"confidence",
	"goldsrc_parity",
	"start",
	"end",
	"hit_position",
	"normal",
	"fraction",
	"hit",
	"start_solid",
	"all_solid",
	"contents",
	"contents_code",
	"model_index",
	"collider_class",
	"collider_name",
	"metadata",
]


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var selector = SelectorRef.new()
	var backend_ids: Array[String] = selector.backend_ids()
	if not _assert(backend_ids.has(SelectorRef.BACKEND_GODOT_SCENE), "Dev selector should expose the Godot scene backend", backend_ids):
		return 1
	if not _assert(backend_ids.has(SelectorRef.BACKEND_SYNTHETIC_BSP_CLIPNODE), "Dev selector should expose the synthetic BSP clipnode backend", backend_ids):
		return 1

	if not _run_godot_backend_contract(selector):
		return 1
	if not _run_synthetic_bsp_backend_contract(selector):
		return 1

	print("Shared trace backend smoke passed.")
	return 0


func _run_godot_backend_contract(selector) -> bool:
	var backend = selector.select_backend(SelectorRef.BACKEND_GODOT_SCENE, root.get_world_3d())
	if not _assert(backend != null, "Godot backend should be selectable in smoke", {}):
		return false

	var capabilities: Dictionary = backend.capabilities()
	if not _assert(str(capabilities.get("source", "")) == TraceBackendRef.SOURCE_GODOT_SCENE, "Godot backend should keep scene-collision source", capabilities):
		return false
	if not _assert(str(capabilities.get("confidence", "")) == TraceBackendRef.CONFIDENCE_GODOT_COLLISION_UNVERIFIED, "Godot backend should keep unverified confidence", capabilities):
		return false
	if not _assert(not bool(capabilities.get("goldsrc_parity", true)), "Godot backend must not claim GoldSrc parity", capabilities):
		return false
	if not _assert(str(capabilities.get("trace_hull", "")) == TraceBackendRef.CAP_REQUIRES_OPENSTRIKE_BSP_READER, "Godot backend trace_hull should stay unsupported", capabilities):
		return false

	var trace_report: Dictionary = backend.trace_hull(Vector3.ZERO, Vector3.FORWARD, selector.standing_hull()).to_dictionary()
	return (
		_assert(_has_trace_fields(trace_report), "Godot hull trace report should expose the shared trace fields", trace_report)
		and _assert(not bool(trace_report.get("supported", true)), "Godot backend must not fake hull trace support", trace_report)
		and _assert(str(trace_report.get("source", "")) == TraceBackendRef.SOURCE_GODOT_SCENE, "Godot unsupported trace should still report its backend source", trace_report)
		and _assert(str(trace_report.get("confidence", "")) == TraceBackendRef.CONFIDENCE_GODOT_COLLISION_UNVERIFIED, "Godot unsupported trace should preserve confidence", trace_report)
		and _assert(int(trace_report.get("contents_code", -1)) == 0, "Godot unsupported trace should keep neutral contents_code", trace_report)
		and _assert(int(trace_report.get("model_index", 0)) == -1, "Godot unsupported trace should keep neutral model_index", trace_report)
	)


func _run_synthetic_bsp_backend_contract(selector) -> bool:
	var backend = selector.select_backend(SelectorRef.BACKEND_SYNTHETIC_BSP_CLIPNODE)
	if not _assert(backend != null, "Synthetic BSP backend should be selectable in smoke", {}):
		return false

	var capabilities: Dictionary = backend.capabilities()
	if not _assert(str(capabilities.get("source", "")) == TraceBackendRef.SOURCE_GOLDSRC_HULL_TRACE, "BSP backend should report GoldSrc hull trace source", capabilities):
		return false
	if not _assert(str(capabilities.get("confidence", "")) == TraceBackendRef.CONFIDENCE_SYNTHETIC_VERIFIED, "BSP backend should report synthetic confidence", capabilities):
		return false
	if not _assert(not bool(capabilities.get("goldsrc_parity", true)), "Synthetic BSP backend must not claim final GoldSrc parity", capabilities):
		return false
	if not _assert(str(capabilities.get("trace_hull", "")) == TraceBackendRef.CAP_SUPPORTED_BY_SYNTHETIC_BSP_FIXTURE, "BSP backend should expose synthetic hull support", capabilities):
		return false
	if not _assert(str(capabilities.get("point_contents", "")) == TraceBackendRef.CAP_DEFERRED, "BSP point_contents should remain deferred in PR-08C", capabilities):
		return false

	var hit_report: Dictionary = backend.trace_hull(Vector3(10.0, 0.0, 0.0), Vector3(-10.0, 0.0, 0.0), selector.point_hull()).to_dictionary()
	if not (
		_assert(_has_trace_fields(hit_report), "Synthetic BSP hit should expose the shared trace fields", hit_report)
		and _assert(bool(hit_report.get("supported", false)), "Synthetic BSP trace should be supported for fixture hulls", hit_report)
		and _assert(bool(hit_report.get("hit", false)), "Synthetic BSP point hull should hit", hit_report)
		and _assert(abs(float(hit_report.get("fraction", 0.0)) - 0.5) <= 0.001, "Synthetic BSP hit should keep PR-08B point fraction", hit_report)
		and _assert(int(hit_report.get("contents_code", 0)) == -2, "Synthetic BSP hit should expose solid contents_code", hit_report)
		and _assert(int(hit_report.get("model_index", -1)) == 0, "Synthetic BSP hit should expose model 0", hit_report)
	):
		return false

	var contents_report: Dictionary = backend.point_contents(Vector3.ZERO)
	return (
		_assert(not bool(contents_report.get("supported", true)), "Synthetic BSP point_contents should stay unsupported/deferred", contents_report)
		and _assert(str(contents_report.get("source", "")) == TraceBackendRef.SOURCE_GOLDSRC_HULL_TRACE, "Synthetic BSP point_contents should report backend source", contents_report)
		and _assert(str(contents_report.get("confidence", "")) == TraceBackendRef.CONFIDENCE_SYNTHETIC_VERIFIED, "Synthetic BSP point_contents should report synthetic confidence", contents_report)
		and _assert(str(contents_report.get("capability", "")) == TraceBackendRef.CAP_DEFERRED, "Synthetic BSP point_contents should report deferred capability", contents_report)
	)


func _has_trace_fields(trace_report: Dictionary) -> bool:
	for field in REQUIRED_TRACE_FIELDS:
		if not trace_report.has(field):
			return false
	return true


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
