extends RefCounted

class_name OpenStrikeBspMapResource

const CollisionLumpsRef = preload("res://src/core/bsp/bsp_collision_lumps.gd")
const LumpTableRef = preload("res://src/core/bsp/bsp_lump_table.gd")

var version := 0
var lump_table = null
var planes: Array[Dictionary] = []
var clipnodes: Array[Dictionary] = []
var models: Array[Dictionary] = []
var diagnostics: Array = []


func load_from_bytes(bytes: PackedByteArray) -> bool:
	version = 0
	lump_table = null
	planes.clear()
	clipnodes.clear()
	models.clear()
	diagnostics.clear()

	var table = LumpTableRef.new()
	if not table.parse(bytes, diagnostics):
		lump_table = table
		version = table.version
		return false

	var collision_lumps = CollisionLumpsRef.new()
	var parsed_collision := collision_lumps.parse(bytes, table, diagnostics)

	lump_table = table
	version = table.version
	planes = collision_lumps.planes.duplicate(true)
	clipnodes = collision_lumps.clipnodes.duplicate(true)
	models = collision_lumps.models.duplicate(true)
	return parsed_collision and not has_errors()


func has_errors() -> bool:
	for diagnostic in diagnostics:
		if diagnostic != null and diagnostic.has_method("is_error") and bool(diagnostic.call("is_error")):
			return true
	return false


func diagnostics_to_dictionaries() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for diagnostic in diagnostics:
		if diagnostic != null and diagnostic.has_method("to_dictionary"):
			output.append(diagnostic.call("to_dictionary"))
	return output


func model_headnode(model_index: int, hull_index: int) -> int:
	if model_index < 0 or model_index >= models.size():
		return -1
	if hull_index < 0 or hull_index >= 4:
		return -1
	var headnodes: Array = models[model_index].get("headnodes", [])
	if hull_index >= headnodes.size():
		return -1
	return int(headnodes[hull_index])


func to_report() -> Dictionary:
	return {
		"version": version,
		"planes": planes.size(),
		"clipnodes": clipnodes.size(),
		"models": models.size(),
		"has_errors": has_errors(),
		"diagnostics": diagnostics_to_dictionaries(),
		"lump_table": lump_table.to_dictionary() if lump_table != null and lump_table.has_method("to_dictionary") else {},
	}
