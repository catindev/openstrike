extends Node3D

class_name OpenStrikeBspWalkableRunner

const AssetManagerRef = preload("res://src/core/assets/asset_manager.gd")
const BspProviderRef = preload("res://src/core/maps/goldsrc_bsp_runtime_provider.gd")
const LocalGameSessionRef = preload("res://src/game/runtime/openstrike_local_game_session.gd")
const MapEntityIndexRef = preload("res://src/core/maps/map_entity_index.gd")
const MovementSettingsRef = preload("res://src/game/movement/cs_movement_settings.gd")
const PlayerSlotRef = preload("res://src/game/runtime/openstrike_player_slot.gd")
const RoundStateRef = preload("res://src/game/runtime/openstrike_round_state.gd")
const TraceLoggerRef = preload("res://src/dev/labs/bsp_walkable/bsp_walkable_trace_logger.gd")
const TraceBackendRef = preload("res://src/core/collision/godot_scene_trace_backend.gd")
const UserCommandRef = preload("res://src/game/runtime/openstrike_user_command.gd")
const ViewmodelWorldProfileRef = preload("res://src/core/units/viewmodel_world_profile.gd")

const DEFAULT_MAP_PATH := "maps/de_dust2.bsp"
const MOUSE_SENSITIVITY := 0.0022
const MIN_PITCH := deg_to_rad(-89.0)
const MAX_PITCH := deg_to_rad(89.0)
const LAB_WALK_MAX_SPEED_UNITS := 250.0
const FOOTSTEP_MIN_SPEED_UPS := 80.0
const FOOTSTEP_SLOW_INTERVAL_SEC := 0.48
const FOOTSTEP_FAST_INTERVAL_SEC := 0.30
const MOVEMENT_SOUND_VOLUME_DB := -7.0
const MOVEMENT_SOUND_PLAYER_COUNT := 4
const MAX_RUNTIME_STEPS_PER_FRAME := 8
const SKYBOX_FACE_SUFFIXES: Array[String] = ["ft", "bk", "lf", "rt", "up", "dn"]
const SKYBOX_EXTENSIONS: Array[String] = ["tga", "bmp"]
const SKYBOX_ALIAS_BY_SKYNAME = {
	"des": ["des", "desert", "2desert"],
}
const MOVEMENT_SOUND_PATHS = {
	"footstep": [
		"sound/player/pl_step1.wav",
		"sound/player/pl_step2.wav",
		"sound/player/pl_step3.wav",
		"sound/player/pl_step4.wav",
	],
	"jump": [
		"sound/player/pl_jump1.wav",
		"sound/player/pl_jump2.wav",
	],
	"land": [
		"sound/player/pl_jumpland2.wav",
	],
}


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

		var source_descriptors: Array = _source_index.spawn_descriptors_for_classes(preferred_classes)
		for descriptor_variant in source_descriptors:
			if not descriptor_variant is Dictionary:
				continue
			var descriptor: Dictionary = descriptor_variant.duplicate(true)
			var position_godot: Vector3 = _vector_from_value(descriptor.get("position", Vector3.ZERO))
			var position_units: Vector3 = position_godot / _unit_scale
			descriptor["position"] = position_units
			descriptor["position_godot"] = _vector_to_array(position_godot)
			descriptor["position_units"] = _vector_to_array(position_units)
			descriptor["source"] = "%s:scaled_for_local_game_session" % str(descriptor.get("source", ""))
			output.append(descriptor)
		return output


	func _vector_from_value(value) -> Vector3:
		if value is Vector3:
			return value
		if value is Array and value.size() >= 3:
			return Vector3(float(value[0]), float(value[1]), float(value[2]))
		return Vector3.ZERO


	func _vector_to_array(value: Vector3) -> Array[float]:
		return [value.x, value.y, value.z]


var config_path := "user://local_goldsrc.json"
var map_path := DEFAULT_MAP_PATH
var trace_enabled := true
var start_uncaptured := false
var auto_exit_sec := 0.0
var auto_forward_sec := 0.0
var fullscreen := true

var _asset_manager
var _profile
var _settings
var _provider
var _entity_index
var _trace_backend
var _logger
var _map_node: Node = null
var _player_root: Node3D = null
var _camera_pivot: Node3D = null
var _camera: Camera3D = null
var _overlay: Label = null
var _environment: Environment = null
var _movement_audio_players: Array[AudioStreamPlayer] = []
var _runtime_session = null
var _runtime_player_id := 0

