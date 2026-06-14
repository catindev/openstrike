extends SceneTree

const BindRegistryRef = preload("res://src/core/config/bind_registry.gd")
const ConfigLoaderRef = preload("res://src/core/config/config_loader.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var cvars = ConfigLoaderRef.load_default_cvars()
	if not _assert(cvars.get_int("sv_gravity") == 800, "sv_gravity should load from default cfg", cvars.to_dictionary()):
		return 1
	if not _assert(cvars.get_float("sv_friction") == 4.0, "sv_friction should load as numeric value", cvars.to_dictionary()):
		return 1
	if not _assert(cvars.get_int("mp_startmoney") == 800, "mp_startmoney should load from default cfg", cvars.to_dictionary()):
		return 1

	cvars.apply_cfg_text("sv_gravity 700\nname \"OpenStrike Player\"\n", "smoke_user_cfg")
	if not _assert(cvars.get_int("sv_gravity") == 700, "user cfg should override existing cvar value", cvars.to_dictionary()):
		return 1
	if not _assert(cvars.get_string("name") == "OpenStrike Player", "user cfg should support quoted strings", cvars.to_dictionary()):
		return 1

	var serialized = cvars.serialize_cfg()
	if not _assert(serialized.contains("sv_gravity 700"), "serialized cfg should include updated cvar", {"serialized": serialized}):
		return 1

	var binds = BindRegistryRef.new()
	if not _assert(binds.apply_bind_line("bind \"w\" \"+forward\"", "smoke", 1), "bind line should parse", binds.to_dictionary()):
		return 1
	if not _assert(binds.get_command("W") == "+forward", "bind lookup should be case-insensitive", binds.to_dictionary()):
		return 1
	if not _assert(binds.apply_bind_line("unbind w", "smoke", 2), "unbind line should parse", binds.to_dictionary()):
		return 1
	if not _assert(not binds.has_binding("w"), "unbind should remove binding", binds.to_dictionary()):
		return 1

	print("Cvar config smoke passed.")
	return 0


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
