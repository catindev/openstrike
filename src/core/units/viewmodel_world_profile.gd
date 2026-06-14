extends RefCounted

class_name OpenStrikeViewmodelWorldProfile

const DEFAULT_PROFILE_PATH := "res://data/config/viewmodel_world_profile.json"
const KEEP_HEIGHT_NAME := "KEEP_HEIGHT"
const KEEP_WIDTH_NAME := "KEEP_WIDTH"

var source_path: String = ""
var metadata: Dictionary = {}
var diagnostics: Array[Dictionary] = []

var goldsrc_unit_scale: float = 0.025
var world_fov_horizontal_ref: float = 90.0
var viewmodel_fov_horizontal_ref: float = 90.0
var reference_aspect: float = 4.0 / 3.0
var view_offset_stand: float = 28.0
var view_offset_duck: float = 12.0
var camera_keep_aspect: String = KEEP_HEIGHT_NAME


func load_from_file(path: String = DEFAULT_PROFILE_PATH) -> void:
	_reset()
	source_path = path

	if not FileAccess.file_exists(path):
		_add_diagnostic("error", "viewmodel_world_profile_missing", "Viewmodel/world profile file is missing.", {"path": path})
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_add_diagnostic("error", "viewmodel_world_profile_unreadable", "Viewmodel/world profile file cannot be opened.", {"path": path, "error": FileAccess.get_open_error()})
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_add_diagnostic("error", "viewmodel_world_profile_invalid_json", "Viewmodel/world profile must be a JSON object.", {"path": path})
		return

	load_from_dictionary(parsed, path)


func load_from_dictionary(data: Dictionary, source: String = "") -> void:
	_reset()
	source_path = source

	var raw_metadata = data.get("metadata", {})
	if raw_metadata is Dictionary:
		metadata = raw_metadata.duplicate(true)
	else:
		_add_diagnostic("warning", "viewmodel_world_profile_metadata_invalid", "Profile metadata must be a dictionary.", {"source_path": source_path})

	goldsrc_unit_scale = _read_float(data, "goldsrc_unit_scale", goldsrc_unit_scale)
	world_fov_horizontal_ref = _read_float(data, "world_fov_horizontal_ref", world_fov_horizontal_ref)
	viewmodel_fov_horizontal_ref = _read_float(data, "viewmodel_fov_horizontal_ref", viewmodel_fov_horizontal_ref)
	reference_aspect = _read_float(data, "reference_aspect", reference_aspect)
	view_offset_stand = _read_float(data, "view_offset_stand", view_offset_stand)
	view_offset_duck = _read_float(data, "view_offset_duck", view_offset_duck)
	camera_keep_aspect = str(data.get("camera_keep_aspect", "")).strip_edges()

	_validate()


func is_valid() -> bool:
	for diagnostic in diagnostics:
		if diagnostic is Dictionary and str(diagnostic.get("level", "")) == "error":
			return false
	return true


func goldsrc_to_godot(value: Vector3) -> Vector3:
	return Vector3(-value.x, value.z, value.y) * goldsrc_unit_scale


func mapping_determinant() -> float:
	var basis_x := Vector3(-1.0, 0.0, 0.0)
	var basis_y := Vector3(0.0, 0.0, 1.0)
	var basis_z := Vector3(0.0, 1.0, 0.0)
	return basis_x.dot(basis_y.cross(basis_z))


func scaled_units(units: float) -> float:
	return units * goldsrc_unit_scale


func world_vertical_fov() -> float:
	return derive_vertical_fov(world_fov_horizontal_ref, reference_aspect)


func viewmodel_vertical_fov() -> float:
	return derive_vertical_fov(viewmodel_fov_horizontal_ref, reference_aspect)


func derive_vertical_fov(horizontal_fov_degrees: float, aspect: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(horizontal_fov_degrees) * 0.5) / aspect))


func derive_horizontal_fov(vertical_fov_degrees: float, aspect: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(vertical_fov_degrees) * 0.5) * aspect))


