extends RefCounted

class_name OpenStrikeGameSnapshot

var tick := 0
var fixed_delta := 0.01
var round_state := {}
var players: Array[Dictionary] = []
var applied_commands: Array[Dictionary] = []


func to_dictionary() -> Dictionary:
	return {
		"tick": tick,
		"fixed_delta": fixed_delta,
		"round_state": round_state.duplicate(true),
		"players": players.duplicate(true),
		"applied_commands": applied_commands.duplicate(true),
	}
