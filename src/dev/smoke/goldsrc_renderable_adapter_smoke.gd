extends SceneTree

const RenderableProviderRef = preload("res://src/presentation/viewmodel/goldsrc_renderable_provider.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var provider = RenderableProviderRef.new()
	var report: Dictionary = provider.inspect_capabilities()
	var capabilities: Dictionary = report.get("coverage_capability", {})

	if not _assert(str(report.get("provider", "")) == RenderableProviderRef.PROVIDER_ID, "adapter should identify goldsrc-godot provider", report):
		return 1
	if not _assert(capabilities.has("viewmodel_scene"), "adapter should report viewmodel scene capability", report):
		return 1
	if not _assert(str(capabilities.get("attachments", "")) == RenderableProviderRef.CAP_REQUIRES_OPENSTRIKE_MDL_READER, "adapter must not claim attachment/socket API before the loader exposes it", report):
		return 1
	if not _assert(str(capabilities.get("animation_events", "")) == RenderableProviderRef.CAP_REQUIRES_OPENSTRIKE_MDL_READER, "adapter must not claim MDL event API before the loader exposes it", report):
		return 1

	if not bool(report.get("extension_available", false)):
		if not _assert(str(capabilities.get("viewmodel_scene", "")) == RenderableProviderRef.CAP_EXTENSION_MISSING, "missing extension should be reported as extension_missing, not a fake success", report):
			return 1
	else:
		if not _assert(str(capabilities.get("viewmodel_scene", "")) == RenderableProviderRef.CAP_SUPPORTED_BY_LOADER_API, "available extension should expose viewmodel_scene through loader API", report):
			return 1
		if not _assert(str(capabilities.get("sequence_names", "")) == RenderableProviderRef.CAP_SUPPORTED_BY_LOADER_API, "available extension should expose sequence names through loader API", report):
			return 1

	print("GoldSrc renderable adapter smoke passed.")
	return 0


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
