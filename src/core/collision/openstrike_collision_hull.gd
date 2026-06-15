extends RefCounted

class_name OpenStrikeCollisionHull

const KIND_POINT := "point"
const KIND_PLAYER_STANDING := "player_standing"
const KIND_PLAYER_DUCKING := "player_ducking"

var kind := KIND_POINT
var mins := Vector3.ZERO
var maxs := Vector3.ZERO


func configure(hull_kind: String, hull_mins: Vector3, hull_maxs: Vector3) -> void:
	kind = hull_kind
	mins = hull_mins
	maxs = hull_maxs


func to_dictionary() -> Dictionary:
	return {
		"kind": kind,
		"mins": _vector_to_array(mins),
		"maxs": _vector_to_array(maxs),
	}


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
