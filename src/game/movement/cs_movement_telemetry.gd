extends RefCounted

class_name CSMovementTelemetry

var frames: Array[Dictionary] = []


func record(delta: float, state, input, settings) -> void:
	frames.append({
		"index": frames.size(),
		"delta": delta,
		"state": state.snapshot(),
		"input": input.to_dictionary(),
		"settings": settings.to_dictionary(),
	})


func clear() -> void:
	frames.clear()


func last_frame() -> Dictionary:
	if frames.is_empty():
		return {}
	return frames[frames.size() - 1]


func max_horizontal_speed() -> float:
	var result := 0.0
	for frame in frames:
		result = max(result, float(frame["state"]["horizontal_speed"]))
	return result