var _last_snapshot_velocity_ups := Vector3.ZERO
var _last_snapshot_report: Dictionary = {}
var _last_player_snapshot: Dictionary = {}
var _last_snapshot_slide_reports: Array[Dictionary] = []
var _accumulator := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _elapsed := 0.0
var _tick := 0
var _last_jump_held := false
var _last_on_floor := false
var _last_snapshot_step_up_attempted := false
var _last_snapshot_step_up_applied := false
var _started := false
var _finished := false
var _spawn_report := {}
var _map_metadata := {}
var _map_entity_index_report := {}
var _trace_backend_report := {}
var _non_blocking_collision_report := {}
var _skybox_report := {}
var _imported_sky_surface_report := {}
var _skybox_face_paths := {}
var _movement_audio_streams := {}
var _movement_audio_report := {}
var _movement_audio_event_counts := {}
var _movement_audio_next_player := 0
var _movement_audio_next_footstep_time := 0.0
var _movement_audio_next_stream_index := {}
var _movement_audio_floor_initialized := false
var _last_movement_audio_events: Array[String] = []


func configure(options: Dictionary) -> void:
	config_path = str(options.get("config_path", config_path))
	map_path = str(options.get("map_path", map_path))
	trace_enabled = bool(options.get("trace_enabled", trace_enabled))
	start_uncaptured = bool(options.get("start_uncaptured", start_uncaptured))
	auto_exit_sec = float(options.get("auto_exit_sec", auto_exit_sec))
	auto_forward_sec = float(options.get("auto_forward_sec", auto_forward_sec))
	fullscreen = bool(options.get("fullscreen", fullscreen))


func _ready() -> void:
	_apply_window_mode()
	set_process(true)
	set_physics_process(true)
	set_process_unhandled_input(true)
	_start_lab()


func _unhandled_input(event: InputEvent) -> void:
	if not _started:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var mouse_motion := event as InputEventMouseMotion
		_yaw -= mouse_motion.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - mouse_motion.relative.y * MOUSE_SENSITIVITY, MIN_PITCH, MAX_PITCH)
		_apply_camera_rotation()

	if event is InputEventMouseButton and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(_delta: float) -> void:
	if not _started:
		return

	if auto_exit_sec > 0.0 and _elapsed >= auto_exit_sec:
		_finish_and_quit("auto_exit")
		return

	if Input.is_key_pressed(KEY_F2):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_update_overlay()


func _physics_process(delta: float) -> void:
	if not _started or _runtime_session == null or _player_root == null:
		return

	_accumulator += minf(delta, 0.25)
	var fixed_delta: float = _settings.fixed_delta()
	var steps: int = 0
	while _accumulator >= fixed_delta and steps < MAX_RUNTIME_STEPS_PER_FRAME:
		_accumulator -= fixed_delta
		_elapsed += fixed_delta

		var input: Dictionary = _read_input()
		var before: Dictionary = _state_snapshot()
		var command_report: Dictionary = _queue_runtime_command(input)
		var jumped: bool = bool(command_report.get("wants_jump", false)) and bool(before.get("on_floor", false))
		var session_steps: int = _runtime_session.step(fixed_delta)
		if session_steps <= 0:
			continue
		_sync_presentation_from_snapshot()
		_tick = _runtime_session.current_tick
		var after: Dictionary = _state_snapshot()
		_update_movement_audio(
			input,
			bool(before.get("on_floor", false)),
			bool(after.get("on_floor", false)),
			bool(after.get("ducked", false)),
			jumped,
			_last_snapshot_velocity_ups
		)
		var trace_entry := _trace_entry(fixed_delta, input, command_report, before, after)
		_logger.record_tick(trace_entry)
		steps += 1

	if steps >= MAX_RUNTIME_STEPS_PER_FRAME:
		_accumulator = 0.0


func _exit_tree() -> void:
	if _logger != null and not _finished:
		_logger.finish("exit_tree")
		_finished = true


func _start_lab() -> void:
	_profile = ViewmodelWorldProfileRef.new()
	_profile.load_from_file()
	if not _profile.is_valid():
		push_error("Viewmodel/world profile is invalid: %s" % JSON.stringify(_profile.to_dictionary()))
		get_tree().quit(1)
		return

	_settings = MovementSettingsRef.new()
	_settings.max_speed = minf(_settings.max_speed, LAB_WALK_MAX_SPEED_UNITS)
	_asset_manager = AssetManagerRef.create_from_config_path(config_path)
	if not _asset_manager.is_available():
		push_error("GoldSrc asset manager is unavailable: %s" % JSON.stringify(_asset_manager.get_diagnostics()))
		get_tree().quit(1)
		return

	_provider = BspProviderRef.new()
	var load_result: Dictionary = _provider.load_map_from_vfs(_asset_manager.vfs, map_path, _profile.goldsrc_unit_scale)
	if not bool(load_result.get("ok", false)):
		push_error("BSP lab failed to load map: %s" % JSON.stringify(_report_without_node(load_result)))
		get_tree().quit(1)
		return

	_map_node = load_result["node"]
	_map_metadata = load_result.get("metadata", {})
	add_child(_map_node)
	_setup_entity_index()
	_setup_trace_backend()
	_non_blocking_collision_report = _disable_non_blocking_entity_collision()
	_imported_sky_surface_report = _hide_imported_sky_surface_meshes()

	_setup_world_lighting()
	_setup_player()
	_setup_skybox()
	_setup_movement_audio()
	_setup_overlay()
	_setup_trace_logger(load_result)

	if start_uncaptured:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_started = true
	print("OpenStrike BSP walkable lab started.")
	print("Map: %s" % map_path)
	print("Trace backend: %s" % str(_trace_backend_report.get("source", BspProviderRef.COLLISION_SOURCE_GODOT_SCENE)))
	print("Trace summary: %s" % _logger.get_paths().get("summary_path", ""))