func camera_keep_aspect_value() -> int:
	if camera_keep_aspect == KEEP_WIDTH_NAME:
		return Camera3D.KEEP_WIDTH
	return Camera3D.KEEP_HEIGHT


func apply_to_camera(camera: Camera3D, use_viewmodel_fov: bool = false) -> void:
	camera.keep_aspect = camera_keep_aspect_value()
	camera.fov = viewmodel_vertical_fov() if use_viewmodel_fov else world_vertical_fov()


func to_dictionary() -> Dictionary:
	return {
		"source_path": source_path,
		"metadata": metadata,
		"valid": is_valid(),
		"goldsrc_unit_scale": goldsrc_unit_scale,
		"world_fov_horizontal_ref": world_fov_horizontal_ref,
		"viewmodel_fov_horizontal_ref": viewmodel_fov_horizontal_ref,
		"reference_aspect": reference_aspect,
		"view_offset_stand": view_offset_stand,
		"view_offset_duck": view_offset_duck,
		"camera_keep_aspect": camera_keep_aspect,
		"world_vertical_fov": world_vertical_fov(),
		"viewmodel_vertical_fov": viewmodel_vertical_fov(),
		"diagnostics": diagnostics.duplicate(true),
	}


func _reset() -> void:
	source_path = ""
	metadata.clear()
	diagnostics.clear()
	goldsrc_unit_scale = 0.025
	world_fov_horizontal_ref = 90.0
	viewmodel_fov_horizontal_ref = 90.0
	reference_aspect = 4.0 / 3.0
	view_offset_stand = 28.0
	view_offset_duck = 12.0
	camera_keep_aspect = KEEP_HEIGHT_NAME


func _read_float(data: Dictionary, key: String, fallback: float) -> float:
	if not data.has(key):
		_add_diagnostic("error", "viewmodel_world_profile_field_missing", "Profile source field is missing.", {"field": key, "source_path": source_path})
		return fallback

	var value = data[key]
	if value is int or value is float:
		return float(value)
	var text := str(value)
	if text.is_valid_float():
		return float(text.to_float())

	_add_diagnostic("error", "viewmodel_world_profile_field_invalid", "Profile source field must be numeric.", {"field": key, "value": value, "source_path": source_path})
	return fallback


func _validate() -> void:
	if goldsrc_unit_scale <= 0.0:
		_add_diagnostic("error", "viewmodel_world_profile_scale_invalid", "GoldSrc unit scale must be positive.", {"goldsrc_unit_scale": goldsrc_unit_scale})
	if world_fov_horizontal_ref <= 0.0 or world_fov_horizontal_ref >= 180.0:
		_add_diagnostic("error", "viewmodel_world_profile_world_fov_invalid", "World horizontal FOV reference must be in (0, 180).", {"world_fov_horizontal_ref": world_fov_horizontal_ref})
	if viewmodel_fov_horizontal_ref <= 0.0 or viewmodel_fov_horizontal_ref >= 180.0:
		_add_diagnostic("error", "viewmodel_world_profile_viewmodel_fov_invalid", "Viewmodel horizontal FOV reference must be in (0, 180).", {"viewmodel_fov_horizontal_ref": viewmodel_fov_horizontal_ref})
	if reference_aspect <= 0.0:
		_add_diagnostic("error", "viewmodel_world_profile_aspect_invalid", "Reference aspect must be positive.", {"reference_aspect": reference_aspect})
	if camera_keep_aspect != KEEP_HEIGHT_NAME:
		_add_diagnostic("error", "viewmodel_world_profile_keep_aspect_invalid", "CS16 parity profile requires KEEP_HEIGHT.", {"camera_keep_aspect": camera_keep_aspect})


func _add_diagnostic(level: String, code: String, message: String, context: Dictionary = {}) -> void:
	diagnostics.append({
		"level": level,
		"code": code,
		"message": message,
		"context": context,
	})
