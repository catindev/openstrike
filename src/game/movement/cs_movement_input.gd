extends RefCounted

class_name CSMovementInput

var forward_move := 0.0
var side_move := 0.0
var jump := false
var duck := false


func _init(forward: float = 0.0, side: float = 0.0, wants_jump: bool = false, wants_duck: bool = false) -> void:
	forward_move = forward
	side_move = side
	jump = wants_jump
	duck = wants_duck


func to_dictionary() -> Dictionary:
	return {
		"forward_move": forward_move,
		"side_move": side_move,
		"jump": jump,
		"duck": duck,
	}
