extends RefCounted

class_name OpenStrikeMapEntityIndex

const CATEGORY_WORLDSPAWN := "worldspawn"
const CATEGORY_PLAYER_SPAWN := "player_spawn"
const CATEGORY_SEMANTIC_VOLUME := "semantic_volume"
const CATEGORY_TRIGGER_VOLUME := "trigger_volume"
const CATEGORY_ILLUSIONARY := "illusionary"
const CATEGORY_POINT_METADATA := "point_metadata"
const CATEGORY_SOLID_CANDIDATE := "solid_candidate"
const CATEGORY_UNKNOWN := "unknown"

const COLLISION_POLICY_DISABLE_PLAYER := "disable_player_collision"
const COLLISION_POLICY_KEEP_SCENE := "keep_scene_collision"
const COLLISION_POLICY_NO_COLLISION_EXPECTED := "no_collision_expected"
const COLLISION_POLICY_UNKNOWN := "unknown"

const DEFAULT_SPAWN_PRIORITY: Array[String] = [
	"info_player_deathmatch",
	"info_player_start",
	"info_player_counterterrorist",
	"info_player_terrorist",
]

const PLAYER_SPAWN_CLASSES: Array[String] = [
	"info_player_deathmatch",
	"info_player_start",
	"info_player_counterterrorist",
	"info_player_terrorist",
]

const BUYZONE_CLASSES: Array[String] = ["func_buyzone"]
const BOMB_TARGET_CLASSES: Array[String] = ["func_bomb_target", "info_bomb_target"]
const ILLUSIONARY_CLASSES: Array[String] = ["func_illusionary"]
const POINT_METADATA_CLASSES: Array[String] = [
	"info_target",
	"light",
	"light_environment",
]

var _entries: Array[Dictionary] = []
var _class_counts := {}
var _category_counts := {}
var _collision_policy_counts := {}


func build_from_scene(root: Node) -> void:
	clear()
	if root == null:
		return

	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current.has_meta("entity"):
			var entity = current.get_meta("entity")
			if entity is Dictionary:
				_add_entity(current, entity)
		for child in current.get_children():
			if child is Node:
				stack.append(child)


func clear() -> void:
	_entries.clear()
	_class_counts.clear()
	_category_counts.clear()
	_collision_policy_counts.clear()


func entries() -> Array[Dictionary]:
	return _entries.duplicate()


func entries_for_player_collision_disabled() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for entry in _entries:
		if str(entry.get("collision_policy", "")) == COLLISION_POLICY_DISABLE_PLAYER:
			output.append(entry)
	return output


func spawn_descriptors_for_classes(preferred_classes: Array[String] = DEFAULT_SPAWN_PRIORITY) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for classname in preferred_classes:
		for entry in _entries:
			if str(entry.get("classname", "")) != classname:
				continue
			var node = entry.get("node", null)
			if not (node is Node3D):
				continue
			output.append(_spawn_descriptor_from_entry(entry))
	return output


func select_spawn_node(preferred_classes: Array[String] = DEFAULT_SPAWN_PRIORITY) -> Node3D:
	for classname in preferred_classes:
		for entry in _entries:
			if str(entry.get("classname", "")) != classname:
				continue
			var node = entry.get("node", null)
			if node is Node3D:
				return node as Node3D
	return null


func to_report() -> Dictionary:
	return {
		"entity_count": _entries.size(),
		"class_counts": _class_counts.duplicate(true),
		"category_counts": _category_counts.duplicate(true),
		"collision_policy_counts": _collision_policy_counts.duplicate(true),
		"spawn_count": _count_category(CATEGORY_PLAYER_SPAWN),
		"disabled_player_collision_classes": _classes_for_collision_policy(COLLISION_POLICY_DISABLE_PLAYER),
		"unknown_classes": _classes_for_category(CATEGORY_UNKNOWN),
		"source": "imported_scene_entity_metadata",
	}


