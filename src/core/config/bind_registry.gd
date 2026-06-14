extends RefCounted

class_name BindRegistry

var bindings: Dictionary = {}
var diagnostics: Array[Dictionary] = []


func bind_key(key: String, command: String) -> bool:
	var normalized_key := _normalize_key(key)
	var normalized_command := command.strip_edges()
	if normalized_key == "":
		_add_diagnostic("error", "bind_key_invalid", "Bind key is empty.", {"key": key})
		return false
	if normalized_command == "":
		_add_diagnostic("error", "bind_command_invalid", "Bind command is empty.", {"key": normalized_key})
		return false
	bindings[normalized_key] = normalized_command
	return true


func unbind_key(key: String) -> void:
	bindings.erase(_normalize_key(key))


func get_command(key: String, fallback: String = "") -> String:
	return str(bindings.get(_normalize_key(key), fallback))


func has_binding(key: String) -> bool:
	return bindings.has(_normalize_key(key))


func apply_bind_line(line: String, source: String = "inline", line_number: int = 0) -> bool:
	var clean_line := _strip_comment(line).strip_edges()
	if clean_line == "":
		return true

	var parts := _split_tokens(clean_line)
	if parts.is_empty():
		return true

	var command := String(parts[0]).to_lower()
	if command == "bind":
		if parts.size() < 3:
			_add_diagnostic("warning", "bind_line_incomplete", "Bind line requires a key and command.", {"source": source, "line": line_number, "text": line})
			return false
		return bind_key(String(parts[1]), String(parts[2]))
	if command == "unbind":
		if parts.size() < 2:
			_add_diagnostic("warning", "unbind_line_incomplete", "Unbind line requires a key.", {"source": source, "line": line_number, "text": line})
			return false
		unbind_key(String(parts[1]))
		return true

	_add_diagnostic("warning", "bind_line_ignored", "Line is not a bind command.", {"source": source, "line": line_number, "text": line})
	return false


func serialize_cfg() -> String:
	var keys := bindings.keys()
	keys.sort()

	var lines: Array[String] = []
	for key in keys:
		lines.append("bind %s %s" % [_quote(str(key)), _quote(str(bindings[key]))])
	return "\n".join(lines) + "\n"


func to_dictionary() -> Dictionary:
	return {
		"bindings": bindings.duplicate(true),
		"diagnostics": diagnostics.duplicate(true),
	}


func _split_tokens(line: String) -> PackedStringArray:
	var tokens := PackedStringArray()
	var current := ""
	var in_quote := false

	for index in range(line.length()):
		var character := line.substr(index, 1)
		if character == "\"":
			in_quote = not in_quote
			continue
		if character == " " and not in_quote:
			if current != "":
				tokens.append(current)
				current = ""
			continue
		current += character

	if current != "":
		tokens.append(current)
	return tokens


func _strip_comment(line: String) -> String:
	var in_quote := false
	var escaped := false

	for index in range(line.length()):
		var character := line.substr(index, 1)
		if escaped:
			escaped = false
			continue
		if character == "\\":
			escaped = true
			continue
		if character == "\"":
			in_quote = not in_quote
			continue
		if not in_quote and character == "/" and index + 1 < line.length() and line.substr(index + 1, 1) == "/":
			return line.substr(0, index)

	return line


func _quote(value: String) -> String:
	return "\"%s\"" % value.replace("\"", "\\\"")


func _normalize_key(key: String) -> String:
	return key.strip_edges().to_lower()


func _add_diagnostic(level: String, code: String, message: String, context: Dictionary = {}) -> void:
	diagnostics.append({
		"level": level,
		"code": code,
		"message": message,
		"context": context,
	})
