extends RefCounted

class_name OpenStrikePlayerSlot

const TEAM_UNASSIGNED := "unassigned"
const TEAM_TERRORIST := "terrorist"
const TEAM_COUNTER_TERRORIST := "counter_terrorist"
const TEAM_SPECTATOR := "spectator"

var player_id := 0
var display_name := ""
var team := TEAM_UNASSIGNED
var connected := true
var alive := false
var spawn_classname := ""
var spawn_position := Vector3.ZERO
var spawn_yaw := 0.0
var last_command_tick := -1


func configure(id: int, player_name: String, player_team: String) -> void:
	player_id = id
	display_name = player_name
	team = player_team
	connected = true
	alive = false
	spawn_classname = ""
	spawn_position = Vector3.ZERO
	spawn_yaw = 0.0
	last_command_tick = -1


func assign_spawn(classname: String, position: Vector3, yaw: float) -> void:
	spawn_classname = classname
	spawn_position = position
	spawn_yaw = yaw
	alive = team != TEAM_SPECTATOR and team != TEAM_UNASSIGNED


func mark_command_applied(command_tick: int) -> void:
	last_command_tick = command_tick


func to_dictionary() -> Dictionary:
	return {
		"player_id": player_id,
		"display_name": display_name,
		"team": team,
		"connected": connected,
		"alive": alive,
		"spawn_classname": spawn_classname,
		"spawn_position": _vector_to_array(spawn_position),
		"spawn_yaw": spawn_yaw,
		"last_command_tick": last_command_tick,
	}


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
