extends RefCounted

class_name OpenStrikeBspLumpTable

const BinaryReaderRef = preload("res://src/core/bsp/bsp_binary_reader.gd")
const DiagnosticRef = preload("res://src/core/bsp/bsp_reader_diagnostic.gd")

const BSP_VERSION := 30
const HEADER_LUMPS := 15
const HEADER_SIZE := 4 + HEADER_LUMPS * 8

const LUMP_ENTITIES := 0
const LUMP_PLANES := 1
const LUMP_TEXTURES := 2
const LUMP_VERTICES := 3
const LUMP_VISIBILITY := 4
const LUMP_NODES := 5
const LUMP_TEXINFO := 6
const LUMP_FACES := 7
const LUMP_LIGHTING := 8
const LUMP_CLIPNODES := 9
const LUMP_LEAVES := 10
const LUMP_MARKSURFACES := 11
const LUMP_EDGES := 12
const LUMP_SURFEDGES := 13
const LUMP_MODELS := 14

const LUMP_NAMES := [
	"ENTITIES",
	"PLANES",
	"TEXTURES",
	"VERTICES",
	"VISIBILITY",
	"NODES",
	"TEXINFO",
	"FACES",
	"LIGHTING",
	"CLIPNODES",
	"LEAVES",
	"MARKSURFACES",
	"EDGES",
	"SURFEDGES",
	"MODELS",
]

var version := 0
var lumps: Array[Dictionary] = []


func parse(bytes: PackedByteArray, diagnostics: Array) -> bool:
	version = 0
	lumps.clear()

	if bytes.size() < HEADER_SIZE:
		_add_diagnostic(
			diagnostics,
			DiagnosticRef.SEVERITY_ERROR,
			"bsp_header_too_short",
			"HEADER",
			"size",
			"BSP30 header must contain a version and 15 lump entries.",
			HEADER_SIZE,
			bytes.size()
		)
		return false

	var reader = BinaryReaderRef.new()
	reader.setup(bytes)
	version = reader.read_i32(0)
	if version != BSP_VERSION:
		_add_diagnostic(
			diagnostics,
			DiagnosticRef.SEVERITY_ERROR,
			"unsupported_bsp_version",
			"HEADER",
			"version",
			"OpenStrike BSP collision reader currently accepts BSP version 30 only.",
			BSP_VERSION,
			version
		)
		return false

	for index in range(HEADER_LUMPS):
		var lump_offset := 4 + index * 8
		var file_offset := reader.read_i32(lump_offset)
		var file_length := reader.read_i32(lump_offset + 4)
		var valid := true
		if file_offset < 0 or file_length < 0:
			valid = false
			_add_diagnostic(
				diagnostics,
				DiagnosticRef.SEVERITY_WARNING,
				"bsp_lump_negative_range",
				lump_name(index),
				"fileofs/filelen",
				"Negative lump offsets or lengths are treated as absent.",
				"non-negative offset and length",
				{"fileofs": file_offset, "filelen": file_length}
			)
		elif file_length > 0 and file_offset + file_length > bytes.size():
			valid = false
			_add_diagnostic(
				diagnostics,
				DiagnosticRef.SEVERITY_WARNING,
				"bsp_lump_out_of_bounds",
				lump_name(index),
				"fileofs/filelen",
				"Out-of-bounds lumps are treated as absent.",
				{"max_end": bytes.size()},
				{"fileofs": file_offset, "filelen": file_length, "end": file_offset + file_length}
			)

		lumps.append({
			"index": index,
			"name": lump_name(index),
			"fileofs": file_offset,
			"filelen": file_length,
			"valid": valid,
		})

	return true


func lump(index: int) -> Dictionary:
	if index < 0 or index >= lumps.size():
		return {}
	return lumps[index]


func lump_name(index: int) -> String:
	if index < 0 or index >= LUMP_NAMES.size():
		return "LUMP_%d" % index
	return str(LUMP_NAMES[index])


func to_dictionary() -> Dictionary:
	var output: Array[Dictionary] = []
	for entry in lumps:
		output.append(entry.duplicate(true))
	return {
		"version": version,
		"lumps": output,
	}


func _add_diagnostic(
	diagnostics: Array,
	severity: String,
	code: String,
	lump: String,
	field: String,
	message: String,
	expected = null,
	actual = null
) -> void:
	var diagnostic = DiagnosticRef.new()
	diagnostic.configure(severity, code, lump, field, message, expected, actual)
	diagnostics.append(diagnostic)
