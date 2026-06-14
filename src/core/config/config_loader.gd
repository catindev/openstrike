extends RefCounted

class_name OpenStrikeConfigLoader

const DEFAULT_CVARS_PATH := "res://data/cvars/default.cfg"

const BindRegistryRef = preload("res://src/core/config/bind_registry.gd")
const CvarRegistryRef = preload("res://src/core/config/cvar_registry.gd")


static func load_default_cvars(path: String = DEFAULT_CVARS_PATH):
	var registry = CvarRegistryRef.new()
	registry.load_cfg_file(path)
	return registry


static func create_empty_bind_registry():
	return BindRegistryRef.new()
