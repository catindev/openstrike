extends SceneTree

const AssetManagerRef = preload("res://src/core/assets/asset_manager.gd")
const BspProviderRef = preload("res://src/core/maps/goldsrc_bsp_runtime_provider.gd")
const RunnerRef = preload("res://src/dev/labs/bsp_walkable/bsp_walkable_runner.gd")
const ViewmodelWorldProfileRef = preload("res://src/core/units/viewmodel_world_profile.gd")


func _init() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	if bool(options.get("capability_smoke", false)):
		quit(_run_capability_smoke())
		return
	if bool(options.get("load_smoke", false)):
		quit(_run_load_smoke(options))
		return

	var runner = RunnerRef.new()
	runner.configure(options)
	root.add_child(runner)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var options := {
		"config_path": "user://local_goldsrc.json",
		"map_path": RunnerRef.DEFAULT_MAP_PATH,
		"trace_enabled": true,
		"start_uncaptured": false,
		"auto_exit_sec": 0.0,
		"fullscreen": true,
		"capability_smoke": false,
		"load_smoke": false,
	}

	for arg in args:
		if arg == "--capability-smoke":
			options["capability_smoke"] = true
		elif arg == "--load-smoke":
			options["load_smoke"] = true
		elif arg == "--no-trace":
			options["trace_enabled"] = false
		elif arg == "--uncaptured":
			options["start_uncaptured"] = true
		elif arg == "--windowed":
			options["fullscreen"] = false
		elif arg == "--fullscreen":
			options["fullscreen"] = true
		elif arg.begins_with("--config="):
			options["config_path"] = arg.trim_prefix("--config=")
		elif arg.begins_with("--map="):
			options["map_path"] = arg.trim_prefix("--map=")
		elif arg.begins_with("--auto-exit-sec="):
			options["auto_exit_sec"] = float(arg.trim_prefix("--auto-exit-sec=").to_float())

	return options


func _run_capability_smoke() -> int:
	var provider = BspProviderRef.new()
	var report: Dictionary = provider.inspect_capabilities()
	var capabilities: Dictionary = report.get("coverage_capability", {})
	if not capabilities.has("bsp_scene"):
		push_error("BSP lab capability smoke failed: missing bsp_scene capability.")
		return 1
	if str(capabilities.get("hull_trace", "")) != BspProviderRef.CAP_REQUIRES_OPENSTRIKE_BSP_READER:
		push_error("BSP lab capability smoke failed: hull_trace must remain requires_openstrike_bsp_reader.")
		return 1
	print("BSP walkable lab capability smoke passed.")
	return 0


func _run_load_smoke(options: Dictionary) -> int:
	var profile = ViewmodelWorldProfileRef.new()
	profile.load_from_file()
	if not profile.is_valid():
		push_error("BSP lab load smoke failed: invalid viewmodel/world profile.")
		return 1

	var asset_manager = AssetManagerRef.create_from_config_path(str(options.get("config_path", "user://local_goldsrc.json")))
	if not asset_manager.is_available():
		push_error("BSP lab load smoke failed: local GoldSrc asset manager is unavailable: %s" % JSON.stringify(asset_manager.get_diagnostics()))
		return 1

	var provider = BspProviderRef.new()
	var load_result: Dictionary = provider.load_map_from_vfs(asset_manager.vfs, str(options.get("map_path", RunnerRef.DEFAULT_MAP_PATH)), profile.goldsrc_unit_scale)
	if not bool(load_result.get("ok", false)):
		var clone := load_result.duplicate(true)
		clone.erase("node")
		push_error("BSP lab load smoke failed: %s" % JSON.stringify(clone))
		return 1

	var metadata: Dictionary = load_result.get("metadata", {})
	var counts: Dictionary = metadata.get("scene_counts", {})
	var spawn_count := int(metadata.get("spawn_count", 0))
	if spawn_count <= 0:
		push_error("BSP lab load smoke failed: loaded map has no player spawn entities.")
		return 1
	if int(counts.get("collision_shapes", 0)) <= 0:
		push_error("BSP lab load smoke failed: loaded map has no imported CollisionShape3D nodes.")
		return 1

	print("BSP walkable lab load smoke passed: %s" % JSON.stringify({
		"map_path": str(options.get("map_path", RunnerRef.DEFAULT_MAP_PATH)),
		"spawn_count": spawn_count,
		"scene_counts": counts,
		"collision_source": BspProviderRef.COLLISION_SOURCE_GODOT_SCENE,
	}))
	var node = load_result.get("node", null)
	if node is Node:
		(node as Node).queue_free()
	return 0
