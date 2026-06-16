extends Node3D

## Minimal player-facing walkable map scene for the game shell.
##
## Loads a GoldSrc BSP through src/core, runs movement through the src/game
## authoritative LocalGameSession, and follows the snapshot for presentation.
## This is a skeleton: no skybox (handed to analysis), no weapon/HUD/audio yet.
##
## Collision is the non-parity Godot scene backend until the GoldSrc clipnode
## trace lands; the on-screen overlay reports the collision source honestly.

class_name OpenStrikeWalkableWorld

signal exit_requested

const BspProviderRef = preload("res://src/core/maps/goldsrc_bsp_runtime_provider.gd")
const LocalGameSessionRef = preload("res://src/game/runtime/openstrike_local_game_session.gd")
const MapEntityIndexRef = preload("res://src/core/maps/map_entity_index.gd")
const MovementSettingsRef = preload("res://src/game/movement/cs_movement_settings.gd")
const PlayerSlotRef = preload("res://src/game/runtime/openstrike_player_slot.gd")
const RoundStateRef = preload("res://src/game/runtime/openstrike_round_state.gd")
const TraceBackendRef = preload("res://src/core/collision/godot_scene_trace_backend.gd")
const UserCommandRef = preload("res://src/game/runtime/openstrike_user_command.gd")
const ViewmodelWorldProfileRef = preload("res://src/core/units/viewmodel_world_profile.gd")

const MOUSE_SENSITIVITY := 0.0022
const MIN_PITCH := deg_to_rad(-89.0)
const MAX_PITCH := deg_to_rad(89.0)
const WALK_MAX_SPEED_UNITS := 250.0
const MAX_RUNTIME_STEPS_PER_FRAME := 8


## Scales imported Godot spawn positions back into runtime (GoldSrc) units so
## LocalGameSession owns simulation in GoldSrc space.
class RuntimeSpawnIndex:
	var _source_index = null
	var _unit_scale := 1.0

	func _init(source_index = null, unit_scale: float = 1.0) -> void:
		_source_index = source_index
		_unit_scale = maxf(unit_scale, 0.000001)

	func spawn_descriptors_for_classes(preferred_classes: Array[String]) -> Array[Dictionary]:
		var output: Array[Dictionary] = []
		if _source_index == null or not _source_index.has_method("spawn_descriptors_for_classes"):
			return output
		for descriptor_variant in _source_index.spawn_descriptors_for_classes(preferred_classes):
			if not descriptor_variant is Dictionary:
				continue
			var descriptor: Dictionary = descriptor_variant.duplicate(true)
			var position_godot: Vector3 = _vector_from_value(descriptor.get("position", Vector3.ZERO))
			descriptor["position"] = position_godot / _unit_scale
			descriptor["source"] = "%s:scaled_for_local_game_session" % str(descriptor.get("source", ""))
			output.append(descriptor)
		return output

	func _vector_from_value(value) -> Vector3:
		if value is Vector3:
			return value
		if value is Array and value.size() >= 3:
			return Vector3(float(value[0]), float(value[1]), float(value[2]))
		return Vector3.ZERO


var _profile
var _settings
var _trace_backend
var _entity_index
var _map_node: Node = null
var _player_root: Node3D = null
var _camera_pivot: Node3D = null
var _camera: Camera3D = null
var _overlay: Label = null
var _runtime_session = null
var _runtime_player_id := 0

var _started := false
var _exiting := false
var _accumulator := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _last_jump_held := false
var _map_path := ""
var _collision_source := ""
var _last_player_snapshot: Dictionary = {}
var _last_velocity_ups := Vector3.ZERO


func start_map(asset_manager, map_path: String) -> Dictionary:
	_map_path = map_path

	_profile = ViewmodelWorldProfileRef.new()
	_profile.load_from_file()
	if not _profile.is_valid():
		return {"ok": false, "reason": "viewmodel/world profile is invalid"}

	if asset_manager == null or not asset_manager.is_available():
		return {"ok": false, "reason": "asset manager unavailable"}

	_settings = MovementSettingsRef.new()
	_settings.max_speed = minf(_settings.max_speed, WALK_MAX_SPEED_UNITS)

	var provider = BspProviderRef.new()
	var load_result: Dictionary = provider.load_map_from_vfs(asset_manager.vfs, map_path, _profile.goldsrc_unit_scale)
	if not bool(load_result.get("ok", false)):
		return {"ok": false, "reason": "map load failed", "diagnostics": load_result.get("diagnostics", [])}

	_map_node = load_result["node"]
	add_child(_map_node)

	_entity_index = MapEntityIndexRef.new()
	_entity_index.build_from_scene(_map_node)
	_disable_non_blocking_entity_collision()

	_trace_backend = TraceBackendRef.new()
	_trace_backend.setup(get_world_3d())
	_collision_source = str(_trace_backend.capabilities().get("source", "godot_scene_collision"))

	_setup_lighting()
	_setup_player()
	_setup_overlay()

	set_process(true)
	set_physics_process(true)
	set_process_unhandled_input(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_started = true
	return {"ok": true}


func _setup_lighting() -> void:
	var world_environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.28, 0.28)
	env.ambient_light_energy = 0.35
	world_environment.environment = env
	add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.light_energy = 0.4
	light.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	add_child(light)


