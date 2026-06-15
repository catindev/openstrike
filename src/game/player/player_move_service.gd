extends RefCounted

class_name OpenStrikePlayerMoveService

const MovementInputRef = preload("res://src/game/movement/cs_movement_input.gd")
const MovementSettingsRef = preload("res://src/game/movement/cs_movement_settings.gd")
const MovementSimulatorRef = preload("res://src/game/movement/cs_movement_simulator.gd")
const MovementStateRef = preload("res://src/game/movement/cs_movement_state.gd")
const CollisionHullRef = preload("res://src/core/collision/openstrike_collision_hull.gd")
const MoveCommandRef = preload("res://src/game/player/player_move_command.gd")
const MoveResultRef = preload("res://src/game/player/player_move_result.gd")
const PlayerStateRef = preload("res://src/game/player/player_state.gd")
const TraceBackendRef = preload("res://src/core/collision/openstrike_trace_backend.gd")

const TRACE_MODE_FREE_VOLUME := "free_volume"
const TRACE_MODE_SYNTHETIC_CONTACT := "synthetic_bsp_contact"
const CONTACT_TRACE_ITERATIONS := 4
const CONTACT_EPSILON := 0.001
const PLAYER_HALF_WIDTH := 16.0

var settings = null
var trace_backend = null


func _init(custom_settings = null, custom_trace_backend = null) -> void:
	settings = custom_settings if custom_settings != null else MovementSettingsRef.new()
	trace_backend = custom_trace_backend


func configure(custom_settings = null, custom_trace_backend = null) -> void:
	settings = custom_settings if custom_settings != null else MovementSettingsRef.new()
	trace_backend = custom_trace_backend


func move(player_state, move_command, move_settings = null, backend = null):
	var active_settings = move_settings if move_settings != null else settings
	var active_backend = backend if backend != null else trace_backend
	var simulator = MovementSimulatorRef.new(active_settings)
	var sim_state = _to_movement_state(player_state, active_settings)
	var sim_input = _to_movement_input(move_command)
	var frame_delta: float = _command_frametime(move_command, active_settings)
	var start_position: Vector3 = sim_state.position

	simulator.step(sim_state, sim_input, frame_delta)
	var contact_summary := _apply_contact_movement(
		start_position,
		sim_state.position,
		sim_state.velocity,
		sim_state,
		active_settings,
		active_backend,
		frame_delta
	)
	if bool(contact_summary.get("used", false)):
		sim_state.position = contact_summary.get("position", sim_state.position)
		sim_state.velocity = contact_summary.get("velocity", sim_state.velocity)

	var next_state = PlayerStateRef.new()
	var trace_summary := _trace_summary(sim_state, active_settings, active_backend, contact_summary)
	next_state.configure(
		sim_state.position,
		sim_state.velocity,
		_command_float(move_command, "view_yaw"),
		_command_float(move_command, "view_pitch"),
		sim_state.ducked,
		sim_state.on_ground,
		_state_flags(player_state),
		trace_summary
	)

	var result = MoveResultRef.new()
	result.configure(next_state, move_command, trace_summary, true)
	return result


func _apply_contact_movement(
	start_position: Vector3,
	target_position: Vector3,
	velocity: Vector3,
	sim_state,
	active_settings,
	active_backend,
	frame_delta: float
) -> Dictionary:
	var summary := _empty_contact_summary(start_position, target_position, velocity)
	if not _should_use_contact_backend(active_backend):
		return summary

	summary["used"] = true
	summary["mode"] = TRACE_MODE_SYNTHETIC_CONTACT
	var hull = _collision_hull(sim_state, active_settings)
	var current_position := start_position
	var current_velocity := velocity
	var current_target := target_position

	for iteration in range(CONTACT_TRACE_ITERATIONS):
		if current_position.distance_to(current_target) <= CONTACT_EPSILON:
			break

		var trace = active_backend.call("trace_hull", current_position, current_target, hull)
		var report: Dictionary = trace.call("to_dictionary") if trace != null and trace.has_method("to_dictionary") else {}
		summary["iterations"] = int(summary.get("iterations", 0)) + 1
		summary["traces"].append(report)

		if not bool(report.get("supported", false)):
			summary["diagnostics"].append({
				"level": "warning",
				"code": "contact_trace_unsupported",
				"message": "Contact movement requested a backend trace that did not return supported trace data.",
				"context": report,
			})
			summary["used"] = false
			summary["mode"] = TRACE_MODE_FREE_VOLUME
			break

		if bool(report.get("start_solid", false)):
			summary["blocked"] = true
			summary["start_solid"] = true
			current_target = current_position
			current_velocity = _slide_velocity(current_velocity, _vector_from_value(report.get("normal", Vector3.ZERO)))
			break

		if not bool(report.get("hit", false)) or float(report.get("fraction", 1.0)) >= 1.0:
			current_position = current_target
			break

		var hit_position := _vector_from_value(report.get("hit_position", current_position))
		var normal := _vector_from_value(report.get("normal", Vector3.ZERO))
		var fraction := clampf(float(report.get("fraction", 1.0)), 0.0, 1.0)
		current_position = hit_position
		current_velocity = _slide_velocity(current_velocity, normal)
		summary["blocked"] = true
		summary["contacts"].append({
			"iteration": iteration,
			"fraction": fraction,
			"position": _vector_to_array(hit_position),
			"normal": _vector_to_array(normal),
			"contents": str(report.get("contents", "")),
			"contents_code": int(report.get("contents_code", 0)),
			"model_index": int(report.get("model_index", -1)),
		})

		var remaining_fraction := 1.0 - fraction
		if remaining_fraction <= CONTACT_EPSILON or current_velocity.length_squared() <= CONTACT_EPSILON * CONTACT_EPSILON:
			current_target = current_position
			break
		current_target = current_position + current_velocity * frame_delta * remaining_fraction

	summary["position"] = current_position
	summary["velocity"] = current_velocity
	return summary