func _setup_entity_index() -> void:
	_entity_index = MapEntityIndexRef.new()
	_entity_index.build_from_scene(_map_node)
	_map_entity_index_report = _entity_index.to_report()


func _setup_trace_backend() -> void:
	_trace_backend = TraceBackendRef.new()
	_trace_backend.setup(get_world_3d())
	_trace_backend_report = _trace_backend.capabilities()


func _setup_world_lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.28, 0.28)
	env.ambient_light_energy = 0.35
	environment.environment = env
	_environment = env
	add_child(environment)

	var light := DirectionalLight3D.new()
	light.name = "BspLabDirectionalLight"
	light.light_energy = 0.35
	light.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	add_child(light)


func _setup_player() -> void:
	_player_root = Node3D.new()
	_player_root.name = "BspLabSnapshotPlayer"
	add_child(_player_root)

	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPitchPivot"
	_player_root.add_child(_camera_pivot)

	_camera = Camera3D.new()
	_camera.name = "BspLabCamera"
	_profile.apply_to_camera(_camera, false)
	_camera.current = true
	_camera_pivot.add_child(_camera)

	_setup_runtime_session()
	_update_camera_height(false)
	_apply_camera_rotation()


func _setup_runtime_session() -> void:
	var runtime_spawn_index = RuntimeSpawnIndex.new(_entity_index, _profile.goldsrc_unit_scale)
	_runtime_session = LocalGameSessionRef.new()
	_runtime_session.configure(_settings.fixed_delta(), runtime_spawn_index, _settings, _trace_backend)
	_runtime_player_id = _runtime_session.add_player("bsp_walkable_local", PlayerSlotRef.TEAM_COUNTER_TERRORIST)
	_runtime_session.start_round(RoundStateRef.PHASE_LIVE)
	_sync_presentation_from_snapshot()
	_spawn_report = _spawn_report_from_snapshot()


func _setup_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BspLabOverlay"
	add_child(layer)

	_overlay = Label.new()
	_overlay.name = "TraceOverlay"
	_overlay.position = Vector2(12.0, 12.0)
	_overlay.size = Vector2(920.0, 170.0)
	_overlay.add_theme_font_size_override("font_size", 13)
	_overlay.modulate = Color(1.0, 0.72, 0.28, 0.92)
	layer.add_child(_overlay)
	_update_overlay()


func _setup_trace_logger(load_result: Dictionary) -> void:
	_logger = TraceLoggerRef.new()
	_logger.start({
		"map_path": map_path,
		"config_path_kind": _config_path_kind(config_path),
		"collision_source": str(_trace_backend_report.get("source", BspProviderRef.COLLISION_SOURCE_GODOT_SCENE)),
		"collision_confidence": str(_trace_backend_report.get("confidence", "")),
		"goldsrc_parity_collision_source": BspProviderRef.COLLISION_SOURCE_GOLDSRC_HULL_TRACE,
		"goldsrc_parity_collision": bool(_trace_backend_report.get("goldsrc_parity", false)),
		"trace_backend": _trace_backend_report,
		"scale_factor": _profile.goldsrc_unit_scale,
		"profile": _profile.to_dictionary(),
		"movement_settings": _settings.to_dictionary(),
		"movement_authority": "OpenStrikeLocalGameSession",
		"movement_adapter": "local_game_session_snapshot",
		"presentation_follows_snapshot": true,
		"runtime_session": {
			"player_id": _runtime_player_id,
			"fixed_delta": _settings.fixed_delta(),
			"snapshot_tick": int(_last_snapshot_report.get("tick", 0)),
		},
		"lab_max_speed_ups": LAB_WALK_MAX_SPEED_UNITS,
		"spawn": _spawn_report,
		"map_metadata": _map_metadata,
		"map_entity_index": _map_entity_index_report,
		"non_blocking_entity_collision": _non_blocking_collision_report,
		"skybox": _skybox_report,
		"imported_sky_surfaces": _imported_sky_surface_report,
		"movement_audio": _movement_audio_report,
		"movement_audio_events": _movement_audio_event_counts,
		"window": {
			"fullscreen": fullscreen,
		},
		"auto_forward_sec": auto_forward_sec,
		"capabilities": load_result.get("capabilities", {}),
		"controls": "WASD move, mouse look, Space jump, Ctrl/C duck, F2 release mouse, Cmd+Q/window close quits",
	}, trace_enabled)


