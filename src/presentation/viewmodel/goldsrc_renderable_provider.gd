extends RefCounted

class_name OpenStrikeGoldSrcRenderableProvider

const OpenStrikeAssetDiagnosticsRef = preload("res://src/core/assets/asset_diagnostics.gd")

const PROVIDER_ID := "alanfischer/goldsrc-godot"
const PROVIDER_URL := "https://github.com/alanfischer/goldsrc-godot"
const GOLDSRC_MDL_CLASS := "GoldSrcMDL"
const GOLDSRC_SPR_CLASS := "GoldSrcSPR"

const CAP_SUPPORTED_BY_LOADER_API := "supported_by_loader_api"
const CAP_REQUIRES_OPENSTRIKE_MDL_READER := "requires_openstrike_mdl_reader"
const CAP_DEFERRED := "deferred"
const CAP_EXTENSION_MISSING := "extension_missing"


func inspect_capabilities() -> Dictionary:
	var extension_available := _has_class(GOLDSRC_MDL_CLASS) and _has_class(GOLDSRC_SPR_CLASS)
	var mdl = _instantiate_class(GOLDSRC_MDL_CLASS)
	var spr = _instantiate_class(GOLDSRC_SPR_CLASS)
	var report := {
		"provider": PROVIDER_ID,
		"source_url": PROVIDER_URL,
		"extension_available": extension_available,
		"classes": {
			GOLDSRC_MDL_CLASS: _has_class(GOLDSRC_MDL_CLASS),
			GOLDSRC_SPR_CLASS: _has_class(GOLDSRC_SPR_CLASS),
		},
		"mdl_api": _inspect_methods(mdl, [
			"load_mdl",
			"build_model",
			"get_sequence_count",
			"get_sequence_name",
			"get_sequence_fps",
			"get_sequence_num_frames",
			"get_bodypart_count",
			"get_bodypart_name",
			"get_bone_count",
			"get_skin_count",
			"get_skin_info",
			"set_scale_factor",
			"get_scale_factor",
		]),
		"spr_api": _inspect_methods(spr, [
			"load_spr",
			"get_frame_count",
			"get_frame_texture",
			"get_frame_origin",
			"get_type",
			"get_texture_format",
			"build_scene",
		]),
		"coverage_capability": {},
	}
	report["coverage_capability"] = _build_coverage_capability(report)
	_free_if_node(mdl)
	_free_if_node(spr)
	return report


func build_view_model(asset_result, profile, build_model: bool = true) -> Dictionary:
	var output := {
		"ok": false,
		"node": null,
		"metadata": {},
		"capabilities": inspect_capabilities(),
		"diagnostics": [],
	}

	if not bool(output["capabilities"].get("extension_available", false)):
		output["diagnostics"].append(OpenStrikeAssetDiagnosticsRef.error(
			"goldsrc_godot_extension_missing",
			(
				"The vendored goldsrc-godot GDExtension is not available; "
				+ "run scripts/bootstrap_gdextensions.sh and confirm a native "
				+ "library exists for this platform before real viewmodel rendering."
			),
			{"provider": PROVIDER_ID, "source_url": PROVIDER_URL}
		))
		return output

	if asset_result == null or not asset_result.is_resolved():
		output["diagnostics"].append(OpenStrikeAssetDiagnosticsRef.error(
			"goldsrc_renderable_asset_unresolved",
			"Renderable adapter requires a resolved asset provider result.",
			{"asset_id": str(asset_result.asset_id) if asset_result != null else ""}
		))
		return output

	if str(asset_result.asset_type) != "view_model":
		output["diagnostics"].append(OpenStrikeAssetDiagnosticsRef.error(
			"goldsrc_renderable_type_mismatch",
			"Renderable adapter currently supports view_model assets for PR-06.",
			{"asset_id": str(asset_result.asset_id), "type": str(asset_result.asset_type)}
		))
		return output

	var mdl = _instantiate_class(GOLDSRC_MDL_CLASS)
	if mdl == null:
		output["diagnostics"].append(OpenStrikeAssetDiagnosticsRef.error(
			"goldsrc_mdl_instantiate_failed",
			"GoldSrcMDL class exists but could not be instantiated.",
			{"asset_id": str(asset_result.asset_id)}
		))
		return output

	mdl.name = str(asset_result.asset_id).replace(".", "_")
	mdl.set("scale_factor", profile.goldsrc_unit_scale)
	var load_error = mdl.call("load_mdl", asset_result.resolved_path)
	if int(load_error) != OK:
		_free_if_node(mdl)
		output["diagnostics"].append(OpenStrikeAssetDiagnosticsRef.error(
			"goldsrc_mdl_load_failed",
			"goldsrc-godot failed to load the resolved MDL.",
			{"asset_id": str(asset_result.asset_id), "error": int(load_error)}
		))
		return output

	if build_model:
		mdl.call("build_model")

	output["ok"] = true
	output["node"] = mdl
	output["metadata"] = _inspect_mdl_metadata(mdl, str(asset_result.asset_id), asset_result.relative_path)
	return output


func _build_coverage_capability(report: Dictionary) -> Dictionary:
	var extension_available := bool(report.get("extension_available", false))
	var missing_or_supported := CAP_SUPPORTED_BY_LOADER_API if extension_available else CAP_EXTENSION_MISSING
	var mdl_api: Dictionary = report.get("mdl_api", {})
	var has_sequences := bool(mdl_api.get("get_sequence_count", false)) and bool(mdl_api.get("get_sequence_name", false))
	var has_sequence_timing := has_sequences and bool(mdl_api.get("get_sequence_fps", false)) and bool(mdl_api.get("get_sequence_num_frames", false))

	return {
		"viewmodel_scene": missing_or_supported if _all_true(mdl_api, ["load_mdl", "build_model", "set_scale_factor"]) else CAP_EXTENSION_MISSING,
		"sequence_names": CAP_SUPPORTED_BY_LOADER_API if extension_available and has_sequences else CAP_EXTENSION_MISSING,
		"sequence_timing": CAP_SUPPORTED_BY_LOADER_API if extension_available and has_sequence_timing else CAP_EXTENSION_MISSING,
		"bone_count": CAP_SUPPORTED_BY_LOADER_API if extension_available and bool(mdl_api.get("get_bone_count", false)) else CAP_EXTENSION_MISSING,
		"bodyparts": CAP_SUPPORTED_BY_LOADER_API if extension_available and bool(mdl_api.get("get_bodypart_count", false)) else CAP_EXTENSION_MISSING,
		"skins": CAP_SUPPORTED_BY_LOADER_API if extension_available and bool(mdl_api.get("get_skin_count", false)) else CAP_EXTENSION_MISSING,
		"attachments": CAP_REQUIRES_OPENSTRIKE_MDL_READER,
		"animation_events": CAP_REQUIRES_OPENSTRIKE_MDL_READER,
		"muzzle_socket_transform": CAP_REQUIRES_OPENSTRIKE_MDL_READER,
		"shell_socket_transform": CAP_REQUIRES_OPENSTRIKE_MDL_READER,
		"world_model_rendering": CAP_DEFERRED,
		"sprite_scene": CAP_SUPPORTED_BY_LOADER_API if extension_available and _all_true(report.get("spr_api", {}), ["load_spr", "build_scene"]) else CAP_EXTENSION_MISSING,
	}


func _inspect_mdl_metadata(mdl, asset_id: String, relative_path: String) -> Dictionary:
	var sequences: Array[Dictionary] = []
	var sequence_count := int(mdl.call("get_sequence_count"))
	for index in range(sequence_count):
		sequences.append({
			"index": index,
			"name": str(mdl.call("get_sequence_name", index)),
			"fps": float(mdl.call("get_sequence_fps", index)),
			"frames": int(mdl.call("get_sequence_num_frames", index)),
		})

	var bodyparts: Array[Dictionary] = []
	var bodypart_count := int(mdl.call("get_bodypart_count"))
	for index in range(bodypart_count):
		bodyparts.append({
			"index": index,
			"name": str(mdl.call("get_bodypart_name", index)),
		})

	return {
		"asset_id": asset_id,
		"relative_path": relative_path,
		"scale_factor": float(mdl.call("get_scale_factor")),
		"sequence_count": sequence_count,
		"sequences": sequences,
		"bone_count": int(mdl.call("get_bone_count")),
		"bodypart_count": bodypart_count,
		"bodyparts": bodyparts,
		"skin_count": int(mdl.call("get_skin_count")),
	}


func _inspect_methods(object, methods: Array[String]) -> Dictionary:
	var result := {}
	for method in methods:
		result[method] = object != null and object.has_method(method)
	return result


func _has_class(class_name_text: String) -> bool:
	return ClassDB.class_exists(class_name_text)


func _instantiate_class(class_name_text: String):
	if not _has_class(class_name_text):
		return null
	return ClassDB.instantiate(class_name_text)


func _all_true(values: Dictionary, keys: Array[String]) -> bool:
	for key in keys:
		if not bool(values.get(key, false)):
			return false
	return true


func _free_if_node(object) -> void:
	if object is Node:
		(object as Node).queue_free()
