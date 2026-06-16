extends SceneTree

const LocalGameSessionRef = preload("res://src/game/runtime/openstrike_local_game_session.gd")
const PlayerSlotRef = preload("res://src/game/runtime/openstrike_player_slot.gd")
const RoundStateRef = preload("res://src/game/runtime/openstrike_round_state.gd")
const UserCommandRef = preload("res://src/game/runtime/openstrike_user_command.gd")


class SingleSpawnIndex:
	func spawn_descriptors_for_classes(_preferred_classes: Array[String]) -> Array[Dictionary]:
		return [{
			"classname": "info_player_counterterrorist",
			"position": Vector3.ZERO,
			"yaw": 0.0,
			"origin": "0 0 0",
			"angles": "0 0 0",
			"source": "view_relative_smoke",
		}]


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	if not _assert_movement_axis(0.0, 1.0, 0.0, Vector3.BACK, "yaw=0 forward should move along +Z"):
		return 1
	if not _assert_movement_axis(PI / 2.0, 1.0, 0.0, Vector3.RIGHT, "yaw=90 forward should move along +X"):
		return 1
	if not _assert_movement_axis(PI / 2.0, 0.0, 1.0, Vector3.FORWARD, "yaw=90 side should move along -Z"):
		return 1

	print("Local game session view-relative smoke passed.")
	return 0


func _assert_movement_axis(yaw: float, forward: float, side: float, expected_axis: Vector3, message: String) -> bool:
	var session = LocalGameSessionRef.new()
	session.configure(0.01, SingleSpawnIndex.new())
	var player_id: int = session.add_player("ct", PlayerSlotRef.TEAM_COUNTER_TERRORIST)
	session.start_round(RoundStateRef.PHASE_FREEZE_TIME)

	var command = UserCommandRef.new()
	command.configure(1, player_id, forward, side, false, false, yaw, 0.0)
	if not _assert(session.queue_command(command), "View-relative command should be accepted", command.to_dictionary()):
		return false

	session.step(0.01)
	var report: Dictionary = session.snapshot().to_dictionary()
	var player: Dictionary = report["players"][0]
	var velocity := _vector_from_value(player.get("velocity", []))
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if not _assert(horizontal.length() > 0.0, "%s should produce horizontal velocity" % message, player):
		return false
	var direction := horizontal.normalized()
	return _assert(
		direction.dot(expected_axis.normalized()) > 0.999,
		message,
		{
			"direction": _vector_to_array(direction),
			"expected_axis": _vector_to_array(expected_axis.normalized()),
			"player": player,
		}
	)


func _vector_from_value(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