func _apply_window_mode() -> void:
	if not fullscreen:
		return
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if window == null:
		return
	window.mode = Window.MODE_FULLSCREEN


func _setup_skybox() -> void:
	_skybox_report = _resolve_skybox()
	if not bool(_skybox_report.get("complete", false)):
		return

	var panorama := _create_skybox_panorama_texture()
	if panorama == null:
		_skybox_report["status"] = "panorama_failed"
		return

	var material := PanoramaSkyMaterial.new()
	material.panorama = panorama
	var sky := Sky.new()
	sky.sky_material = material
	if _environment != null:
		_environment.background_mode = Environment.BG_SKY
		_environment.sky = sky
	_skybox_report["status"] = "loaded_panorama"
	_skybox_report["render_mode"] = "environment_panorama"


func _resolve_skybox() -> Dictionary:
	_skybox_face_paths.clear()
	var worldspawn: Dictionary = _map_metadata.get("worldspawn", {})
	var skyname := str(worldspawn.get("skyname", "")).strip_edges().to_lower()
	var report := {
		"skyname": skyname,
		"candidate": "",
		"candidates": [],
		"complete": false,
		"status": "missing_skyname",
		"faces": {},
	}
	if skyname == "":
		return report

	var candidates := _skybox_candidates(skyname)
	report["candidates"] = candidates
	report["status"] = "missing_faces"
	for candidate in candidates:
		var face_reports := {}
		var face_paths := {}
		var complete := true
		for suffix in SKYBOX_FACE_SUFFIXES:
			var resolved := _resolve_skybox_face(candidate, suffix)
			face_reports[suffix] = {
				"found": bool(resolved.get("found", false)),
				"relative_path": str(resolved.get("relative_path", "")),
			}
			if bool(resolved.get("found", false)):
				face_paths[suffix] = str(resolved.get("resolved_path", ""))
			else:
				complete = false

		if str(report.get("candidate", "")) == "":
			report["candidate"] = candidate
			report["faces"] = face_reports
		if complete:
			_skybox_face_paths = face_paths
			report["candidate"] = candidate
			report["faces"] = face_reports
			report["complete"] = true
			report["status"] = "loaded"
			return report

	return report


func _skybox_candidates(skyname: String) -> Array[String]:
	var output: Array[String] = []
	var aliases = SKYBOX_ALIAS_BY_SKYNAME.get(skyname, [skyname])
	for alias in aliases:
		var candidate := str(alias).strip_edges().to_lower()
		if candidate != "" and not output.has(candidate):
			output.append(candidate)
	return output


func _resolve_skybox_face(candidate: String, suffix: String) -> Dictionary:
	for extension in SKYBOX_EXTENSIONS:
		var relative_path := "gfx/env/%s%s.%s" % [candidate, suffix, extension]
		var resolved: Dictionary = _asset_manager.resolve_asset(relative_path)
		if bool(resolved.get("found", false)):
			return {
				"found": true,
				"relative_path": relative_path,
				"resolved_path": str(resolved.get("resolved_path", "")),
			}
	return {
		"found": false,
		"relative_path": "gfx/env/%s%s.%s" % [candidate, suffix, SKYBOX_EXTENSIONS[0]],
		"resolved_path": "",
	}


func _create_skybox_panorama_texture() -> Texture2D:
	var face_images: Dictionary = {}
	for suffix in SKYBOX_FACE_SUFFIXES:
		var image_path := str(_skybox_face_paths.get(suffix, ""))
		if image_path == "":
			return null
		var image := Image.new()
		var error := image.load(image_path)
		if error != OK:
			var faces: Dictionary = _skybox_report.get("faces", {})
			if faces.has(suffix) and faces[suffix] is Dictionary:
				var face: Dictionary = faces[suffix]
				face["load_error"] = error
				faces[suffix] = face
				_skybox_report["faces"] = faces
			return null
		face_images[suffix] = image

	var face_size := int((face_images["ft"] as Image).get_width())
	var panorama_width := face_size * 4
	var panorama_height := face_size * 2
	var panorama := Image.create(panorama_width, panorama_height, false, Image.FORMAT_RGB8)

	for y in range(panorama_height):
		var v := (float(y) + 0.5) / float(panorama_height)
		var pitch := (0.5 - v) * PI
		var cos_pitch := cos(pitch)
		for x in range(panorama_width):
			var u := (float(x) + 0.5) / float(panorama_width)
			var yaw := (u - 0.5) * TAU
			var direction := Vector3(sin(yaw) * cos_pitch, sin(pitch), -cos(yaw) * cos_pitch)
			panorama.set_pixel(x, y, _sample_skybox_color(face_images, direction))

	_skybox_report["panorama_size"] = [panorama_width, panorama_height]
	return ImageTexture.create_from_image(panorama)


