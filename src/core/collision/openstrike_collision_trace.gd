extends RefCounted

class_name OpenStrikeCollisionTrace

const STATUS_CLEAR := "clear"
const STATUS_HIT := "hit"
const STATUS_UNSUPPORTED := "unsupported"

var supported := true
var status := STATUS_CLEAR
var source := ""
var confidence := ""
var goldsrc_parity := false
var start_position := Vector3.ZERO
var end_position := Vector3.ZERO
var hit_position := Vector3.ZERO
var normal := Vector3.ZERO
var fraction := 1.0
var start_solid := false
var all_solid := false
var contents := ""
var model_index := -1
var collider_class := ""
var collider_name := ""
var metadata := {}


func setup(start: Vector3, end: Vector3, trace_source: String, trace_confidence: String, parity: bool) -> void:
	supported = true
	status = STATUS_CLEAR
	source = trace_source
	confidence = trace_confidence
	goldsrc_parity = parity
	start_position = start
	end_position = end
	hit_position = end
	normal = Vector3.ZERO
	fraction = 1.0
	start_solid = false
	all_solid = false
	contents = ""
	model_index = -1
	collider_class = ""
	collider_name = ""
	metadata = {}


func mark_unsupported(reason: String, capability: String = "") -> void:
	supported = false
	status = STATUS_UNSUPPORTED
	hit_position = end_position
	normal = Vector3.ZERO
	fraction = 1.0
	start_solid = false
	all_solid = false
	contents = ""
	model_index = -1
	metadata["reason"] = reason
	if capability != "":
		metadata["capability"] = capability


func mark_hit(ray_result: Dictionary) -> void:
	supported = true
	status = STATUS_HIT
	hit_position = ray_result.get("position", end_position)
	normal = ray_result.get("normal", Vector3.ZERO)
	fraction = _calculate_fraction(start_position, end_position, hit_position)
	start_solid = false
	all_solid = false
	var collider = ray_result.get("collider", null)
	collider_class = collider.get_class() if collider != null else ""
	collider_name = str(collider.name) if collider is Node else ""


func to_dictionary() -> Dictionary:
	return {
		"supported": supported,
		"status": status,
		"source": source,
		"confidence": confidence,
		"goldsrc_parity": goldsrc_parity,
		"start": _vector_to_array(start_position),
		"end": _vector_to_array(end_position),
		"hit_position": _vector_to_array(hit_position),
		"normal": _vector_to_array(normal),
		"fraction": fraction,
		"hit": status == STATUS_HIT,
		"start_solid": start_solid,
		"all_solid": all_solid,
		"contents": contents,
		"model_index": model_index,
		"collider_class": collider_class,
		"collider_name": collider_name,
		"metadata": metadata.duplicate(true),
	}


func _calculate_fraction(start: Vector3, end: Vector3, point: Vector3) -> float:
	var total := start.distance_to(end)
	if total <= 0.000001:
		return 0.0
	return clampf(start.distance_to(point) / total, 0.0, 1.0)


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
