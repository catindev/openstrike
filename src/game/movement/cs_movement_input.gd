extends RefCounted

class_name CSMovementInput

const BUTTON_RELEASED := 0.0
const BUTTON_JUST_PRESSED := 0.5
const BUTTON_HELD := 1.0

var forward_move := 0.0
var side_move := 0.0
var jump := false
var duck := false
var forward_axis := Vector3.BACK
var right_axis := Vector3.RIGHT


func _init(forward: float = 0.0, side: float = 0.0, wants_jump: bool = false, wants_duck: bool = false) -> void:
	forward_move = forward
	side_move = side
	jump = wants_jump
	duck = wants_duck


func configure_axes(forward: Vector3 = Vector3.BACK, right: Vector3 = Vector3.RIGHT) -> void:
	forward_axis = _horizontal_axis_or_default(forward, Vector3.BACK)
	right_axis = _horizontal_axis_or_default(right, Vector3.RIGHT)


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
		"forward_axis": _vector_to_array(forward_axis),
		"right_axis": _vector_to_array(right_axis),
	}


func _horizontal_axis_or_default(axis: Vector3, default_axis: Vector3) -> Vector3:
	var horizontal := Vector3(axis.x, 0.0, axis.z)
	if horizontal.length_squared() <= 0.0:
		return default_axis
	return horizontal.normalized()


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