func _sample_skybox_color(face_images: Dictionary, direction: Vector3) -> Color:
	var abs_x := absf(direction.x)
	var abs_y := absf(direction.y)
	var abs_z := absf(direction.z)
	var suffix := "ft"
	var u_axis := 0.0
	var v_axis := 0.0

	if abs_x >= abs_y and abs_x >= abs_z:
		if direction.x >= 0.0:
			suffix = "rt"
			u_axis = -direction.z / abs_x
		else:
			suffix = "lf"
			u_axis = direction.z / abs_x
		v_axis = -direction.y / abs_x
	elif abs_y >= abs_x and abs_y >= abs_z:
		if direction.y >= 0.0:
			suffix = "up"
			u_axis = direction.x / abs_y
			v_axis = direction.z / abs_y
		else:
			suffix = "dn"
			u_axis = direction.x / abs_y
			v_axis = -direction.z / abs_y
	else:
		if direction.z >= 0.0:
			suffix = "bk"
			u_axis = direction.x / abs_z
		else:
			suffix = "ft"
			u_axis = -direction.x / abs_z
		v_axis = -direction.y / abs_z

	var image := face_images[suffix] as Image
	var pixel_x := clampi(int(((u_axis + 1.0) * 0.5) * float(image.get_width() - 1)), 0, image.get_width() - 1)
	var pixel_y := clampi(int(((v_axis + 1.0) * 0.5) * float(image.get_height() - 1)), 0, image.get_height() - 1)
	return image.get_pixel(pixel_x, pixel_y)


func _hide_imported_sky_surface_meshes() -> Dictionary:
	var report := {
		"hidden_mesh_instances": 0,
		"match_rule": "MeshInstance3D.name == sky",
	}
	var stack: Array[Node] = []
	if _map_node != null:
		stack.append(_map_node)

	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D and current.name.to_lower() == "sky":
			(current as MeshInstance3D).visible = false
			report["hidden_mesh_instances"] = int(report["hidden_mesh_instances"]) + 1
		for child in current.get_children():
			if child is Node:
				stack.append(child)

	return report


func _setup_movement_audio() -> void:
	_movement_audio_streams.clear()
	_movement_audio_report = {
		"status": "configured",
		"material_profile": "default_hard_surface",
		"crouch_footsteps": "silent",
		"sounds": {},
	}
	_movement_audio_event_counts = {
		"footstep": 0,
		"jump": 0,
		"land": 0,
	}
	_movement_audio_next_stream_index.clear()
	_movement_audio_next_player = 0
	_movement_audio_next_footstep_time = 0.0

	for index in range(MOVEMENT_SOUND_PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "MovementAudioPlayer%d" % index
		player.volume_db = MOVEMENT_SOUND_VOLUME_DB
		add_child(player)
		_movement_audio_players.append(player)

	for sound_key in MOVEMENT_SOUND_PATHS.keys():
		var streams: Array[AudioStream] = []
		var entries: Array[Dictionary] = []
		for relative_path in MOVEMENT_SOUND_PATHS[sound_key]:
			var entry := {
				"relative_path": str(relative_path),
				"found": false,
				"loaded": false,
			}
			var resolved: Dictionary = _asset_manager.resolve_asset(str(relative_path))
			if bool(resolved.get("found", false)):
				entry["found"] = true
				var stream := AudioStreamWAV.load_from_file(str(resolved.get("resolved_path", "")))
				if stream != null:
					entry["loaded"] = true
					streams.append(stream)
			entries.append(entry)
		_movement_audio_streams[str(sound_key)] = streams
		_movement_audio_next_stream_index[str(sound_key)] = 0
		var sounds: Dictionary = _movement_audio_report["sounds"]
		sounds[str(sound_key)] = {
			"loaded_count": streams.size(),
			"entries": entries,
		}
		_movement_audio_report["sounds"] = sounds


func _play_movement_audio(sound_key: String) -> void:
	var streams: Array = _movement_audio_streams.get(sound_key, [])
	if streams.is_empty() or _movement_audio_players.is_empty():
		return

	var stream_index := int(_movement_audio_next_stream_index.get(sound_key, 0)) % streams.size()
	_movement_audio_next_stream_index[sound_key] = stream_index + 1

	var player := _movement_audio_players[_movement_audio_next_player % _movement_audio_players.size()]
	_movement_audio_next_player += 1
	player.stop()
	player.stream = streams[stream_index]
	player.volume_db = MOVEMENT_SOUND_VOLUME_DB
	player.play()

	_last_movement_audio_events.append(sound_key)
	_movement_audio_event_counts[sound_key] = int(_movement_audio_event_counts.get(sound_key, 0)) + 1


func _update_movement_audio(input: Dictionary, started_on_floor: bool, now_on_floor: bool, ducked: bool, jumped: bool, velocity_ups: Vector3) -> void:
	var horizontal_speed := Vector2(velocity_ups.x, velocity_ups.z).length()
	var moving_input := absf(float(input.get("forward", 0.0))) > 0.01 or absf(float(input.get("side", 0.0))) > 0.01

	if not _movement_audio_floor_initialized:
		_movement_audio_floor_initialized = now_on_floor
		_last_on_floor = now_on_floor
		if not jumped:
			return

	if jumped:
		_play_movement_audio("jump")

	if _tick > 2 and not _last_on_floor and now_on_floor:
		_play_movement_audio("land")
		_movement_audio_next_footstep_time = _elapsed + FOOTSTEP_SLOW_INTERVAL_SEC

	if now_on_floor and not ducked and moving_input and horizontal_speed >= FOOTSTEP_MIN_SPEED_UPS:
		if _elapsed >= _movement_audio_next_footstep_time:
			_play_movement_audio("footstep")
			var speed_alpha := clampf(
				(horizontal_speed - FOOTSTEP_MIN_SPEED_UPS) / maxf(LAB_WALK_MAX_SPEED_UNITS - FOOTSTEP_MIN_SPEED_UPS, 1.0),
				0.0,
				1.0
			)
			_movement_audio_next_footstep_time = _elapsed + lerpf(FOOTSTEP_SLOW_INTERVAL_SEC, FOOTSTEP_FAST_INTERVAL_SEC, speed_alpha)
	elif not started_on_floor or ducked:
		_movement_audio_next_footstep_time = _elapsed + FOOTSTEP_FAST_INTERVAL_SEC

	_last_on_floor = now_on_floor


func _read_input() -> Dictionary:
	var forward := 0.0
	var side := 0.0
	if Input.is_key_pressed(KEY_W):
		forward += 1.0
	if auto_forward_sec > 0.0 and _elapsed < auto_forward_sec:
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
		"jump": jump_held,
		"jump_pressed": jump_held and not _last_jump_held,
		"duck": Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C),
	}
	_last_jump_held = jump_held
	return input


