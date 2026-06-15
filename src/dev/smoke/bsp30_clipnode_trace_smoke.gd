extends SceneTree

const BspBackendRef = preload("res://src/core/bsp/bsp_clipnode_trace_backend.gd")
const CollisionLumpsRef = preload("res://src/core/bsp/bsp_collision_lumps.gd")
const HullRef = preload("res://src/core/collision/openstrike_collision_hull.gd")
const LumpTableRef = preload("res://src/core/bsp/bsp_lump_table.gd")
const MapResourceRef = preload("res://src/core/bsp/bsp_map_resource.gd")
const TraceBackendRef = preload("res://src/core/collision/openstrike_trace_backend.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	if not _run_reader_contract():
		return 1
	if not _run_point_hull_trace():
		return 1
	if not _run_standing_hull_trace():
		return 1
	if not _run_start_solid_trace():
		return 1
	if not _run_free_trace():
		return 1
	if not _run_invalid_planenum_diagnostic():
		return 1
	if not _run_invalid_child_diagnostic():
		return 1
	if not _run_empty_clipnodes_non_solid():
		return 1
	if not _run_source_style_model_rejection():
		return 1

	print("BSP30 clipnode trace smoke passed.")
	return 0


func _run_reader_contract() -> bool:
	var map_resource = _load_map(_build_bsp30_fixture())
	if map_resource == null:
		return false
	var model: Dictionary = map_resource.models[0]
	var headnodes: Array = model.get("headnodes", [])
	return (
		_assert(map_resource.version == LumpTableRef.BSP_VERSION, "Synthetic BSP should parse as BSP30", map_resource.to_report())
		and _assert(map_resource.planes.size() == 1, "Synthetic BSP should expose one plane", map_resource.to_report())
		and _assert(map_resource.clipnodes.size() == 1, "Synthetic BSP should expose one clipnode", map_resource.to_report())
		and _assert(map_resource.models.size() == 1, "Synthetic BSP should expose one GoldSrc model", map_resource.to_report())
		and _assert(headnodes.size() == 4 and int(headnodes[1]) == 0, "GoldSrc model must expose headnode[4] with standing hull at index 1", model)
	)


func _run_point_hull_trace() -> bool:
	var backend = _backend_for_fixture(_build_bsp30_fixture())
	if backend == null:
		return false
	var capabilities: Dictionary = backend.capabilities()
	if not _assert(str(capabilities.get("trace_hull", "")) == TraceBackendRef.CAP_SUPPORTED_BY_SYNTHETIC_BSP_FIXTURE, "BSP clipnode backend should report synthetic-only hull trace support", capabilities):
		return false
	var trace = backend.trace_hull(Vector3(10.0, 0.0, 0.0), Vector3(-10.0, 0.0, 0.0), _point_hull())
	var report: Dictionary = trace.to_dictionary()
	return (
		_assert(bool(report.get("hit", false)), "Point hull should hit the synthetic x=0 solid halfspace", report)
		and _assert(abs(float(report.get("fraction", 0.0)) - 0.5) <= 0.001, "Point hull trace should hit halfway through x=10 -> x=-10", report)
		and _assert(abs(float(report.get("hit_position", [])[0])) <= 0.001, "Point hull hit position should be on x=0", report)
		and _assert(str(report.get("contents", "")) == "solid", "Point hull should report solid contents on impact", report)
	)


func _run_standing_hull_trace() -> bool:
	var backend = _backend_for_fixture(_build_bsp30_fixture())
	if backend == null:
		return false
	var trace = backend.trace_hull(Vector3(32.0, 0.0, 0.0), Vector3(-32.0, 0.0, 0.0), _standing_hull())
	var report: Dictionary = trace.to_dictionary()
	return (
		_assert(bool(report.get("hit", false)), "Standing hull should hit the runtime-offset synthetic plane", report)
		and _assert(abs(float(report.get("fraction", 0.0)) - 0.25) <= 0.001, "Standing hull center should contact at x=16 over x=32 -> x=-32", report)
		and _assert(abs(float(report.get("hit_position", [])[0]) - 16.0) <= 0.001, "Standing hull center contact should be x=16", report)
	)


func _run_start_solid_trace() -> bool:
	var backend = _backend_for_fixture(_build_bsp30_fixture())
	if backend == null:
		return false
	var trace = backend.trace_hull(Vector3(10.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0), _standing_hull())
	var report: Dictionary = trace.to_dictionary()
	return (
		_assert(bool(report.get("start_solid", false)), "Standing hull starting at x=10 should overlap the solid side after runtime offset", report)
		and _assert(abs(float(report.get("fraction", 1.0))) <= 0.001, "Start-solid trace should report fraction 0", report)
	)


func _run_free_trace() -> bool:
	var backend = _backend_for_fixture(_build_bsp30_fixture())
	if backend == null:
		return false
	var trace = backend.trace_hull(Vector3(10.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0), _point_hull())
	var report: Dictionary = trace.to_dictionary()
	return (
		_assert(not bool(report.get("hit", true)), "Trace staying in the empty halfspace should stay clear", report)
		and _assert(abs(float(report.get("fraction", 0.0)) - 1.0) <= 0.001, "Free trace should keep fraction 1", report)
	)


func _run_invalid_planenum_diagnostic() -> bool:
	var backend = _backend_for_fixture(_build_bsp30_fixture(99))
	if backend == null:
		return false
	var report: Dictionary = backend.trace_hull(Vector3(10.0, 0.0, 0.0), Vector3(-10.0, 0.0, 0.0), _point_hull()).to_dictionary()
	return (
		_assert(not bool(report.get("supported", true)), "Invalid planenum trace should fail as a diagnostic, not fake a result", report)
		and _assert(_has_diagnostic_code(report, "invalid_planenum"), "Invalid planenum diagnostic should be structured", report)
	)


func _run_invalid_child_diagnostic() -> bool:
	var backend = _backend_for_fixture(_build_bsp30_fixture(0, 99, CollisionLumpsRef.CONTENTS_SOLID))
	if backend == null:
		return false
	var report: Dictionary = backend.trace_hull(Vector3(10.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0), _point_hull()).to_dictionary()
	return (
		_assert(not bool(report.get("supported", true)), "Invalid child trace should fail as a diagnostic, not fake a result", report)
		and _assert(_has_diagnostic_code(report, "invalid_child_index"), "Invalid child diagnostic should be structured", report)
	)


func _run_empty_clipnodes_non_solid() -> bool:
	var backend = _backend_for_fixture(_build_bsp30_fixture(0, CollisionLumpsRef.CONTENTS_EMPTY, CollisionLumpsRef.CONTENTS_SOLID, false))
	if backend == null:
		return false
	var report: Dictionary = backend.trace_hull(Vector3(32.0, 0.0, 0.0), Vector3(-32.0, 0.0, 0.0), _standing_hull()).to_dictionary()
	return (
		_assert(bool(report.get("supported", false)), "Empty clipnodes should remain a supported non-solid result", report)
		and _assert(not bool(report.get("hit", true)), "Empty clipnodes should be non-solid", report)
		and _assert(abs(float(report.get("fraction", 0.0)) - 1.0) <= 0.001, "Empty clipnodes should not fall back to headnode[0]", report)
		and _assert(_has_diagnostic_code(report, "empty_clipnodes_non_solid"), "Empty clipnodes should record an explicit non-solid diagnostic", report)
	)


func _run_source_style_model_rejection() -> bool:
	var map_resource = MapResourceRef.new()
	var loaded := map_resource.load_from_bytes(_build_bsp30_fixture(0, CollisionLumpsRef.CONTENTS_EMPTY, CollisionLumpsRef.CONTENTS_SOLID, true, 48))
	var report: Dictionary = map_resource.to_report()
	return (
		_assert(not loaded, "Source-style 48-byte dmodel_t fixture should be rejected", report)
		and _assert(map_resource.has_errors(), "Source-style model rejection should be an error", report)
		and _assert(_diagnostics_contain(map_resource.diagnostics_to_dictionaries(), "bsp_model_lump_not_goldsrc_64_bytes"), "Source-style model rejection should name the GoldSrc 64-byte contract", report)
	)


func _backend_for_fixture(bytes: PackedByteArray):
	var map_resource = _load_map(bytes)
	if map_resource == null:
		return null
	var backend = BspBackendRef.new()
	backend.setup(map_resource, BspBackendRef.HULL_EXTENT_CONTRACT_RUNTIME_PLANE_OFFSET)
	return backend


func _load_map(bytes: PackedByteArray):
	var map_resource = MapResourceRef.new()
	var loaded := map_resource.load_from_bytes(bytes)
	if not _assert(loaded and not map_resource.has_errors(), "Synthetic BSP fixture should load without reader errors", map_resource.to_report()):
		return null
	return map_resource


func _point_hull():
	var hull = HullRef.new()
	hull.configure(HullRef.KIND_POINT, Vector3.ZERO, Vector3.ZERO)
	return hull


func _standing_hull():
	var hull = HullRef.new()
	hull.configure(HullRef.KIND_PLAYER_STANDING, Vector3(-16.0, -16.0, -36.0), Vector3(16.0, 16.0, 36.0))
	return hull


func _build_bsp30_fixture(
	planenum: int = 0,
	front_child: int = CollisionLumpsRef.CONTENTS_EMPTY,
	back_child: int = CollisionLumpsRef.CONTENTS_SOLID,
	include_clipnodes: bool = true,
	model_record_size: int = 64
) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(LumpTableRef.HEADER_SIZE)
	_write_i32_at(bytes, 0, LumpTableRef.BSP_VERSION)

	var entries: Array[Dictionary] = []
	for index in range(LumpTableRef.HEADER_LUMPS):
		entries.append({"offset": 0, "length": 0})

	_append_lump(bytes, entries, LumpTableRef.LUMP_PLANES, _build_plane_lump())
	if include_clipnodes:
		_append_lump(bytes, entries, LumpTableRef.LUMP_CLIPNODES, _build_clipnode_lump(planenum, front_child, back_child))
	else:
		_append_lump(bytes, entries, LumpTableRef.LUMP_CLIPNODES, PackedByteArray())
	_append_lump(bytes, entries, LumpTableRef.LUMP_MODELS, _build_model_lump(model_record_size))

	for index in range(entries.size()):
		var header_offset := 4 + index * 8
		_write_i32_at(bytes, header_offset, int(entries[index].get("offset", 0)))
		_write_i32_at(bytes, header_offset + 4, int(entries[index].get("length", 0)))
	return bytes


func _build_plane_lump() -> PackedByteArray:
	var bytes := PackedByteArray()
	_append_f32(bytes, 1.0)
	_append_f32(bytes, 0.0)
	_append_f32(bytes, 0.0)
	_append_f32(bytes, 0.0)
	_append_i32(bytes, 0)
	return bytes


func _build_clipnode_lump(planenum: int, front_child: int, back_child: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	_append_i32(bytes, planenum)
	_append_i16(bytes, front_child)
	_append_i16(bytes, back_child)
	return bytes


func _build_model_lump(record_size: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	for value in [0.0, 0.0, 0.0]:
		_append_f32(bytes, value)
	for value in [0.0, 0.0, 0.0]:
		_append_f32(bytes, value)
	for value in [0.0, 0.0, 0.0]:
		_append_f32(bytes, value)

	if record_size == 48:
		_append_i32(bytes, 0)
		_append_i32(bytes, 0)
		_append_i32(bytes, 0)
		return bytes

	_append_i32(bytes, 0)
	_append_i32(bytes, 0)
	_append_i32(bytes, -1)
	_append_i32(bytes, 0)
	_append_i32(bytes, 0)
	_append_i32(bytes, 0)
	_append_i32(bytes, 0)
	return bytes


func _append_lump(bytes: PackedByteArray, entries: Array[Dictionary], index: int, lump_bytes: PackedByteArray) -> void:
	if lump_bytes.is_empty():
		entries[index] = {"offset": 0, "length": 0}
		return
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


func _write_i32_at(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes.encode_s32(offset, value)


func _has_diagnostic_code(report: Dictionary, code: String) -> bool:
	var metadata: Dictionary = report.get("metadata", {})
	var diagnostics: Array = metadata.get("diagnostics", [])
	return _diagnostics_contain(diagnostics, code)


func _diagnostics_contain(diagnostics: Array, code: String) -> bool:
	for diagnostic_variant in diagnostics:
		var diagnostic: Dictionary = diagnostic_variant
		if str(diagnostic.get("code", "")) == code:
			return true
	return false


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
