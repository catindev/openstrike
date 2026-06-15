extends SceneTree

const BspBackendRef = preload("res://src/core/bsp/bsp_clipnode_trace_backend.gd")
const CollisionLumpsRef = preload("res://src/core/bsp/bsp_collision_lumps.gd")
const LumpTableRef = preload("res://src/core/bsp/bsp_lump_table.gd")
const MapResourceRef = preload("res://src/core/bsp/bsp_map_resource.gd")
const MovementSettingsRef = preload("res://src/game/movement/cs_movement_settings.gd")
const MoveCommandRef = preload("res://src/game/player/player_move_command.gd")
const MoveServiceRef = preload("res://src/game/player/player_move_service.gd")
const PlayerStateRef = preload("res://src/game/player/player_state.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var settings = MovementSettingsRef.new()
	if not _run_duck_hull_passes_low_ceiling(settings):
		return 1
	if not _run_step_up_succeeds_on_18_units(settings):
		return 1
	if not _run_step_up_fails_on_too_high_step(settings):
		return 1

	print("PlayerMoveService step smoke passed.")
	return 0


func _run_duck_hull_passes_low_ceiling(settings) -> bool:
	var service = MoveServiceRef.new(settings, _low_ceiling_backend())
	var standing_state = PlayerStateRef.new()
	standing_state.configure(Vector3(32.0, 0.0, 0.0), Vector3(-2000.0, 0.0, 0.0), 0.0, 0.0, false, true)
	var standing_result = service.move(standing_state, _command(settings.fixed_delta(), false))
	var standing_contact: Dictionary = standing_result.trace_summary.get("contact", {})
	var standing_step: Dictionary = standing_contact.get("step", {})

	var duck_state = PlayerStateRef.new()
	duck_state.configure(Vector3(32.0, 0.0, 0.0), Vector3(-2000.0, 0.0, 0.0), 0.0, 0.0, false, true)
	var duck_result = service.move(duck_state, _command(settings.fixed_delta(), true))
	var duck_contact: Dictionary = duck_result.trace_summary.get("contact", {})
	return (
		_assert(bool(standing_contact.get("start_solid", false)), "Standing hull should start solid under synthetic low ceiling", standing_result.to_dictionary())
		and _assert(abs(standing_result.state.origin.x - 32.0) <= 0.001, "Standing hull should not move through low ceiling", standing_result.to_dictionary())
		and _assert(bool(standing_step.get("attempted", false)), "Standing low-ceiling block should attempt but reject step path", standing_result.to_dictionary())
		and _assert(not bool(standing_step.get("selected", true)), "Standing low-ceiling step path should not be selected", standing_result.to_dictionary())
		and _assert(bool(duck_result.state.ducked), "Duck command should select the duck hull", duck_result.to_dictionary())
		and _assert(str(duck_result.trace_summary.get("hull", {}).get("kind", "")) == "duck", "Duck hull metadata should be reported", duck_result.to_dictionary())
		and _assert(not bool(duck_contact.get("blocked", true)), "Duck hull should pass synthetic low ceiling", duck_result.to_dictionary())
		and _assert(duck_result.state.origin.x < 32.0, "Duck hull should move through the low-ceiling fixture", duck_result.to_dictionary())
	)


func _run_step_up_succeeds_on_18_units(settings) -> bool:
	var service = MoveServiceRef.new(settings, _step_backend(settings.step_size))
	var state = PlayerStateRef.new()
	state.configure(Vector3(32.0, 0.0, 0.0), Vector3(-2000.0, 0.0, 0.0), 0.0, 0.0, false, true)
	var result = service.move(state, _command(settings.fixed_delta(), false))
	var contact: Dictionary = result.trace_summary.get("contact", {})
	var step: Dictionary = contact.get("step", {})
	return (
		_assert(bool(step.get("attempted", false)), "Blocked walk move should attempt a step path", result.to_dictionary())
		and _assert(bool(step.get("valid", false)), "18-unit synthetic step should be a valid step path", result.to_dictionary())
		and _assert(bool(step.get("selected", false)), "18-unit synthetic step should be selected over blocked flat move", result.to_dictionary())
		and _assert(abs(result.state.origin.y - settings.step_size) <= 0.001, "Selected step should land on the 18-unit top", result.to_dictionary())
		and _assert(result.state.origin.x < 16.0, "Selected step should advance past the riser", result.to_dictionary())
		and _assert(abs(float(result.trace_summary.get("ground_height", 0.0)) - settings.step_size) <= 0.001, "Selected step should update ground height metadata", result.to_dictionary())
		and _assert(bool(result.state.on_ground), "Selected step should keep state grounded", result.to_dictionary())
		and _assert(float(step.get("step_progress", 0.0)) > float(step.get("flat_progress", 1.0)), "Selected step should advance farther than flat path", result.to_dictionary())
	)


func _run_step_up_fails_on_too_high_step(settings) -> bool:
	var service = MoveServiceRef.new(settings, _step_backend(settings.step_size + 6.0))
	var state = PlayerStateRef.new()
	state.configure(Vector3(32.0, 0.0, 0.0), Vector3(-2000.0, 0.0, 0.0), 0.0, 0.0, false, true)
	var result = service.move(state, _command(settings.fixed_delta(), false))
	var contact: Dictionary = result.trace_summary.get("contact", {})
	var step: Dictionary = contact.get("step", {})
	return (
		_assert(bool(step.get("attempted", false)), "Too-high step should still be attempted", result.to_dictionary())
		and _assert(not bool(step.get("valid", true)), "Too-high synthetic step should be invalid", result.to_dictionary())
		and _assert(not bool(step.get("selected", true)), "Too-high synthetic step should not be selected", result.to_dictionary())
		and _assert(abs(result.state.origin.y) <= 0.001, "Too-high step should keep the original ground height", result.to_dictionary())
		and _assert(abs(result.state.origin.x - 16.0) <= 0.001, "Too-high step should keep the flat wall stop", result.to_dictionary())
		and _assert(str(step.get("reason", "")) == "step_move_blocked", "Too-high step should fail during elevated move", result.to_dictionary())
	)


func _low_ceiling_backend():
	return _backend_for_fixture(
		[
			{"normal": Vector3(0.0, -1.0, 0.0), "dist": -24.0},
		],
		[
			{"planenum": 0, "front": CollisionLumpsRef.CONTENTS_EMPTY, "back": CollisionLumpsRef.CONTENTS_SOLID},
		]
	)


func _step_backend(step_height: float):
	var standing_half_height := 36.0
	return _backend_for_fixture(
		[
			{"normal": Vector3(0.0, 1.0, 0.0), "dist": step_height - standing_half_height},
			{"normal": Vector3(1.0, 0.0, 0.0), "dist": 0.0},
		],
		[
			{"planenum": 0, "front": CollisionLumpsRef.CONTENTS_EMPTY, "back": 1},
			{"planenum": 1, "front": CollisionLumpsRef.CONTENTS_EMPTY, "back": CollisionLumpsRef.CONTENTS_SOLID},
		]
	)


func _backend_for_fixture(planes: Array[Dictionary], clipnodes: Array[Dictionary]):
	var map_resource = MapResourceRef.new()
	if not map_resource.load_from_bytes(_build_bsp30_fixture(planes, clipnodes)):
		push_error("Synthetic PR-08H BSP fixture failed to load: %s" % JSON.stringify(map_resource.to_report()))
		return null
	if map_resource.has_errors():
		push_error("Synthetic PR-08H BSP fixture loaded with errors: %s" % JSON.stringify(map_resource.to_report()))
		return null
	var backend = BspBackendRef.new()
	backend.setup(map_resource, BspBackendRef.HULL_EXTENT_CONTRACT_RUNTIME_PLANE_OFFSET)
	return backend


func _command(delta: float, wants_duck: bool):
	var command = MoveCommandRef.new()
	command.configure(0.0, 0.0, false, wants_duck, 0.0, 0.0, delta)
	return command


func _build_bsp30_fixture(planes: Array[Dictionary], clipnodes: Array[Dictionary]) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(LumpTableRef.HEADER_SIZE)
	_write_i32_at(bytes, 0, LumpTableRef.BSP_VERSION)

	var entries: Array[Dictionary] = []
	for index in range(LumpTableRef.HEADER_LUMPS):
		entries.append({"offset": 0, "length": 0})

	_append_lump(bytes, entries, LumpTableRef.LUMP_PLANES, _build_plane_lump(planes))
	_append_lump(bytes, entries, LumpTableRef.LUMP_CLIPNODES, _build_clipnode_lump(clipnodes))
	_append_lump(bytes, entries, LumpTableRef.LUMP_MODELS, _build_model_lump([0, 0, -1, 0]))

	for index in range(entries.size()):
		var header_offset := 4 + index * 8
		_write_i32_at(bytes, header_offset, int(entries[index].get("offset", 0)))
		_write_i32_at(bytes, header_offset + 4, int(entries[index].get("length", 0)))
	return bytes


func _build_plane_lump(planes: Array[Dictionary]) -> PackedByteArray:
	var bytes := PackedByteArray()
	for plane in planes:
		var normal: Vector3 = plane.get("normal", Vector3.ZERO)
		_append_f32(bytes, normal.x)
		_append_f32(bytes, normal.y)
		_append_f32(bytes, normal.z)
		_append_f32(bytes, float(plane.get("dist", 0.0)))
		_append_i32(bytes, 0)
	return bytes


func _build_clipnode_lump(clipnodes: Array[Dictionary]) -> PackedByteArray:
	var bytes := PackedByteArray()
	for clipnode in clipnodes:
		_append_i32(bytes, int(clipnode.get("planenum", 0)))
		_append_i16(bytes, int(clipnode.get("front", CollisionLumpsRef.CONTENTS_EMPTY)))
		_append_i16(bytes, int(clipnode.get("back", CollisionLumpsRef.CONTENTS_SOLID)))
	return bytes


func _build_model_lump(headnodes: Array[int]) -> PackedByteArray:
	var bytes := PackedByteArray()
	for value in [0.0, 0.0, 0.0]:
		_append_f32(bytes, value)
	for value in [0.0, 0.0, 0.0]:
		_append_f32(bytes, value)
	for value in [0.0, 0.0, 0.0]:
		_append_f32(bytes, value)

	for index in range(4):
		_append_i32(bytes, int(headnodes[index]))
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


func _write_i32_at(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes.encode_s32(offset, value)


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