func _add_entity(node: Node, entity: Dictionary) -> void:
	var classname := str(entity.get("classname", "")).strip_edges().to_lower()
	if classname == "":
		classname = "<missing>"
	var classification := _classify(classname)
	var entry := {
		"node": node,
		"entity": entity,
		"classname": classname,
		"category": str(classification.get("category", CATEGORY_UNKNOWN)),
		"role": str(classification.get("role", "")),
		"collision_policy": str(classification.get("collision_policy", COLLISION_POLICY_UNKNOWN)),
	}
	_entries.append(entry)
	_class_counts[classname] = int(_class_counts.get(classname, 0)) + 1
	_category_counts[entry["category"]] = int(_category_counts.get(entry["category"], 0)) + 1
	_collision_policy_counts[entry["collision_policy"]] = int(_collision_policy_counts.get(entry["collision_policy"], 0)) + 1


func _classify(classname: String) -> Dictionary:
	if classname == "worldspawn":
		return _classification(CATEGORY_WORLDSPAWN, "worldspawn", COLLISION_POLICY_KEEP_SCENE)
	if PLAYER_SPAWN_CLASSES.has(classname):
		return _classification(CATEGORY_PLAYER_SPAWN, "player_spawn", COLLISION_POLICY_NO_COLLISION_EXPECTED)
	if BUYZONE_CLASSES.has(classname):
		return _classification(CATEGORY_SEMANTIC_VOLUME, "buyzone", COLLISION_POLICY_DISABLE_PLAYER)
	if BOMB_TARGET_CLASSES.has(classname):
		return _classification(CATEGORY_SEMANTIC_VOLUME, "bomb_target", COLLISION_POLICY_DISABLE_PLAYER)
	if ILLUSIONARY_CLASSES.has(classname):
		return _classification(CATEGORY_ILLUSIONARY, "illusionary", COLLISION_POLICY_DISABLE_PLAYER)
	if classname.begins_with("trigger_"):
		return _classification(CATEGORY_TRIGGER_VOLUME, "trigger", COLLISION_POLICY_DISABLE_PLAYER)
	if POINT_METADATA_CLASSES.has(classname):
		return _classification(CATEGORY_POINT_METADATA, "point_metadata", COLLISION_POLICY_NO_COLLISION_EXPECTED)
	if classname.begins_with("func_"):
		return _classification(CATEGORY_SOLID_CANDIDATE, "brush_entity", COLLISION_POLICY_KEEP_SCENE)
	return _classification(CATEGORY_UNKNOWN, "unknown", COLLISION_POLICY_UNKNOWN)


func _classification(category: String, role: String, collision_policy: String) -> Dictionary:
	return {
		"category": category,
		"role": role,
		"collision_policy": collision_policy,
	}


func _spawn_descriptor_from_entry(entry: Dictionary) -> Dictionary:
	var node := entry.get("node", null) as Node3D
	var entity: Dictionary = entry.get("entity", {})
	return {
		"classname": str(entry.get("classname", "")),
		"position": _node_position(node),
		"yaw": _yaw_from_entity_or_node(entity, node),
		"origin": str(entity.get("origin", "")),
		"angles": str(entity.get("angles", "")),
	}


func _node_position(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO
	if node.is_inside_tree():
		return node.global_position
	return node.transform.origin


func _yaw_from_entity_or_node(entity: Dictionary, node: Node3D) -> float:
	var angles := str(entity.get("angles", "")).split(" ", false)
	if angles.size() >= 2 and String(angles[1]).is_valid_float():
		return -deg_to_rad(float(String(angles[1]).to_float()))
	return node.global_rotation.y if node != null else 0.0


func _count_category(category: String) -> int:
	return int(_category_counts.get(category, 0))


func _classes_for_collision_policy(collision_policy: String) -> Dictionary:
	var output := {}
	for entry in _entries:
		if str(entry.get("collision_policy", "")) != collision_policy:
			continue
		var classname := str(entry.get("classname", ""))
		output[classname] = int(output.get(classname, 0)) + 1
	return output


func _classes_for_category(category: String) -> Dictionary:
	var output := {}
	for entry in _entries:
		if str(entry.get("category", "")) != category:
			continue
		var classname := str(entry.get("classname", ""))
		output[classname] = int(output.get(classname, 0)) + 1
	return output
