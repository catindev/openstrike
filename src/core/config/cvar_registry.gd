extends RefCounted

class_name CvarRegistry

var values: Dictionary = {}
var defaults: Dictionary = {}
var definitions: Dictionary = {}
var diagnostics: Array[Dictionary] = []


func define(name: String, default_value, flags: Array[String] = [], description: String = "") -> bool:
	var cvar_name := _normalize_name(name)
	if cvar_name == "":
		_add_diagnostic("error", "cvar_invalid_name", "Cvar name is empty.", {"name": name})
		return false

	defaults[cvar_name] = default_value
	values[cvar_name] = default_value
	definitions[cvar_name] = {
		"name": cvar_name,
		"default": default_value,
		"flags": flags.duplicate(),
		"description": description,
	}
	return true


func has_cvar(name: String) -> bool:
	return values.has(_normalize_name(name))


func set_value(name: String, value) -> bool:
	var cvar_name := _normalize_name(name)
	if cvar_name == "":
		_add_diagnostic("error", "cvar_invalid_name", "Cvar name is empty.", {"name": name})
		return false

	if not values.has(cvar_name):
		_add_diagnostic("warning", "cvar_implicit_definition", "Setting an undefined cvar creates a runtime definition.", {"name": cvar_name})
		defaults[cvar_name] = value
		definitions[cvar_name] = {
			"name": cvar_name,
			"default": value,
			"flags": [],
			"description": "",
		}

	values[cvar_name] = value
	return true


func get_value(name: String, fallback = null):
	return values.get(_normalize_name(name), fallback)


func get_int(name: String, fallback: int = 0) -> int:
	var value = get_value(name, fallback)
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is bool:
		return 1 if value else 0
	return int(str(value).to_int()) if str(value).is_valid_int() else fallback


func get_float(name: String, fallback: float = 0.0) -> float:
	var value = get_value(name, fallback)
	if value is int or value is float:
		return float(value)
	if value is bool:
		return 1.0 if value else 0.0
	return float(str(value).to_float()) if str(value).is_valid_float() else fallback


func get_string(name: String, fallback: String = "") -> String:
	var value = get_value(name, fallback)
	return str(value)


func load_cfg_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		_add_diagnostic("error", "cfg_missing", "Config file is missing.", {"path": path})
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_add_diagnostic("error", "cfg_unreadable", "Config file cannot be opened.", {"path": path, "error": FileAccess.get_open_error()})
		return false

	load_cfg_text(file.get_as_text(), path)
	return true


func load_cfg_text(text: String, source: String = "inline") -> void:
	_parse_cfg_text(text, source, true)


func apply_cfg_text(text: String, source: String = "inline") -> void:
	_parse_cfg_text(text, source, false)


func _parse_cfg_text(text: String, source: String, define_missing: bool) -> void:
	var line_number := 0
	for raw_line in text.split("\n"):
		line_number += 1
		var line := _strip_comment(String(raw_line)).strip_edges()
		if line == "":
			continue

		var parts := _split_command(line)
		if parts.is_empty():
			continue

		var name := String(parts[0])
		if parts.size() == 1:
			_add_diagnostic("warning", "cfg_value_missing", "Cvar line has no value.", {"source": source, "line": line_number, "name": name})
			continue

		var parsed_value = _parse_value(String(parts[1]))
		if define_missing:
			define(name, parsed_value)
		else:
			set_value(name, parsed_value)


func serialize_cfg() -> String:
	var names := values.keys()
	names.sort()

	var lines: Array[String] = []
	for name in names:
		lines.append("%s %s" % [name, _format_value(values[name])])
	return "\n".join(lines) + "\n"


func to_dictionary() -> Dictionary:
	return {
		"values": values.duplicate(true),
		"defaults": defaults.duplicate(true),
		"definitions": definitions.duplicate(true),
		"diagnostics": diagnostics.duplicate(true),
	}


func _split_command(line: String) -> PackedStringArray:
	var first_space := line.find(" ")
	if first_space == -1:
		return PackedStringArray([line])
	return PackedStringArray([
		line.substr(0, first_space).strip_edges(),
		line.substr(first_space + 1).strip_edges(),
	])


func _parse_value(value_text: String):
	var value := _unquote(value_text.strip_edges())
	var lower := value.to_lower()
	if lower == "true":
		return true
	if lower == "false":
		return false
	if value.is_valid_int():
		return value.to_int()
	if value.is_valid_float():
		return value.to_float()
	return value


func _format_value(value) -> String:
	if value is String:
		var text := str(value)
		if text.find(" ") != -1 or text == "":
			return "\"%s\"" % text.replace("\"", "\\\"")
	return str(value)


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


func _unquote(value: String) -> String:
	if value.length() >= 2 and value.begins_with("\"") and value.ends_with("\""):
		return value.substr(1, value.length() - 2).replace("\\\"", "\"")
	return value


func _normalize_name(name: String) -> String:
	return name.strip_edges().to_lower()


func _add_diagnostic(level: String, code: String, message: String, context: Dictionary = {}) -> void:
	diagnostics.append({
		"level": level,
		"code": code,
		"message": message,
		"context": context,
	})
