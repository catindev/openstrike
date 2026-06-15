extends SceneTree

const BspProviderRef = preload("res://src/core/maps/goldsrc_bsp_runtime_provider.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var provider = BspProviderRef.new()
	var report: Dictionary = provider.inspect_capabilities()
	var capabilities: Dictionary = report.get("coverage_capability", {})
	var collision_contract: Dictionary = report.get("collision_contract", {})

	if not _assert(str(report.get("provider", "")) == BspProviderRef.PROVIDER_ID, "BSP provider should identify goldsrc-godot provider", report):
		return 1
	if not _assert(capabilities.has("bsp_scene"), "BSP provider should report BSP scene capability", report):
		return 1
	if not _assert(capabilities.has("scene_collision"), "BSP provider should report imported scene collision capability", report):
		return 1
	if not _assert(str(capabilities.get("clipnodes", "")) == BspProviderRef.CAP_REQUIRES_OPENSTRIKE_BSP_READER, "BSP provider must not claim clipnode API before OpenStrike owns a BSP reader", report):
		return 1
	if not _assert(str(capabilities.get("hull_trace", "")) == BspProviderRef.CAP_REQUIRES_OPENSTRIKE_BSP_READER, "BSP provider must not claim GoldSrc hull trace API before it exists", report):
		return 1
	if not _assert(str(collision_contract.get("goldsrc_parity_collision_source", "")) == BspProviderRef.COLLISION_SOURCE_GOLDSRC_HULL_TRACE, "BSP provider should document the target GoldSrc collision source", report):
		return 1

	if not bool(report.get("extension_available", false)):
		if not _assert(str(capabilities.get("bsp_scene", "")) == BspProviderRef.CAP_EXTENSION_MISSING, "missing extension should be reported as extension_missing, not a fake success", report):
			return 1
	else:
		if not _assert(str(capabilities.get("bsp_scene", "")) == BspProviderRef.CAP_SUPPORTED_BY_LOADER_API, "available extension should expose BSP scene loading through loader API", report):
			return 1
		if not _assert(str(capabilities.get("scene_collision", "")) == BspProviderRef.CAP_AVAILABLE_AFTER_IMPORTED_SCENE_INSPECTION, "scene collision should be explicitly scoped to imported scene inspection", report):
			return 1
		if not _assert(str(collision_contract.get("runtime_collision_source", "")) == BspProviderRef.COLLISION_SOURCE_GODOT_SCENE, "runtime collision source should be marked as Godot scene collision for the first walkable lab", report):
			return 1

	print("GoldSrc BSP runtime provider smoke passed.")
	return 0


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
