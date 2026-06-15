extends RefCounted

const BACKEND_GODOT_SCENE := "godot_scene"
const BACKEND_SYNTHETIC_BSP_CLIPNODE := "synthetic_bsp_clipnode"

const BspBackendRef = preload("res://src/core/bsp/bsp_clipnode_trace_backend.gd")
const CollisionLumpsRef = preload("res://src/core/bsp/bsp_collision_lumps.gd")
const GodotSceneBackendRef = preload("res://src/core/collision/godot_scene_trace_backend.gd")
const HullRef = preload("res://src/core/collision/openstrike_collision_hull.gd")
const LumpTableRef = preload("res://src/core/bsp/bsp_lump_table.gd")
const MapResourceRef = preload("res://src/core/bsp/bsp_map_resource.gd")


func backend_ids() -> Array[String]:
	return [BACKEND_GODOT_SCENE, BACKEND_SYNTHETIC_BSP_CLIPNODE]


func select_backend(backend_id: String, world: World3D = null):
	match backend_id:
		BACKEND_GODOT_SCENE:
			var godot_backend = GodotSceneBackendRef.new()
			if world != null:
				godot_backend.setup(world)
			return godot_backend
		BACKEND_SYNTHETIC_BSP_CLIPNODE:
			return synthetic_bsp_backend()
		_:
			return null


func synthetic_bsp_backend():
	var map_resource = synthetic_map_resource()
	if map_resource == null:
		return null
	var backend = BspBackendRef.new()
	backend.setup(map_resource, BspBackendRef.HULL_EXTENT_CONTRACT_RUNTIME_PLANE_OFFSET)
	return backend


func synthetic_map_resource():
	var map_resource = MapResourceRef.new()
	if not map_resource.load_from_bytes(build_bsp30_fixture()):
		return null
	if map_resource.has_errors():
		return null
	return map_resource


func point_hull():
	var hull = HullRef.new()
	hull.configure(HullRef.KIND_POINT, Vector3.ZERO, Vector3.ZERO)
	return hull


func standing_hull():
	var hull = HullRef.new()
	hull.configure(HullRef.KIND_PLAYER_STANDING, Vector3(-16.0, -16.0, -36.0), Vector3(16.0, 16.0, 36.0))
	return hull


func build_bsp30_fixture(
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
