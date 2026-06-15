extends RefCounted

class_name OpenStrikeBspCollisionLumps

const BinaryReaderRef = preload("res://src/core/bsp/bsp_binary_reader.gd")
const DiagnosticRef = preload("res://src/core/bsp/bsp_reader_diagnostic.gd")
const LumpTableRef = preload("res://src/core/bsp/bsp_lump_table.gd")

const PLANE_RECORD_SIZE := 20
const CLIPNODE_RECORD_SIZE := 8
const GOLDSRC_MODEL_RECORD_SIZE := 64
const SOURCE_MODEL_RECORD_SIZE := 48
const MAX_MAP_CLIPNODES := 32767

const CONTENTS_EMPTY := -1
const CONTENTS_SOLID := -2
const CONTENTS_WATER := -3
const CONTENTS_SLIME := -4
const CONTENTS_LAVA := -5
const CONTENTS_SKY := -6
const CONTENTS_ORIGIN := -7
const CONTENTS_CLIP := -8

var planes: Array[Dictionary] = []
var clipnodes: Array[Dictionary] = []
var models: Array[Dictionary] = []


func parse(bytes: PackedByteArray, lump_table, diagnostics: Array) -> bool:
	planes.clear()
	clipnodes.clear()
	models.clear()

	var ok := true
	var reader = BinaryReaderRef.new()
	reader.setup(bytes)

	ok = _parse_planes(reader, lump_table.lump(LumpTableRef.LUMP_PLANES), diagnostics) and ok
	ok = _parse_clipnodes(reader, lump_table.lump(LumpTableRef.LUMP_CLIPNODES), diagnostics) and ok
	ok = _parse_models(reader, lump_table.lump(LumpTableRef.LUMP_MODELS), diagnostics) and ok
	return ok


func _parse_planes(reader, lump: Dictionary, diagnostics: Array) -> bool:
	if not _lump_available(lump):
		return true
	var file_length := int(lump.get("filelen", 0))
	if file_length % PLANE_RECORD_SIZE != 0:
		_add_diagnostic(
			diagnostics,
			DiagnosticRef.SEVERITY_ERROR,
			"bsp_plane_lump_bad_record_size",
			"PLANES",
			"filelen",
			"Plane lump length must be divisible by the BSP30 dplane_t record size.",
			"divisible by %d" % PLANE_RECORD_SIZE,
			file_length
		)
		return false

	var file_offset := int(lump.get("fileofs", 0))
	var count := int(file_length / PLANE_RECORD_SIZE)
	for index in range(count):
		var offset := file_offset + index * PLANE_RECORD_SIZE
		planes.append({
			"normal": Vector3(
				reader.read_f32(offset),
				reader.read_f32(offset + 4),
				reader.read_f32(offset + 8)
			),
			"dist": reader.read_f32(offset + 12),
			"type": reader.read_i32(offset + 16),
		})
	return true


func _parse_clipnodes(reader, lump: Dictionary, diagnostics: Array) -> bool:
	if not _lump_available(lump):
		return true
	var file_length := int(lump.get("filelen", 0))
	if file_length % CLIPNODE_RECORD_SIZE != 0:
		_add_diagnostic(
			diagnostics,
			DiagnosticRef.SEVERITY_ERROR,
			"bsp_clipnode_lump_bad_record_size",
			"CLIPNODES",
			"filelen",
			"Clipnode lump length must be divisible by the BSP30 dclipnode_t record size.",
			"divisible by %d" % CLIPNODE_RECORD_SIZE,
			file_length
		)
		return false

	var count := int(file_length / CLIPNODE_RECORD_SIZE)
	if count > MAX_MAP_CLIPNODES:
		_add_diagnostic(
			diagnostics,
			DiagnosticRef.SEVERITY_ERROR,
			"bsp_clipnode_count_exceeds_bsp30_limit",
			"CLIPNODES",
			"count",
			"Clipnode count exceeds the BSP30 16-bit index limit.",
			MAX_MAP_CLIPNODES,
			count
		)
		return false

	var file_offset := int(lump.get("fileofs", 0))
	for index in range(count):
		var offset := file_offset + index * CLIPNODE_RECORD_SIZE
		clipnodes.append({
			"planenum": reader.read_i32(offset),
			"children": [
				reader.read_i16(offset + 4),
				reader.read_i16(offset + 6),
			],
		})
	return true


func _parse_models(reader, lump: Dictionary, diagnostics: Array) -> bool:
	if not _lump_available(lump):
		return true
	var file_length := int(lump.get("filelen", 0))
	if file_length == SOURCE_MODEL_RECORD_SIZE or file_length % GOLDSRC_MODEL_RECORD_SIZE != 0:
		_add_diagnostic(
			diagnostics,
			DiagnosticRef.SEVERITY_ERROR,
			"bsp_model_lump_not_goldsrc_64_bytes",
			"MODELS",
			"filelen",
			"GoldSrc BSP30 dmodel_t records are 64 bytes with headnode[4]; Source-style 48-byte records are rejected.",
			"divisible by %d" % GOLDSRC_MODEL_RECORD_SIZE,
			file_length
		)
		return false

	var file_offset := int(lump.get("fileofs", 0))
	var count := int(file_length / GOLDSRC_MODEL_RECORD_SIZE)
	for index in range(count):
		var offset := file_offset + index * GOLDSRC_MODEL_RECORD_SIZE
		models.append({
			"mins": Vector3(
				reader.read_f32(offset),
				reader.read_f32(offset + 4),
				reader.read_f32(offset + 8)
			),
			"maxs": Vector3(
				reader.read_f32(offset + 12),
				reader.read_f32(offset + 16),
				reader.read_f32(offset + 20)
			),
			"origin": Vector3(
				reader.read_f32(offset + 24),
				reader.read_f32(offset + 28),
				reader.read_f32(offset + 32)
			),
			"headnodes": [
				reader.read_i32(offset + 36),
				reader.read_i32(offset + 40),
				reader.read_i32(offset + 44),
				reader.read_i32(offset + 48),
			],
			"visleafs": reader.read_i32(offset + 52),
			"firstface": reader.read_i32(offset + 56),
			"numfaces": reader.read_i32(offset + 60),
		})
	return true


func _lump_available(lump: Dictionary) -> bool:
	return bool(lump.get("valid", false)) and int(lump.get("filelen", 0)) > 0


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
