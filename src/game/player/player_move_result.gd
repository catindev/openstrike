extends RefCounted

class_name OpenStrikePlayerMoveResult

const MoveCommandRef = preload("res://src/game/player/player_move_command.gd")
const PlayerStateRef = preload("res://src/game/player/player_state.gd")

var accepted := true
var state = null
var command = null
var trace_summary := {}
var diagnostics: Array[Dictionary] = []


func configure(result_state, result_command = null, result_trace_summary: Dictionary = {}, result_accepted: bool = true) -> void:
	state = result_state
	command = result_command
	trace_summary = result_trace_summary.duplicate(true)
	accepted = result_accepted
	diagnostics.clear()


func configure_from_dictionary(data: Dictionary) -> void:
	accepted = bool(data.get("accepted", true))
	trace_summary = data.get("trace_summary", {}).duplicate(true) if data.get("trace_summary", {}) is Dictionary else {}

	state = null
	var state_data = data.get("state", {})
	if state_data is Dictionary:
		state = PlayerStateRef.new()
		state.configure_from_dictionary(state_data)

	command = null
	var command_data = data.get("command", {})
	if command_data is Dictionary:
		command = MoveCommandRef.new()
		command.configure_from_dictionary(command_data)

	diagnostics.clear()
	var raw_diagnostics = data.get("diagnostics", [])
	if raw_diagnostics is Array:
		for entry in raw_diagnostics:
			if entry is Dictionary:
				diagnostics.append(entry.duplicate(true))


func add_diagnostic(level: String, code: String, message: String, context: Dictionary = {}) -> void:
	diagnostics.append({
		"level": level,
		"code": code,
		"message": message,
		"context": context.duplicate(true),
	})


func to_dictionary() -> Dictionary:
	return {
		"accepted": accepted,
		"state": state.to_dictionary() if state != null and state.has_method("to_dictionary") else {},
		"command": command.to_dictionary() if command != null and command.has_method("to_dictionary") else {},
		"trace_summary": trace_summary.duplicate(true),
		"diagnostics": diagnostics.duplicate(true),
	}