func _queue_runtime_command(input: Dictionary) -> Dictionary:
	var command = UserCommandRef.new()
	var command_tick: int = _runtime_session.current_tick + 1
	var command_forward := -float(input.get("forward", 0.0))
	var command_side := float(input.get("side", 0.0))
	command.configure(
		command_tick,
		_runtime_player_id,
		command_forward,
		command_side,
		bool(input.get("jump_pressed", false)),
		bool(input.get("duck", false)),
		_yaw,
		_pitch
	)
	var accepted: bool = _runtime_session.queue_command(command)
	var report: Dictionary = command.to_dictionary()
	report["accepted"] = accepted
	report["presentation_input"] = input.duplicate(true)
	return report


func _update_camera_height(ducked: bool) -> void:
	if _camera_pivot == null:
		return
	_camera_pivot.position.y = _profile.scaled_units(_profile.view_offset_duck if ducked else _profile.view_offset_stand)


func _apply_camera_rotation() -> void:
	if _player_root != null:
		_player_root.rotation.y = _yaw
	if _camera_pivot != null:
		_camera_pivot.rotation.x = _pitch


func _sync_presentation_from_snapshot() -> void:
	if _runtime_session == null:
		return
	_last_snapshot_report = _runtime_session.snapshot().to_dictionary()
	_last_player_snapshot = _snapshot_player(_last_snapshot_report)
	if _last_player_snapshot.is_empty():
		return

	var origin_units: Vector3 = _vector_from_value(_last_player_snapshot.get("origin", Vector3.ZERO))
	_last_snapshot_velocity_ups = _vector_from_value(_last_player_snapshot.get("velocity", Vector3.ZERO))
	_yaw = float(_last_player_snapshot.get("view_yaw", _yaw))
	_pitch = float(_last_player_snapshot.get("view_pitch", _pitch))
	if _player_root != null:
		_player_root.global_position = _runtime_units_to_godot(origin_units)
	_update_camera_height(bool(_last_player_snapshot.get("ducked", false)))
	_update_snapshot_contact_report()
	_apply_camera_rotation()


func _snapshot_player(snapshot_report: Dictionary) -> Dictionary:
	var players: Array = snapshot_report.get("players", [])
	for player_variant in players:
		if not player_variant is Dictionary:
			continue
		var player: Dictionary = player_variant
		if int(player.get("player_id", 0)) == _runtime_player_id:
			return player.duplicate(true)
	return {}


func _spawn_report_from_snapshot() -> Dictionary:
	if _last_player_snapshot.is_empty():
		return {
			"classname": "missing_runtime_snapshot",
			"source": "local_game_session_snapshot",
		}
	var spawn_units: Vector3 = _vector_from_value(_last_player_snapshot.get("spawn_position", Vector3.ZERO))
	return {
		"classname": str(_last_player_snapshot.get("spawn_classname", "")),
		"position_units": _vector_to_array(spawn_units),
		"position_godot": _vector_to_array(_runtime_units_to_godot(spawn_units)),
		"yaw": float(_last_player_snapshot.get("spawn_yaw", 0.0)),
		"source": "local_game_session_snapshot",
	}