func _setup_player() -> void:
	_player_root = Node3D.new()
	_player_root.name = "SnapshotPlayer"
	add_child(_player_root)

	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPitchPivot"
	_player_root.add_child(_camera_pivot)

	_camera = Camera3D.new()
	_profile.apply_to_camera(_camera, false)
	_camera.current = true
	_camera_pivot.add_child(_camera)

	var runtime_spawn_index = RuntimeSpawnIndex.new(_entity_index, _profile.goldsrc_unit_scale)
	_runtime_session = LocalGameSessionRef.new()
	_runtime_session.configure(_settings.fixed_delta(), runtime_spawn_index, _settings, _trace_backend)
	_runtime_player_id = _runtime_session.add_player("shell_local", PlayerSlotRef.TEAM_COUNTER_TERRORIST)
	_runtime_session.start_round(RoundStateRef.PHASE_LIVE)
	_sync_presentation_from_snapshot()
	_update_camera_height(false)
	_apply_camera_rotation()


func _setup_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WalkableOverlay"
	add_child(layer)

	_overlay = Label.new()
	_overlay.position = Vector2(12.0, 12.0)
	_overlay.add_theme_font_size_override("font_size", 13)
	_overlay.modulate = Color(1.0, 0.72, 0.28, 0.92)
	layer.add_child(_overlay)
	_update_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if not _started:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_request_exit()
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - motion.relative.y * MOUSE_SENSITIVITY, MIN_PITCH, MAX_PITCH)
		_apply_camera_rotation()

	if event is InputEventMouseButton and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(_delta: float) -> void:
	if _started:
		_update_overlay()


func _physics_process(delta: float) -> void:
	if not _started or _runtime_session == null or _player_root == null:
		return

	_accumulator += minf(delta, 0.25)
	var fixed_delta: float = _settings.fixed_delta()
	var steps := 0
	while _accumulator >= fixed_delta and steps < MAX_RUNTIME_STEPS_PER_FRAME:
		_accumulator -= fixed_delta
		_queue_runtime_command(_read_input())
		if _runtime_session.step(fixed_delta) > 0:
			_sync_presentation_from_snapshot()
		steps += 1

	if steps >= MAX_RUNTIME_STEPS_PER_FRAME:
		_accumulator = 0.0


func _read_input() -> Dictionary:
	var forward := 0.0
	var side := 0.0
	if Input.is_key_pressed(KEY_W):
		forward += 1.0
	if Input.is_key_pressed(KEY_S):
		forward -= 1.0
	if Input.is_key_pressed(KEY_D):
		side += 1.0
	if Input.is_key_pressed(KEY_A):
		side -= 1.0

	var jump_held := Input.is_key_pressed(KEY_SPACE)
	var input := {
		"forward": forward,
		"side": side,
		"jump_pressed": jump_held and not _last_jump_held,
		"duck": Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C),
	}
	_last_jump_held = jump_held
	return input


func _queue_runtime_command(input: Dictionary) -> void:
	var command = UserCommandRef.new()
	command.configure(
		_runtime_session.current_tick + 1,
		_runtime_player_id,
		-float(input.get("forward", 0.0)),
		float(input.get("side", 0.0)),
		bool(input.get("jump_pressed", false)),
		bool(input.get("duck", false)),
		_yaw,
		_pitch
	)
	_runtime_session.queue_command(command)


func _sync_presentation_from_snapshot() -> void:
	if _runtime_session == null:
		return
	var snapshot: Dictionary = _runtime_session.snapshot().to_dictionary()
	_last_player_snapshot = _snapshot_player(snapshot)
	if _last_player_snapshot.is_empty():
		return

	var origin_units: Vector3 = _vector_from_value(_last_player_snapshot.get("origin", Vector3.ZERO))
	_last_velocity_ups = _vector_from_value(_last_player_snapshot.get("velocity", Vector3.ZERO))
	_yaw = float(_last_player_snapshot.get("view_yaw", _yaw))
	_pitch = float(_last_player_snapshot.get("view_pitch", _pitch))
	if _player_root != null:
		_player_root.global_position = origin_units * _profile.goldsrc_unit_scale
	_update_camera_height(bool(_last_player_snapshot.get("ducked", false)))
	_apply_camera_rotation()


func _snapshot_player(snapshot: Dictionary) -> Dictionary:
	for player_variant in snapshot.get("players", []):
		if player_variant is Dictionary and int(player_variant.get("player_id", 0)) == _runtime_player_id:
			return (player_variant as Dictionary).duplicate(true)
	return {}


func _update_camera_height(ducked: bool) -> void:
	if _camera_pivot != null:
		_camera_pivot.position.y = _profile.scaled_units(_profile.view_offset_duck if ducked else _profile.view_offset_stand)


func _apply_camera_rotation() -> void:
	if _player_root != null:
		_player_root.rotation.y = _yaw
	if _camera_pivot != null:
		_camera_pivot.rotation.x = _pitch


func _disable_non_blocking_entity_collision() -> void:
	if _entity_index == null:
		return
	for entry in _entity_index.entries_for_player_collision_disabled():
		var node = entry.get("node", null)
		if node is Node:
			_disable_collision_tree(node)


func _disable_collision_tree(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is CollisionObject3D:
			(current as CollisionObject3D).collision_layer = 0
			(current as CollisionObject3D).collision_mask = 0
		if current is CollisionShape3D:
			(current as CollisionShape3D).disabled = true
		for child in current.get_children():
			if child is Node:
				stack.append(child)


func _update_overlay() -> void:
	if _overlay == null:
		return
	var horizontal_speed := Vector2(_last_velocity_ups.x, _last_velocity_ups.z).length()
	_overlay.text = (
		"%s | collision=%s (placeholder, not GoldSrc parity)\n"
		+ "WASD move  Mouse look  Space jump  Ctrl/C duck  Esc menu\n"
		+ "speed=%.1f u/s  on_floor=%s"
	) % [
		_map_path,
		_collision_source,
		horizontal_speed,
		str(_last_player_snapshot.get("on_ground", false)),
	]


func _request_exit() -> void:
	if _exiting:
		return
	_exiting = true
	_started = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	exit_requested.emit()


func _vector_from_value(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO
