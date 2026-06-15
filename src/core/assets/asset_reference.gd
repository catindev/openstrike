extends RefCounted

class_name OpenStrikeAssetReference

const OpenStrikeAssetDiagnosticsRef = preload("res://src/core/assets/asset_diagnostics.gd")

const ALLOWED_PROVIDERS := ["goldsrc"]
const ALLOWED_ENTRY_KEYS := ["type", "path", "provider", "metadata"]
const TYPE_EXTENSIONS := {
	"view_model": ".mdl",
	"sprite": ".spr",
	"sound": ".wav",
}

var asset_id: StringName = &""
var asset_type: StringName = &""
var relative_path: String = ""
var provider_id: StringName = &"goldsrc"
var metadata: Dictionary = {}
var diagnostics: Array[Dictionary] = []


func configure(id: StringName, data: Dictionary) -> void:
	asset_id = id
	asset_type = StringName(str(data.get("type", "")).strip_edges())
	var requested_path := str(data.get("path", "")).strip_edges()
	relative_path = _normalize_relative_path(requested_path)
	provider_id = StringName(str(data.get("provider", "goldsrc")).strip_edges())
	metadata = {}
	diagnostics.clear()

	var raw_metadata = data.get("metadata", {})
	if raw_metadata is Dictionary:
		metadata = raw_metadata.duplicate(true)
	else:
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.warning(
			"asset_reference_metadata_invalid",
			"Asset reference metadata must be a dictionary.",
			{"asset_id": str(asset_id)}
		))

	_validate_entry_keys(data)
	_validate(requested_path)


func is_valid() -> bool:
	return not OpenStrikeAssetDiagnosticsRef.has_errors(diagnostics)


func to_dictionary() -> Dictionary:
	return {
		"asset_id": str(asset_id),
		"type": str(asset_type),
		"path": relative_path,
		"provider": str(provider_id),
		"metadata": metadata,
		"valid": is_valid(),
		"diagnostics": diagnostics,
	}


func _validate(requested_path: String) -> void:
	if asset_id == StringName():
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_reference_id_missing",
			"Asset reference requires a semantic asset id."
		))

	if asset_type == StringName():
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_reference_type_missing",
			"Asset reference requires a semantic asset type.",
			{"asset_id": str(asset_id)}
		))
	elif not TYPE_EXTENSIONS.has(str(asset_type)):
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_reference_type_unsupported",
			"Asset reference type is not supported by the current manifest contract.",
			{"asset_id": str(asset_id), "type": str(asset_type), "allowed": TYPE_EXTENSIONS.keys()}
		))

	_validate_requested_path(requested_path)

	if relative_path != "" and TYPE_EXTENSIONS.has(str(asset_type)):
		var expected_extension: String = TYPE_EXTENSIONS[str(asset_type)]
		var actual_extension := ".%s" % relative_path.get_extension().to_lower()
		if actual_extension != expected_extension:
			diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
				"asset_reference_extension_mismatch",
				"Asset reference path extension does not match its semantic type.",
				{
					"asset_id": str(asset_id),
					"type": str(asset_type),
					"path": relative_path,
					"expected_extension": expected_extension,
					"actual_extension": actual_extension,
				}
			))

	if provider_id == StringName():
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_reference_provider_missing",
			"Asset reference requires a provider id.",
			{"asset_id": str(asset_id)}
		))
	elif not ALLOWED_PROVIDERS.has(str(provider_id)):
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_reference_provider_unsupported",
			"Asset reference provider is not supported by the current manifest contract.",
			{"asset_id": str(asset_id), "provider": str(provider_id), "allowed": ALLOWED_PROVIDERS}
		))


func _validate_entry_keys(data: Dictionary) -> void:
	for key in data.keys():
		var key_text := str(key)
		if ALLOWED_ENTRY_KEYS.has(key_text):
			continue
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_reference_unknown_key",
			"Asset manifest entries may only use the approved top-level keys.",
			{"asset_id": str(asset_id), "key": key_text, "allowed": ALLOWED_ENTRY_KEYS}
		))


func _validate_requested_path(requested_path: String) -> void:
	if requested_path == "":
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_reference_path_missing",
			"Asset reference requires a GoldSrc-relative path.",
			{"asset_id": str(asset_id)}
		))
		return

	if requested_path.contains("\\"):
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_reference_path_backslash",
			"Asset reference paths must use forward slashes to avoid traversal ambiguity.",
			{"asset_id": str(asset_id), "path": requested_path}
		))

	if _is_absolute_or_uri_path(requested_path):
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_reference_path_absolute",
			"Asset reference paths must be relative GoldSrc paths.",
			{"asset_id": str(asset_id), "path": requested_path}
		))

	for part in requested_path.replace("\\", "/").split("/", false):
		if String(part).strip_edges() == "..":
			diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
				"asset_reference_path_traversal",
				"Asset reference paths must not contain parent traversal.",
				{"asset_id": str(asset_id), "path": requested_path}
			))
			return

	if relative_path == "":
		diagnostics.append(OpenStrikeAssetDiagnosticsRef.error(
			"asset_reference_path_invalid",
			"Asset reference path could not be normalized to a GoldSrc-relative path.",
			{"asset_id": str(asset_id), "path": requested_path}
		))


static func _normalize_relative_path(path: String) -> String:
	var normalized := path.strip_edges()
	if normalized == "":
		return ""
	if normalized.contains("\\"):
		return ""
	if _is_absolute_or_uri_path(normalized):
		return ""

	while normalized.begins_with("./"):
		normalized = normalized.substr(2)

	var output: Array[String] = []
	for part in normalized.split("/", false):
		var clean_part := String(part).strip_edges()
		if clean_part == "" or clean_part == ".":
			continue
		if clean_part == "..":
			return ""
		output.append(clean_part.to_lower())

	return "/".join(output)


static func _is_absolute_or_uri_path(path: String) -> bool:
	return (
		path.contains("://")
		or path.begins_with("/")
		or (path.length() > 2 and path.substr(1, 1) == ":")
	)
