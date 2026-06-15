extends RefCounted

class_name OpenStrikeUserCommand

var tick := 0
var player_id := 0
var forward_move := 0.0
var side_move := 0.0
var wants_jump := false
var wants_duck := false
var view_yaw := 0.0
var view_pitch := 0.0


func configure(
	command_tick: int,
	command_player_id: int,
	forward: float,
	side: float,
	jump: bool = false,
	duck: bool = false,
	yaw: float = 0.0,
	pitch: float = 0.0
) -> void:
	tick = command_tick
	player_id = command_player_id
	forward_move = forward
	side_move = side
	wants_jump = jump
	wants_duck = duck
	view_yaw = yaw
	view_pitch = pitch


func to_dictionary() -> Dictionary:
	return {
		"tick": tick,
		"player_id": player_id,
		"forward_move": forward_move,
		"side_move": side_move,
		"wants_jump": wants_jump,
		"wants_duck": wants_duck,
		"view_yaw": view_yaw,
		"view_pitch": view_pitch,
	}
