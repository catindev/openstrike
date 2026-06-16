extends RefCounted

class_name OpenStrikePlayerSlot

const PlayerStateRef = preload("res://src/game/player/player_state.gd")

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
var movement_state = null


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
	movement_state = PlayerStateRef.new()
	movement_state.configure(Vector3.ZERO, Vector3.ZERO)


func assign_spawn(classname: String, position: Vector3, yaw: float) -> void:
	spawn_classname = classname
	spawn_position = position
	spawn_yaw = yaw
	alive = team != TEAM_SPECTATOR and team != TEAM_UNASSIGNED
	_reset_movement_state_to_spawn()


func mark_command_applied(command_tick: int) -> void:
	last_command_tick = command_tick


func apply_movement_state(next_state) -> void:
	if next_state == null:
		return
	movement_state = next_state


func to_dictionary() -> Dictionary:
	var movement_report: Dictionary = movement_state.to_dictionary() if movement_state != null and movement_state.has_method("to_dictionary") else {}
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
		"origin": movement_report.get("origin", _vector_to_array(Vector3.ZERO)),
		"velocity": movement_report.get("velocity", _vector_to_array(Vector3.ZERO)),
		"view_yaw": float(movement_report.get("view_yaw", spawn_yaw)),
		"view_pitch": float(movement_report.get("view_pitch", 0.0)),
		"ducked": bool(movement_report.get("ducked", false)),
		"on_ground": bool(movement_report.get("on_ground", true)),
		"movement_state": movement_report,
	}


func _reset_movement_state_to_spawn() -> void:
	if movement_state == null:
		movement_state = PlayerStateRef.new()
	var trace_summary := {
		"mode": "spawn",
		"ground_height": spawn_position.y,
	}
	movement_state.configure(
		spawn_position,
		Vector3.ZERO,
		spawn_yaw,
		0.0,
		false,
		alive,
		PlayerStateRef.FLAG_NONE,
		trace_summary
	)


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