func _empty_contact_summary(start_position: Vector3, target_position: Vector3, velocity: Vector3) -> Dictionary:
	return {
		"used": false,
		"mode": TRACE_MODE_FREE_VOLUME,
		"iterations": 0,
		"blocked": false,
		"start_solid": false,
		"start": _vector_to_array(start_position),
		"target": _vector_to_array(target_position),
		"position": target_position,
		"velocity": velocity,
		"contacts": [],
		"traces": [],
		"diagnostics": [],
	}


func _to_movement_state(player_state, active_settings):
	var sim_state = MovementStateRef.new()
	if player_state != null and player_state.has_method("to_dictionary"):
		var state_data: Dictionary = player_state.call("to_dictionary")
		sim_state.position = _vector_from_value(state_data.get("origin", Vector3.ZERO))
		sim_state.velocity = _vector_from_value(state_data.get("velocity", Vector3.ZERO))
		sim_state.ducked = bool(state_data.get("ducked", false))
		sim_state.on_ground = bool(state_data.get("on_ground", true))
		var last_trace = state_data.get("last_trace_summary", {})
		if last_trace is Dictionary:
			sim_state.ground_height = float(last_trace.get("ground_height", 0.0))
	sim_state.body_height = active_settings.duck_height if sim_state.ducked else active_settings.stand_height
	return sim_state


func _to_movement_input(move_command):
	return MovementInputRef.new(
		_command_float(move_command, "forward_move"),
		_command_float(move_command, "side_move"),
		_command_bool(move_command, "wants_jump"),
		_command_bool(move_command, "wants_duck")
	)


func _trace_summary(sim_state, active_settings, active_backend, contact_summary: Dictionary = {}) -> Dictionary:
	var contact_used := bool(contact_summary.get("used", false))
	var summary := {
		"mode": str(contact_summary.get("mode", TRACE_MODE_FREE_VOLUME)),
		"contact_movement": contact_used,
		"trace_backend_used": contact_used,
		"ground_height": sim_state.ground_height,
		"hull": {
			"kind": "duck" if sim_state.ducked else "standing",
			"height": active_settings.duck_height if sim_state.ducked else active_settings.stand_height,
		},
	}
	if active_backend != null and active_backend.has_method("capabilities"):
		summary["trace_backend_capabilities"] = active_backend.call("capabilities")
	if contact_used:
		summary["contact"] = _contact_summary_for_report(contact_summary)
	return summary


func _contact_summary_for_report(contact_summary: Dictionary) -> Dictionary:
	return {
		"iterations": int(contact_summary.get("iterations", 0)),
		"blocked": bool(contact_summary.get("blocked", false)),
		"start_solid": bool(contact_summary.get("start_solid", false)),
		"start": contact_summary.get("start", []),
		"target": contact_summary.get("target", []),
		"position": _vector_to_array(contact_summary.get("position", Vector3.ZERO)),
		"velocity": _vector_to_array(contact_summary.get("velocity", Vector3.ZERO)),
		"contacts": contact_summary.get("contacts", []).duplicate(true),
		"traces": contact_summary.get("traces", []).duplicate(true),
	}


func _should_use_contact_backend(active_backend) -> bool:
	if active_backend == null or not active_backend.has_method("trace_hull") or not active_backend.has_method("capabilities"):
		return false
	var capabilities: Dictionary = active_backend.call("capabilities")
	return (
		str(capabilities.get("source", "")) == TraceBackendRef.SOURCE_GOLDSRC_HULL_TRACE
		and str(capabilities.get("confidence", "")) == TraceBackendRef.CONFIDENCE_SYNTHETIC_VERIFIED
		and str(capabilities.get("trace_hull", "")) == TraceBackendRef.CAP_SUPPORTED_BY_SYNTHETIC_BSP_FIXTURE
	)


func _collision_hull(sim_state, active_settings):
	var hull = CollisionHullRef.new()
	var half_height: float = (active_settings.duck_height if sim_state.ducked else active_settings.stand_height) * 0.5
	var kind := CollisionHullRef.KIND_PLAYER_DUCKING if sim_state.ducked else CollisionHullRef.KIND_PLAYER_STANDING
	hull.configure(
		kind,
		Vector3(-PLAYER_HALF_WIDTH, -PLAYER_HALF_WIDTH, -half_height),
		Vector3(PLAYER_HALF_WIDTH, PLAYER_HALF_WIDTH, half_height)
	)
	return hull


func _slide_velocity(velocity: Vector3, normal: Vector3) -> Vector3:
	if normal.length_squared() <= 0.0:
		return velocity
	var normalized := normal.normalized()
	var into_plane := velocity.dot(normalized)
	if into_plane >= 0.0:
		return velocity
	return velocity - normalized * into_plane


func _command_frametime(move_command, active_settings) -> float:
	if move_command != null:
		var value: float = _command_float(move_command, "frametime")
		if value > 0.0:
			return value
	return active_settings.fixed_delta()


func _command_float(move_command, property_name: String) -> float:
	if move_command == null:
		return 0.0
	return float(move_command.get(property_name))


func _command_bool(move_command, property_name: String) -> bool:
	if move_command == null:
		return false
	return bool(move_command.get(property_name))


func _state_flags(player_state) -> int:
	if player_state == null:
		return PlayerStateRef.FLAG_NONE
	return int(player_state.get("flags"))


func _vector_from_value(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
