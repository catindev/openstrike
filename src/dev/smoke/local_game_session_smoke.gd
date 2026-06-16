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
	if not _assert_round_bootstrap_and_single_tick():
		return 1
	if not _assert_multistep_applied_commands():
		return 1
	if not _assert_far_future_commands_are_discarded():
		return 1

	print("Local game session smoke passed.")
	return 0


func _assert_round_bootstrap_and_single_tick() -> bool:
	var entity_index = DescriptorOnlySpawnIndex.new()

	var session = LocalGameSessionRef.new()
	session.configure(0.01, entity_index)
	var ct_id: int = session.add_player("ct", PlayerSlotRef.TEAM_COUNTER_TERRORIST)
	var t_id: int = session.add_player("t", PlayerSlotRef.TEAM_TERRORIST)
	session.start_round(RoundStateRef.PHASE_FREEZE_TIME)

	var initial_snapshot = session.snapshot()
	var initial_report: Dictionary = initial_snapshot.to_dictionary()
	if not _assert(initial_report["tick"] == 0, "New round snapshot should start at tick 0", initial_report):
		return false
	if not _assert(initial_report["round_state"]["phase"] == RoundStateRef.PHASE_FREEZE_TIME, "New round should start in freeze time", initial_report):
		return false

	var players: Array = initial_report["players"]
	if not _assert(players.size() == 2, "Session snapshot should contain two players", initial_report):
		return false
	if not _assert(players[0]["spawn_classname"] == "info_player_counterterrorist", "CT player should use CT spawn priority", players[0]):
		return false
	if not _assert(players[1]["spawn_classname"] == "info_player_terrorist", "T player should use T spawn priority", players[1]):
		return false
	if not _assert(players[0]["spawn_position"] == [10.0, 0.0, 0.0], "CT player should spawn from descriptor position", players[0]):
		return false
	if not _assert(players[1]["spawn_position"] == [-10.0, 0.0, 0.0], "T player should spawn from descriptor position", players[1]):
		return false

	var command = UserCommandRef.new()
	command.configure(1, ct_id, 1.0, 0.0, true, false, 0.5, -0.1)
	if not _assert(session.queue_command(command), "Known player command should be accepted", command.to_dictionary()):
		return false

	var rejected_command = UserCommandRef.new()
	rejected_command.configure(1, 999, 1.0, 0.0)
	if not _assert(not session.queue_command(rejected_command), "Unknown player command should be rejected", rejected_command.to_dictionary()):
		return false

	var steps: int = session.step(0.015)
	if not _assert(steps == 1, "Session should advance exactly one fixed tick for 0.015s at 100 Hz", {"steps": steps}):
		return false

	var tick_snapshot = session.snapshot()
	var tick_report: Dictionary = tick_snapshot.to_dictionary()
	if not _assert(tick_report["tick"] == 1, "Session should advance to tick 1", tick_report):
		return false
	if not _assert(tick_report["round_state"]["phase_tick"] == 1, "Round phase tick should advance with server tick", tick_report):
		return false
	if not _assert(tick_report["applied_commands"].size() == 1, "Session should apply one queued command on tick 1", tick_report):
		return false
	if not _assert(tick_report["players"][0]["last_command_tick"] == 1, "Applied command should update player command tick", tick_report["players"][0]):
		return false
	if not _assert(tick_report["players"][0].has("movement_state"), "Player snapshot should include movement state", tick_report["players"][0]):
		return false
	if not _assert(float(tick_report["players"][0]["origin"][2]) > 0.0, "Applied movement command should advance player origin", tick_report["players"][0]):
		return false
	if not _assert(float(tick_report["players"][0]["velocity"][2]) > 0.0, "Applied movement command should update player velocity", tick_report["players"][0]):
		return false
	if not _assert(float(tick_report["players"][0]["view_yaw"]) == 0.5, "Applied movement command should update snapshot yaw", tick_report["players"][0]):
		return false

	return true


func _assert_multistep_applied_commands() -> bool:
	var session = LocalGameSessionRef.new()
	session.configure(0.01, DescriptorOnlySpawnIndex.new())
	var ct_id: int = session.add_player("ct", PlayerSlotRef.TEAM_COUNTER_TERRORIST)
	session.start_round(RoundStateRef.PHASE_FREEZE_TIME)

	var expected_ticks: Array[int] = [1, 2, 3, 4]
	for command_tick in expected_ticks:
		var command = UserCommandRef.new()
		command.configure(command_tick, ct_id, 1.0, 0.0, false, false, float(command_tick) * 0.1, 0.0)
		if not _assert(session.queue_command(command), "Known multistep command should be accepted", command.to_dictionary()):
			return false

	var steps: int = session.step(0.04)
	if not _assert(steps == 4, "Session should advance four fixed ticks for 4x fixed_delta", {"steps": steps}):
		return false

	var report: Dictionary = session.snapshot().to_dictionary()
	if not _assert(report["tick"] == 4, "Multistep session should end on tick 4", report):
		return false
	if not _assert(report["applied_commands"].size() == expected_ticks.size(), "Multistep snapshot should retain commands from all ticks", report):
		return false

	var applied_ticks: Array[int] = []
	for applied_command in report["applied_commands"]:
		applied_ticks.append(int(applied_command.get("tick", -1)))
	if not _assert(applied_ticks == expected_ticks, "Multistep snapshot should list every applied command tick", {"applied_ticks": applied_ticks}):
		return false

	return true


func _assert_far_future_commands_are_discarded() -> bool:
	var session = LocalGameSessionRef.new()
	session.configure(0.01, DescriptorOnlySpawnIndex.new())
	var ct_id: int = session.add_player("ct", PlayerSlotRef.TEAM_COUNTER_TERRORIST)
	session.start_round(RoundStateRef.PHASE_FREEZE_TIME)

	var far_tick: int = LocalGameSessionRef.FUTURE_COMMAND_RETAIN_TICKS + 2
	var command = UserCommandRef.new()
	command.configure(far_tick, ct_id, 1.0, 0.0, false, false, 0.0, 0.0)
	if not _assert(session.queue_command(command), "Far-future known player command should be accepted before pruning", command.to_dictionary()):
		return false

	var first_steps: int = session.step(0.01)
	if not _assert(first_steps == 1, "Future-drop check should advance one tick before pruning assertion", {"steps": first_steps}):
		return false

	var first_report: Dictionary = session.snapshot().to_dictionary()
	if not _assert(first_report["applied_commands"].is_empty(), "Far-future command should not apply during the pruning tick", first_report):
		return false

	var remaining_steps: int = far_tick - session.current_tick
	var catchup_steps: int = session.step(float(remaining_steps) * 0.01)
	if not _assert(catchup_steps == remaining_steps, "Future-drop catchup should reach the far command tick", {"steps": catchup_steps, "remaining_steps": remaining_steps}):
		return false

	var catchup_report: Dictionary = session.snapshot().to_dictionary()
	if not _assert(catchup_report["tick"] == far_tick, "Future-drop catchup should end on the far command tick", catchup_report):
		return false
	if not _assert(catchup_report["applied_commands"].is_empty(), "Dropped far-future command should not apply when its tick arrives", catchup_report):
		return false

	return true


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
