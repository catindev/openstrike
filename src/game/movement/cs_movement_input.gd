extends RefCounted

class_name CSMovementInput

const BUTTON_RELEASED := 0.0
const BUTTON_JUST_PRESSED := 0.5
const BUTTON_HELD := 1.0

var forward_move := 0.0
var side_move := 0.0
var jump := false
var duck := false


func _init(forward: float = 0.0, side: float = 0.0, wants_jump: bool = false, wants_duck: bool = false) -> void:
	forward_move = forward
	side_move = side
	jump = wants_jump
	duck = wants_duck


static func button_axis(positive_state: float, negative_state: float) -> float:
	return (
		float(clamp(positive_state, BUTTON_RELEASED, BUTTON_HELD))
		- float(clamp(negative_state, BUTTON_RELEASED, BUTTON_HELD))
	)


func to_dictionary() -> Dictionary:
	return {
		"forward_move": forward_move,
		"side_move": side_move,
		"jump": jump,
		"duck": duck,
	}
