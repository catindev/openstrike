extends SceneTree

const LocalGameSessionRef = preload("res://src/game/runtime/openstrike_local_game_session.gd")
const PlayerSlotRef = preload("res://src/game/runtime/openstrike_player_slot.gd")
const RoundStateRef = preload("res://src/game/runtime/openstrike_round_state.gd")
const UserCommandRef = preload("res://src/game/runtime/openstrike_user_command.gd")


class DescriptorOnlySpawnIndex:
	var _descriptors_by_class: Dictionary = {}


	func _init() -> void:
		_descriptors_by_class = {
			"info_player_counterterrorist": [
				_spawn_descriptor("info_player_counterterrorist", Vector3(10.0, 0.0, 0.0), "0 90 0"),
				_spawn_descriptor("info_player_counterterrorist", Vector3(20.0, 0.0, 0.0), "0 180 0"),
			],
			"info_player_terrorist": [
				_spawn_descriptor("info_player_terrorist", Vector3(-10.0, 0.0, 0.0), "0 270 0"),
			],
			"info_player_deathmatch": [
				_spawn_descriptor("info_player_deathmatch", Vector3(0.0, 0.0, 5.0), "0 45 0"),
			],
		}


	func spawn_descriptors_for_classes(preferred_classes: Array[String]) -> Array[Dictionary]:
		var output: Array[Dictionary] = []
		for classname in preferred_classes:
			var descriptors: Array = _descriptors_by_class.get(classname, [])
			for descriptor_variant in descriptors:
				var descriptor: Dictionary = descriptor_variant
				output.append(descriptor.duplicate(true))
		return output


	func _spawn_descriptor(classname: String, position: Vector3, angles: String) -> Dictionary:
		return {
			"classname": classname,
			"position": position,
			"yaw": _yaw_from_angles(angles),
			"origin": "%f %f %f" % [position.x, position.y, position.z],
			"angles": angles,
			"source": "synthetic_descriptor_index",
		}


	func _yaw_from_angles(angles: String) -> float:
		var parts := angles.split(" ", false)
		if parts.size() >= 2 and String(parts[1]).is_valid_float():
			return -deg_to_rad(float(String(parts[1]).to_float()))
		return 0.0


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var entity_index = DescriptorOnlySpawnIndex.new()

	var session = LocalGameSessionRef.new()
	session.configure(0.01, entity_index)
	var ct_id: int = session.add_player("ct", PlayerSlotRef.TEAM_COUNTER_TERRORIST)
	var t_id: int = session.add_player("t", PlayerSlotRef.TEAM_TERRORIST)
	session.start_round(RoundStateRef.PHASE_FREEZE_TIME)

	var initial_snapshot = session.snapshot()
	var initial_report: Dictionary = initial_snapshot.to_dictionary()
	if not _assert(initial_report["tick"] == 0, "New round snapshot should start at tick 0", initial_report):
		return 1
	if not _assert(initial_report["round_state"]["phase"] == RoundStateRef.PHASE_FREEZE_TIME, "New round should start in freeze time", initial_report):
		return 1

	var players: Array = initial_report["players"]
	if not _assert(players.size() == 2, "Session snapshot should contain two players", initial_report):
		return 1
	if not _assert(players[0]["spawn_classname"] == "info_player_counterterrorist", "CT player should use CT spawn priority", players[0]):
		return 1
	if not _assert(players[1]["spawn_classname"] == "info_player_terrorist", "T player should use T spawn priority", players[1]):
		return 1
	if not _assert(players[0]["spawn_position"] == [10.0, 0.0, 0.0], "CT player should spawn from descriptor position", players[0]):
		return 1
	if not _assert(players[1]["spawn_position"] == [-10.0, 0.0, 0.0], "T player should spawn from descriptor position", players[1]):
		return 1

	var command = UserCommandRef.new()
	command.configure(1, ct_id, 1.0, 0.0, true, false, 0.5, -0.1)
	if not _assert(session.queue_command(command), "Known player command should be accepted", command.to_dictionary()):
		return 1

	var rejected_command = UserCommandRef.new()
	rejected_command.configure(1, 999, 1.0, 0.0)
	if not _assert(not session.queue_command(rejected_command), "Unknown player command should be rejected", rejected_command.to_dictionary()):
		return 1

	var steps: int = session.step(0.015)
	if not _assert(steps == 1, "Session should advance exactly one fixed tick for 0.015s at 100 Hz", {"steps": steps}):
		return 1

	var tick_snapshot = session.snapshot()
	var tick_report: Dictionary = tick_snapshot.to_dictionary()
	if not _assert(tick_report["tick"] == 1, "Session should advance to tick 1", tick_report):
		return 1
	if not _assert(tick_report["round_state"]["phase_tick"] == 1, "Round phase tick should advance with server tick", tick_report):
		return 1
	if not _assert(tick_report["applied_commands"].size() == 1, "Session should apply one queued command on tick 1", tick_report):
		return 1
	if not _assert(tick_report["players"][0]["last_command_tick"] == 1, "Applied command should update player command tick", tick_report["players"][0]):
		return 1

	print("Local game session smoke passed.")
	return 0


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
