extends SceneTree

const DEFAULT_CATALOG_PATH := "res://data/assets/cs16_pilot_weapon_assets.json"
const TOOL_NAME := "viewmodel_manual_preflight"

const OpenStrikeAssetManagerRef = preload("res://src/core/assets/asset_manager.gd")
const OpenStrikeGoldSrcLocalConfigRef = preload("res://src/core/assets/goldsrc_local_config.gd")
const ProfileRef = preload("res://src/core/units/viewmodel_world_profile.gd")
const RenderableProviderRef = preload("res://src/presentation/viewmodel/goldsrc_renderable_provider.gd")

const SENSITIVE_CONTEXT_KEYS := [
	"cstrike_dir",
	"dir",
	"directory",
	"half_life_dir",
	"path",
	"root",
	"roots",
	"resolved_path",
	"search_roots",
	"source_path",
	"tried",
	"valve_dir",
]


func _init() -> void:
	var exit_code := _run()
	if exit_code >= 0:
		quit(exit_code)


func _run() -> int:
	var options := _parse_args()
	if bool(options.get("help", false)):
		_print_usage()
		return 0
	if bool(options.get("capability_smoke", false)):
		return _run_capability_smoke()

	var profile = ProfileRef.new()
	profile.load_from_file(str(options.get("profile", ProfileRef.DEFAULT_PROFILE_PATH)))
	if not profile.is_valid():
		_print_output(false, "profile_invalid", {
			"profile": _path_label(str(options.get("profile", "")), "<custom-profile>"),
			"diagnostics": _sanitize_diagnostics(profile.diagnostics),
		})
		return 1

	var manager = OpenStrikeAssetManagerRef.new()
	manager.configure_from_config_path(str(options.get("config", OpenStrikeGoldSrcLocalConfigRef.DEFAULT_CONFIG_PATH)))
	manager.configure_asset_manifest_from_file(str(options.get("catalog", DEFAULT_CATALOG_PATH)))

	var asset_id := StringName(str(options.get("asset_id", "weapon.ak47.viewmodel")))
	var asset_result = manager.inspect_view_model(asset_id)
	var provider = RenderableProviderRef.new()
	var renderable := provider.build_view_model(asset_result, profile, true)
	var output := _build_output(manager, asset_result, renderable, profile, options)
	print(JSON.stringify(output))

	if _has_errors(manager.get_diagnostics()) or _has_errors(asset_result.diagnostics) or _has_errors(renderable.get("diagnostics", [])):
		_free_renderable(renderable)
		return 1

	if bool(options.get("visual", false)):
		_setup_visual_scene(renderable, profile, asset_id)
		return -1

	_free_renderable(renderable)
	return 0


func _run_capability_smoke() -> int:
	var provider = RenderableProviderRef.new()
	var report: Dictionary = provider.inspect_capabilities()
	var capabilities: Dictionary = report.get("coverage_capability", {})
	var complete := capabilities.has("viewmodel_scene") and str(capabilities.get("attachments", "")) == RenderableProviderRef.CAP_REQUIRES_OPENSTRIKE_MDL_READER
	print(JSON.stringify({
		"tool": TOOL_NAME,
		"mode": "capability_smoke",
		"complete": complete,
		"capabilities": report,
	}))
	return 0 if complete else 1


func _setup_visual_scene(renderable: Dictionary, profile, asset_id: StringName) -> void:
	var window := get_root()
	window.title = "OpenStrike viewmodel preflight: %s" % str(asset_id)

	var scene := Node3D.new()
	scene.name = "ViewmodelManualPreflight"
	window.add_child(scene)

	var camera := Camera3D.new()
	camera.name = "WorldCamera"
	camera.current = true
	camera.near = 0.01
	profile.apply_to_camera(camera)
	scene.add_child(camera)

	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	light.light_energy = 1.5
	scene.add_child(light)

	var model_node = renderable.get("node", null)
	if model_node is Node3D:
		camera.add_child(model_node)
		(model_node as Node3D).transform = Transform3D.IDENTITY

	var canvas := CanvasLayer.new()
	window.add_child(canvas)
	var label := Label.new()
	label.text = "OpenStrike viewmodel preflight\n%s\nProfile scale/FOV only; no per-weapon transform.\nClose the window when done." % str(asset_id)
	label.position = Vector2(16.0, 16.0)
	canvas.add_child(label)


