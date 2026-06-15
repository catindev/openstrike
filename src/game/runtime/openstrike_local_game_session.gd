extends RefCounted

class_name OpenStrikeLocalGameSession

const PlayerSlotRef = preload("res://src/game/runtime/openstrike_player_slot.gd")
const RoundStateRef = preload("res://src/game/runtime/openstrike_round_state.gd")
const SnapshotRef = preload("res://src/game/runtime/openstrike_game_snapshot.gd")

const SPAWN_PRIORITY_BY_TEAM := {
	PlayerSlotRef.TEAM_COUNTER_TERRORIST: [
		"info_player_counterterrorist",
		"info_player_deathmatch",
		"info_player_start",
		"info_player_terrorist",
	],
	PlayerSlotRef.TEAM_TERRORIST: [
		"info_player_terrorist",
		"info_player_deathmatch",
		"info_player_start",
		"info_player_counterterrorist",
	],
	PlayerSlotRef.TEAM_UNASSIGNED: [
		"info_player_deathmatch",
		"info_player_start",
		"info_player_counterterrorist",
		"info_player_terrorist",
	],
}

var fixed_delta := 0.01
var current_tick := 0
var round_state = RoundStateRef.new()

var _players := {}
var _next_player_id := 1
var _map_entity_index = null
var _command_queue: Array = []
var _last_applied_commands: Array[Dictionary] = []
var _spawn_cursor_by_team := {}
var _accumulator := 0.0


func configure(sim_delta: float, map_entity_index = null) -> void:
	fixed_delta = max(sim_delta, 0.001)
	_map_entity_index = map_entity_index


func add_player(display_name: String, team: String = PlayerSlotRef.TEAM_UNASSIGNED) -> int:
	var player = PlayerSlotRef.new()
	var player_id := _next_player_id
	_next_player_id += 1
	player.configure(player_id, display_name, team)
	_players[player_id] = player
	return player_id


func start_round(start_phase: String = RoundStateRef.PHASE_FREEZE_TIME) -> void:
	current_tick = 0
	_accumulator = 0.0
	_last_applied_commands.clear()
	_command_queue.clear()
	_spawn_cursor_by_team.clear()
	round_state.start_round(round_state.round_index + 1, start_phase)
	_assign_spawns()


func queue_command(command) -> bool:
	if command == null or not _players.has(command.player_id):
		return false
	_command_queue.append(command)
	return true


func step(delta: float) -> int:
	_accumulator += max(delta, 0.0)
	var steps := 0
	while _accumulator + 0.000001 >= fixed_delta:
		_accumulator -= fixed_delta
		_step_fixed()
		steps += 1
	return steps


func snapshot():
	var output = SnapshotRef.new()
	output.tick = current_tick
	output.fixed_delta = fixed_delta
	output.round_state = round_state.to_dictionary()
	output.players = _player_reports()
	output.applied_commands = _last_applied_commands.duplicate(true)
	return output


func _step_fixed() -> void:
	current_tick += 1
	round_state.advance_tick()
	_apply_queued_commands_for_tick(current_tick)


func _apply_queued_commands_for_tick(tick: int) -> void:
	_last_applied_commands.clear()
	var remaining: Array = []
	for command in _command_queue:
		if command.tick > tick:
			remaining.append(command)
			continue
		var player = _players.get(command.player_id, null)
		if player == null:
			continue
		player.mark_command_applied(command.tick)
		_last_applied_commands.append(command.to_dictionary())
	_command_queue = remaining


func _assign_spawns() -> void:
	for player_id in _sorted_player_ids():
		var player = _players[player_id]
		if player.team == PlayerSlotRef.TEAM_SPECTATOR:
			continue
		var spawn := _select_spawn_for_team(player.team)
		if spawn.is_empty():
			player.assign_spawn("", Vector3.ZERO, 0.0)
		else:
			player.assign_spawn(
				str(spawn.get("classname", "")),
				spawn.get("position", Vector3.ZERO),
				float(spawn.get("yaw", 0.0))
			)


func _select_spawn_for_team(team: String) -> Dictionary:
	if _map_entity_index == null or not _map_entity_index.has_method("entries"):
		return {}

	var priority: Array = SPAWN_PRIORITY_BY_TEAM.get(team, SPAWN_PRIORITY_BY_TEAM[PlayerSlotRef.TEAM_UNASSIGNED])
	var candidates: Array[Dictionary] = []
	for classname in priority:
		for entry in _map_entity_index.entries():
			if str(entry.get("classname", "")) == classname and entry.get("node", null) is Node3D:
				candidates.append(_spawn_from_entry(entry))
		if not candidates.is_empty():
			break

	if candidates.is_empty():
		return {}

	var cursor := int(_spawn_cursor_by_team.get(team, 0))
	_spawn_cursor_by_team[team] = cursor + 1
	return candidates[cursor % candidates.size()]


func _spawn_from_entry(entry: Dictionary) -> Dictionary:
	var node := entry.get("node", null) as Node3D
	var entity: Dictionary = entry.get("entity", {})
	return {
		"classname": str(entry.get("classname", "")),
		"position": _node_position(node),
		"yaw": _yaw_from_entity_or_node(entity, node),
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


func _player_reports() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for player_id in _sorted_player_ids():
		output.append(_players[player_id].to_dictionary())
	return output


func _sorted_player_ids() -> Array[int]:
	var ids: Array[int] = []
	for player_id in _players.keys():
		ids.append(int(player_id))
	ids.sort()
	return ids