func _disable_non_blocking_entity_collision() -> Dictionary:
	var report := {
		"disabled_entity_count": 0,
		"disabled_collision_object_count": 0,
		"disabled_collision_shape_count": 0,
		"classes": {},
		"source": "map_entity_index_collision_policy",
	}
	if _entity_index == null:
		return report

	for entry in _entity_index.entries_for_player_collision_disabled():
		var current = entry.get("node", null)
		if not current is Node:
			continue
		var disabled := _disable_collision_tree(current)
		report["disabled_entity_count"] = int(report["disabled_entity_count"]) + 1
		report["disabled_collision_object_count"] = int(report["disabled_collision_object_count"]) + int(disabled.get("collision_objects", 0))
		report["disabled_collision_shape_count"] = int(report["disabled_collision_shape_count"]) + int(disabled.get("collision_shapes", 0))
		var classname := str(entry.get("classname", ""))
		var classes: Dictionary = report["classes"]
		classes[classname] = int(classes.get(classname, 0)) + 1
		report["classes"] = classes

	return report


func _disable_collision_tree(root: Node) -> Dictionary:
	var counts := {
		"collision_objects": 0,
		"collision_shapes": 0,
	}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is CollisionObject3D:
			var collision_object := current as CollisionObject3D
			collision_object.collision_layer = 0
			collision_object.collision_mask = 0
			counts["collision_objects"] = int(counts["collision_objects"]) + 1
		if current is CollisionShape3D:
			(current as CollisionShape3D).disabled = true
			counts["collision_shapes"] = int(counts["collision_shapes"]) + 1
		for child in current.get_children():
			if child is Node:
				stack.append(child)
	return counts


func _state_snapshot() -> Dictionary:
	if _last_player_snapshot.is_empty():
		return {}
	var origin_units: Vector3 = _vector_from_value(_last_player_snapshot.get("origin", Vector3.ZERO))
	var velocity_units: Vector3 = _vector_from_value(_last_player_snapshot.get("velocity", Vector3.ZERO))
	var position_godot: Vector3 = _runtime_units_to_godot(origin_units)
	return {
		"position_units": _vector_to_array(origin_units),
		"position_godot": _vector_to_array(position_godot),
		"velocity_godot": _vector_to_array(_runtime_units_to_godot(velocity_units)),
		"velocity_ups": _vector_to_array(velocity_units),
		"yaw": _yaw,
		"pitch": _pitch,
		"ducked": bool(_last_player_snapshot.get("ducked", false)),
		"on_floor": bool(_last_player_snapshot.get("on_ground", false)),
		"floor_normal": _vector_to_array(_snapshot_floor_normal()),
		"movement_state": _movement_state_report(),
	}


func _trace_entry(delta: float, input: Dictionary, command_report: Dictionary, before: Dictionary, after: Dictionary) -> Dictionary:
	var horizontal_speed := Vector2(_last_snapshot_velocity_ups.x, _last_snapshot_velocity_ups.z).length()
	var position_delta: float = _presentation_snapshot_position_delta()
	return {
		"tick": _tick,
		"time_sec": _elapsed,
		"delta": delta,
		"map_path": map_path,
		"collision_source": str(_trace_backend_report.get("source", BspProviderRef.COLLISION_SOURCE_GODOT_SCENE)),
		"collision_confidence": str(_trace_backend_report.get("confidence", "")),
		"goldsrc_parity_collision": bool(_trace_backend_report.get("goldsrc_parity", false)),
		"movement_authority": "OpenStrikeLocalGameSession",
		"presentation_follows_snapshot": position_delta <= 0.001,
		"presentation_snapshot_position_delta": position_delta,
		"runtime_snapshot_tick": int(_last_snapshot_report.get("tick", _tick)),
		"command": command_report,
		"input": input,
		"before": before,
		"after": after,
		"position_units": after.get("position_units", []),
		"position_godot": after.get("position_godot", []),
		"velocity_ups": _vector_to_array(_last_snapshot_velocity_ups),
		"speed_ups": _last_snapshot_velocity_ups.length(),
		"horizontal_speed_ups": horizontal_speed,
		"step_up_attempted": _last_snapshot_step_up_attempted,
		"step_up_applied": _last_snapshot_step_up_applied,
		"movement_audio_events": _last_movement_audio_events.duplicate(),
		"on_floor": bool(after.get("on_floor", false)),
		"floor_normal": after.get("floor_normal", []),
		"slide_collision_count": _last_snapshot_slide_reports.size(),
		"slide_collisions": _slide_reports(),
		"movement_state": _movement_state_report(),
	}


