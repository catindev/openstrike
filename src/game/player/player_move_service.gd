extends RefCounted

class_name OpenStrikePlayerMoveService

const MovementInputRef = preload("res://src/game/movement/cs_movement_input.gd")
const MovementSettingsRef = preload("res://src/game/movement/cs_movement_settings.gd")
const MovementSimulatorRef = preload("res://src/game/movement/cs_movement_simulator.gd")
const MovementStateRef = preload("res://src/game/movement/cs_movement_state.gd")
const MoveCommandRef = preload("res://src/game/player/player_move_command.gd")
const MoveResultRef = preload("res://src/game/player/player_move_result.gd")
const PlayerStateRef = preload("res://src/game/player/player_state.gd")

const TRACE_MODE_FREE_VOLUME := "free_volume"

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

	simulator.step(sim_state, sim_input, frame_delta)

	var next_state = PlayerStateRef.new()
	var trace_summary := _trace_summary(sim_state, active_settings, active_backend)
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


func _trace_summary(sim_state, active_settings, active_backend) -> Dictionary:
	var summary := {
		"mode": TRACE_MODE_FREE_VOLUME,
		"contact_movement": false,
		"trace_backend_used": false,
		"ground_height": sim_state.ground_height,
		"hull": {
			"kind": "duck" if sim_state.ducked else "standing",
			"height": active_settings.duck_height if sim_state.ducked else active_settings.stand_height,
		},
	}
	if active_backend != null and active_backend.has_method("capabilities"):
		summary["trace_backend_capabilities"] = active_backend.call("capabilities")
	return summary


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
