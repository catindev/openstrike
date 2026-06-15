extends RefCounted

class_name OpenStrikePlayerState

const FLAG_NONE := 0

var origin := Vector3.ZERO
var velocity := Vector3.ZERO
var view_yaw := 0.0
var view_pitch := 0.0
var ducked := false
var on_ground := true
var flags := FLAG_NONE
var last_trace_summary := {}


func configure(
	state_origin: Vector3,
	state_velocity: Vector3,
	yaw: float = 0.0,
	pitch: float = 0.0,
	is_ducked: bool = false,
	is_on_ground: bool = true,
	state_flags: int = FLAG_NONE,
	trace_summary: Dictionary = {}
) -> void:
	origin = state_origin
	velocity = state_velocity
	view_yaw = yaw
	view_pitch = pitch
	ducked = is_ducked
	on_ground = is_on_ground
	flags = state_flags
	last_trace_summary = trace_summary.duplicate(true)


func configure_from_dictionary(data: Dictionary) -> void:
	origin = _vector_from_value(data.get("origin", Vector3.ZERO))
	velocity = _vector_from_value(data.get("velocity", Vector3.ZERO))
	view_yaw = float(data.get("view_yaw", 0.0))
	view_pitch = float(data.get("view_pitch", 0.0))
	ducked = bool(data.get("ducked", false))
	on_ground = bool(data.get("on_ground", true))
	flags = int(data.get("flags", FLAG_NONE))
	var trace_summary = data.get("last_trace_summary", {})
	last_trace_summary = trace_summary.duplicate(true) if trace_summary is Dictionary else {}


func to_dictionary() -> Dictionary:
	return {
		"origin": _vector_to_array(origin),
		"velocity": _vector_to_array(velocity),
		"view_yaw": view_yaw,
		"view_pitch": view_pitch,
		"ducked": ducked,
		"on_ground": on_ground,
		"flags": flags,
		"last_trace_summary": last_trace_summary.duplicate(true),
	}


func _vector_from_value(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