func _slide_reports() -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	for report in _last_snapshot_slide_reports:
		reports.append(report.duplicate(true))
	return reports


func _update_snapshot_contact_report() -> void:
	_last_snapshot_slide_reports.clear()
	_last_snapshot_step_up_attempted = false
	_last_snapshot_step_up_applied = false

	var trace_summary: Dictionary = _snapshot_trace_summary()
	var contact: Dictionary = trace_summary.get("contact", {}) if trace_summary.get("contact", {}) is Dictionary else {}
	var step: Dictionary = contact.get("step", {}) if contact.get("step", {}) is Dictionary else {}
	_last_snapshot_step_up_attempted = bool(step.get("attempted", false))
	_last_snapshot_step_up_applied = bool(step.get("selected", false))

	var contacts = contact.get("contacts", [])
	if not contacts is Array:
		return
	var index := 0
	for contact_variant in contacts:
		if not contact_variant is Dictionary:
			continue
		var contact_entry: Dictionary = contact_variant
		_last_snapshot_slide_reports.append({
			"index": index,
			"position": contact_entry.get("position", []),
			"normal": contact_entry.get("normal", []),
			"contents": str(contact_entry.get("contents", "")),
			"contents_code": int(contact_entry.get("contents_code", 0)),
			"model_index": int(contact_entry.get("model_index", -1)),
			"source": "local_game_session_snapshot",
		})
		index += 1


func _movement_state_report() -> Dictionary:
	if _last_player_snapshot.is_empty():
		return {}
	var movement_state = _last_player_snapshot.get("movement_state", {})
	return movement_state.duplicate(true) if movement_state is Dictionary else {}


func _snapshot_trace_summary() -> Dictionary:
	var movement_state: Dictionary = _movement_state_report()
	var trace_summary = movement_state.get("last_trace_summary", {})
	return trace_summary.duplicate(true) if trace_summary is Dictionary else {}


func _snapshot_floor_normal() -> Vector3:
	var slide_reports: Array[Dictionary] = _last_snapshot_slide_reports
	for report in slide_reports:
		var normal: Vector3 = _vector_from_value(report.get("normal", Vector3.ZERO))
		if normal.length_squared() > 0.0 and normal.y > 0.5:
			return normal.normalized()
	if bool(_last_player_snapshot.get("on_ground", false)):
		return Vector3.UP
	return Vector3.ZERO


func _presentation_snapshot_position_delta() -> float:
	if _player_root == null or _last_player_snapshot.is_empty():
		return INF
	var origin_units: Vector3 = _vector_from_value(_last_player_snapshot.get("origin", Vector3.ZERO))
	var snapshot_position_godot: Vector3 = _runtime_units_to_godot(origin_units)
	return _player_root.global_position.distance_to(snapshot_position_godot)


func _runtime_units_to_godot(value: Vector3) -> Vector3:
	return value * _profile.goldsrc_unit_scale


func _update_overlay() -> void:
	if _overlay == null or _logger == null or _player_root == null:
		return
	var paths: Dictionary = _logger.get_paths()
	var horizontal_speed := Vector2(_last_snapshot_velocity_ups.x, _last_snapshot_velocity_ups.z).length()
	_overlay.text = (
		"OpenStrike BSP walkable lab | %s | authority=LocalGameSession | collision=%s:%s | sky=%s:%s\n"
		+ "WASD move  Mouse look  Space jump  Ctrl/C duck  F2 release mouse  Cmd+Q/window close quit\n"
		+ "pos=%s vel_ups=%s speed=%.1f hspeed=%.1f floor=%s slides=%d\n"
		+ "trace=%s"
	) % [
		map_path,
		str(_trace_backend_report.get("source", BspProviderRef.COLLISION_SOURCE_GODOT_SCENE)),
		str(_trace_backend_report.get("confidence", "")),
		str(_skybox_report.get("skyname", "")),
		str(_skybox_report.get("status", "")),
		str(_player_root.global_position.snapped(Vector3(0.001, 0.001, 0.001))),
		str(_last_snapshot_velocity_ups.snapped(Vector3(0.1, 0.1, 0.1))),
		_last_snapshot_velocity_ups.length(),
		horizontal_speed,
		str(_last_player_snapshot.get("on_ground", false)),
		_last_snapshot_slide_reports.size(),
		str(paths.get("trace_path", "")),
	]


func _finish_and_quit(reason: String) -> void:
	if _logger != null and not _finished:
		_logger.finish(reason)
		_finished = true
	get_tree().quit(0)


func _report_without_node(load_result: Dictionary) -> Dictionary:
	var clone := load_result.duplicate(true)
	clone.erase("node")
	return clone


func _config_path_kind(path: String) -> String:
	if path.begins_with("user://"):
		return "user"
	if path.begins_with("res://"):
		return "repo"
	return "absolute_or_external"


func _vector_from_value(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
