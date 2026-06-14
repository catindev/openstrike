extends RefCounted

class_name AssetDiagnostics

static func info(code: String, message: String, context: Dictionary = {}) -> Dictionary:
	return _entry("info", code, message, context)


static func warning(code: String, message: String, context: Dictionary = {}) -> Dictionary:
	return _entry("warning", code, message, context)


static func error(code: String, message: String, context: Dictionary = {}) -> Dictionary:
	return _entry("error", code, message, context)


static func has_errors(entries: Array) -> bool:
	for entry in entries:
		if entry is Dictionary and entry.get("level", "") == "error":
			return true
	return false


static func _entry(level: String, code: String, message: String, context: Dictionary) -> Dictionary:
	return {
		"level": level,
		"code": code,
		"message": message,
		"context": context,
	}
