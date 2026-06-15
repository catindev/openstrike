extends SceneTree

const MoveCommandRef = preload("res://src/game/player/player_move_command.gd")
const MoveResultRef = preload("res://src/game/player/player_move_result.gd")
const PlayerStateRef = preload("res://src/game/player/player_state.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	if not _run_state_defaults_and_roundtrip():
		return 1
	if not _run_command_defaults_and_roundtrip():
		return 1
	if not _run_result_roundtrip():
		return 1
	if not _run_no_character_body_guard():
		return 1

	print("Player move types smoke passed.")
	return 0


func _run_state_defaults_and_roundtrip() -> bool:
	var state = PlayerStateRef.new()
	var defaults: Dictionary = state.to_dictionary()
	if not (
		_assert(defaults.get("origin", []) == [0.0, 0.0, 0.0], "Player state origin should default to zero", defaults)
		and _assert(defaults.get("velocity", []) == [0.0, 0.0, 0.0], "Player state velocity should default to zero", defaults)
		and _assert(bool(defaults.get("on_ground", false)), "Player state should default to on_ground for a resting player", defaults)
		and _assert(not bool(defaults.get("ducked", true)), "Player state should default to standing", defaults)
		and _assert(int(defaults.get("flags", -1)) == PlayerStateRef.FLAG_NONE, "Player state flags should default to none", defaults)
	):
		return false

	state.configure(
		Vector3(10.0, 20.0, 30.0),
		Vector3(1.0, 2.0, 3.0),
		1.5,
		-0.25,
		true,
		false,
		7,
		{"hit": true, "fraction": 0.25, "contents_code": -2}
	)
	var report: Dictionary = state.to_dictionary()
	var roundtrip = PlayerStateRef.new()
	roundtrip.configure_from_dictionary(report)
	return _assert(roundtrip.to_dictionary() == report, "Player state should roundtrip through dictionary serialization", {
		"report": report,
		"roundtrip": roundtrip.to_dictionary(),
	})


func _run_command_defaults_and_roundtrip() -> bool:
	var command = MoveCommandRef.new()
	var defaults: Dictionary = command.to_dictionary()
	if not (
		_assert(float(defaults.get("forward_move", 1.0)) == 0.0, "Move command forward_move should default to zero", defaults)
		and _assert(float(defaults.get("side_move", 1.0)) == 0.0, "Move command side_move should default to zero", defaults)
		and _assert(float(defaults.get("frametime", 0.0)) == 0.01, "Move command frametime should default to 100 Hz", defaults)
	):
		return false

	command.configure(400.0, -50.0, true, true, 0.75, -0.125, 0.01)
	var report: Dictionary = command.to_dictionary()
	var roundtrip = MoveCommandRef.new()
	roundtrip.configure_from_dictionary(report)
	return _assert(roundtrip.to_dictionary() == report, "Move command should roundtrip through dictionary serialization", {
		"report": report,
		"roundtrip": roundtrip.to_dictionary(),
	})


func _run_result_roundtrip() -> bool:
	var state = PlayerStateRef.new()
	state.configure(Vector3(4.0, 5.0, 6.0), Vector3(7.0, 8.0, 9.0), 0.5, -0.2, false, true, 3, {"status": "clear"})

	var command = MoveCommandRef.new()
	command.configure(250.0, 0.0, false, false, 0.5, -0.2, 0.01)

	var result = MoveResultRef.new()
	result.configure(state, command, {"contacts": [], "backend": "synthetic"}, true)
	result.add_diagnostic("warning", "synthetic_notice", "Synthetic result fixture.", {"scope": "smoke"})

	var report: Dictionary = result.to_dictionary()
	var roundtrip = MoveResultRef.new()
	roundtrip.configure_from_dictionary(report)
	return _assert(roundtrip.to_dictionary() == report, "Move result should roundtrip nested state, command and trace summary", {
		"report": report,
		"roundtrip": roundtrip.to_dictionary(),
	})


func _run_no_character_body_guard() -> bool:
	for path in [
		"res://src/game/player/player_state.gd",
		"res://src/game/player/player_move_command.gd",
		"res://src/game/player/player_move_result.gd",
	]:
		var file := FileAccess.open(path, FileAccess.READ)
		if not _assert(file != null, "Player move type source should be readable", {"path": path}):
			return false
		var source := file.get_as_text()
		if not _assert(not source.contains("CharacterBody3D"), "Player move types must not depend on Godot CharacterBody3D", {"path": path}):
			return false
	return true


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
