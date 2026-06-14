extends RefCounted

class_name CSMovementState

var position := Vector3.ZERO
var velocity := Vector3.ZERO
var ground_height := 0.0
var on_ground := true
var ducked := false
var body_height := 72.0


func horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func horizontal_speed() -> float:
	return horizontal_velocity().length()


func snapshot() -> Dictionary:
	return {
		"position": position,
		"velocity": velocity,
		"ground_height": ground_height,
		"on_ground": on_ground,
		"ducked": ducked,
		"body_height": body_height,
		"horizontal_speed": horizontal_speed(),
	}
