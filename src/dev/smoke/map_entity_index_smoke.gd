extends SceneTree

const MapEntityIndexRef = preload("res://src/core/maps/map_entity_index.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var root := Node3D.new()
	root.name = "SyntheticMapRoot"
	root.add_child(_entity_node("Worldspawn", "worldspawn", Vector3.ZERO))
	root.add_child(_entity_node("TSpawn", "info_player_start", Vector3(1.0, 2.0, 3.0)))
	root.add_child(_entity_node("DeathmatchSpawn", "info_player_deathmatch", Vector3(4.0, 5.0, 6.0)))
	root.add_child(_entity_node("Buyzone", "func_buyzone", Vector3.ZERO))
	root.add_child(_entity_node("BombBrush", "func_bomb_target", Vector3.ZERO))
	root.add_child(_entity_node("BombPoint", "info_bomb_target", Vector3.ZERO))
	root.add_child(_entity_node("Illusionary", "func_illusionary", Vector3.ZERO))
	root.add_child(_entity_node("TriggerCamera", "trigger_camera", Vector3.ZERO))
	root.add_child(_entity_node("LightEnvironment", "light_environment", Vector3.ZERO))
	root.add_child(_entity_node("SolidDoor", "func_door", Vector3.ZERO))
	root.add_child(_entity_node("CustomThing", "custom_unknown", Vector3.ZERO))

	var index = MapEntityIndexRef.new()
	index.build_from_scene(root)
	var report: Dictionary = index.to_report()

	if not _assert(int(report.get("spawn_count", 0)) == 2, "Entity index should count supported spawn classes", report):
		root.free()
		return 1

	var selected_spawn := index.select_spawn_node()
	if not _assert(selected_spawn != null and selected_spawn.name == "DeathmatchSpawn", "Entity index should prefer info_player_deathmatch spawn", _spawn_name(selected_spawn)):
		root.free()
		return 1

	var disabled_classes: Dictionary = report.get("disabled_player_collision_classes", {})
	for classname in ["func_buyzone", "func_bomb_target", "info_bomb_target", "func_illusionary", "trigger_camera"]:
		if not _assert(int(disabled_classes.get(classname, 0)) == 1, "Entity index should mark non-blocking semantic/trigger entities for collision disable", {"classname": classname, "report": report}):
			root.free()
			return 1

	if not _assert(not disabled_classes.has("func_door"), "Solid brush entities should keep scene collision in the temporary backend", report):
		root.free()
		return 1
	if not _assert(report.get("unknown_classes", {}).has("custom_unknown"), "Unknown entity classes should remain visible in reports", report):
		root.free()
		return 1

	root.free()
	print("Map entity index smoke passed.")
	return 0


func _entity_node(node_name: String, classname: String, position: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = position
	node.set_meta("entity", {
		"classname": classname,
		"origin": "%f %f %f" % [position.x, position.y, position.z],
		"angles": "0 90 0",
	})
	return node


func _spawn_name(node: Node3D) -> String:
	return node.name if node != null else "<null>"


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