func _build_output(manager, asset_result, renderable: Dictionary, profile, options: Dictionary) -> Dictionary:
	return {
		"tool": TOOL_NAME,
		"mode": "visual" if bool(options.get("visual", false)) else "inspection",
		"complete": bool(renderable.get("ok", false)),
		"config": _path_label(str(options.get("config", "")), "<custom-config>"),
		"catalog": _path_label(str(options.get("catalog", "")), "<custom-catalog>"),
		"profile": _path_label(str(options.get("profile", "")), "<custom-profile>"),
		"asset": _sanitize_asset_result(asset_result),
		"renderable": {
			"ok": bool(renderable.get("ok", false)),
			"metadata": renderable.get("metadata", {}),
			"capabilities": renderable.get("capabilities", {}),
			"diagnostics": _sanitize_diagnostics(renderable.get("diagnostics", [])),
		},
		"profile_values": {
			"goldsrc_unit_scale": profile.goldsrc_unit_scale,
			"world_fov_horizontal_ref": profile.world_fov_horizontal_ref,
			"viewmodel_fov_horizontal_ref": profile.viewmodel_fov_horizontal_ref,
			"world_vertical_fov": profile.world_vertical_fov(),
			"camera_keep_aspect": profile.camera_keep_aspect,
		},
		"manager_diagnostics": _sanitize_diagnostics(manager.get_diagnostics()),
	}


func _parse_args() -> Dictionary:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()

	var options := {
		"asset_id": "weapon.ak47.viewmodel",
		"catalog": DEFAULT_CATALOG_PATH,
		"config": OpenStrikeGoldSrcLocalConfigRef.DEFAULT_CONFIG_PATH,
		"profile": ProfileRef.DEFAULT_PROFILE_PATH,
		"visual": false,
		"capability_smoke": false,
		"help": false,
	}

	var index := 0
	while index < args.size():
		var arg := str(args[index])
		if arg == "--":
			index += 1
			continue
		if arg == "--visual":
			options["visual"] = true
		elif arg == "--capability-smoke":
			options["capability_smoke"] = true
		elif arg == "--help" or arg == "-h":
			options["help"] = true
		elif arg.begins_with("--asset-id="):
			options["asset_id"] = arg.trim_prefix("--asset-id=")
		elif arg == "--asset-id" and index + 1 < args.size():
			index += 1
			options["asset_id"] = str(args[index])
		elif arg.begins_with("--catalog="):
			options["catalog"] = arg.trim_prefix("--catalog=")
		elif arg == "--catalog" and index + 1 < args.size():
			index += 1
			options["catalog"] = str(args[index])
		elif arg.begins_with("--config="):
			options["config"] = arg.trim_prefix("--config=")
		elif arg == "--config" and index + 1 < args.size():
			index += 1
			options["config"] = str(args[index])
		elif arg.begins_with("--profile="):
			options["profile"] = arg.trim_prefix("--profile=")
		elif arg == "--profile" and index + 1 < args.size():
			index += 1
			options["profile"] = str(args[index])
		index += 1

	return options


func _print_usage() -> void:
	print("Usage: Godot --path . --script res://src/dev/tools/viewmodel_manual_preflight.gd -- [--config=user://local_goldsrc.json] [--catalog=res://data/assets/cs16_pilot_weapon_assets.json] [--profile=res://data/config/viewmodel_world_profile.json] [--asset-id=weapon.ak47.viewmodel] [--visual]")
	print("       Use --capability-smoke for CI-safe adapter capability inspection without real assets.")


func _sanitize_asset_result(asset_result) -> Dictionary:
	if asset_result == null:
		return {}
	return {
		"asset_id": str(asset_result.asset_id),
		"type": str(asset_result.asset_type),
		"provider": str(asset_result.provider_id),
		"relative_path": asset_result.relative_path,
		"normalized_path": asset_result.normalized_path,
		"found": asset_result.found,
		"loaded": asset_result.loaded,
		"resolved": asset_result.is_resolved(),
		"metadata": asset_result.metadata,
		"diagnostics": _sanitize_diagnostics(asset_result.diagnostics),
	}


func _sanitize_diagnostics(entries) -> Array:
	var sanitized: Array = []
	if not entries is Array:
		return sanitized

	for raw_entry in entries:
		if not raw_entry is Dictionary:
			continue
		sanitized.append({
			"level": str(raw_entry.get("level", "")),
			"code": str(raw_entry.get("code", "")),
			"message": str(raw_entry.get("message", "")),
			"context": _sanitize_context(raw_entry.get("context", {})),
		})
	return sanitized


func _sanitize_context(context) -> Dictionary:
	var sanitized := {}
	if not context is Dictionary:
		return sanitized

	for key in context.keys():
		var key_text := str(key)
		if SENSITIVE_CONTEXT_KEYS.has(key_text):
			continue
		sanitized[key_text] = context[key]
	return sanitized


func _path_label(path: String, fallback: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://") or path.begins_with("<"):
		return path
	if path == "":
		return ""
	return fallback


func _has_errors(entries) -> bool:
	if not entries is Array:
		return false
	for entry in entries:
		if entry is Dictionary and str(entry.get("level", "")) == "error":
			return true
	return false


func _free_renderable(renderable: Dictionary) -> void:
	var node = renderable.get("node", null)
	if node is Node:
		(node as Node).free()


func _print_output(complete: bool, code: String, context: Dictionary) -> void:
	print(JSON.stringify({
		"tool": TOOL_NAME,
		"complete": complete,
		"diagnostics": [{
			"level": "error" if not complete else "info",
			"code": code,
			"message": code,
			"context": context,
		}],
	}))
