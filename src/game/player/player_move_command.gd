extends RefCounted

class_name OpenStrikePlayerMoveCommand

var forward_move := 0.0
var side_move := 0.0
var wants_jump := false
var wants_duck := false
var view_yaw := 0.0
var view_pitch := 0.0
var frametime := 0.01


func configure(
	forward: float,
	side: float,
	jump: bool = false,
	duck: bool = false,
	yaw: float = 0.0,
	pitch: float = 0.0,
	command_frametime: float = 0.01
) -> void:
	forward_move = forward
	side_move = side
	wants_jump = jump
	wants_duck = duck
	view_yaw = yaw
	view_pitch = pitch
	frametime = command_frametime


func configure_from_dictionary(data: Dictionary) -> void:
	forward_move = float(data.get("forward_move", 0.0))
	side_move = float(data.get("side_move", 0.0))
	wants_jump = bool(data.get("wants_jump", false))
	wants_duck = bool(data.get("wants_duck", false))
	view_yaw = float(data.get("view_yaw", 0.0))
	view_pitch = float(data.get("view_pitch", 0.0))
	frametime = float(data.get("frametime", 0.01))


func to_dictionary() -> Dictionary:
	return {
		"forward_move": forward_move,
		"side_move": side_move,
		"wants_jump": wants_jump,
		"wants_duck": wants_duck,
		"view_yaw": view_yaw,
		"view_pitch": view_pitch,
		"frametime": frametime,
	}
