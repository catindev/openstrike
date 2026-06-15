extends SceneTree

const MovementSettingsRef = preload("res://src/game/movement/cs_movement_settings.gd")
const MoveCommandRef = preload("res://src/game/player/player_move_command.gd")
const MoveServiceRef = preload("res://src/game/player/player_move_service.gd")
const PlayerStateRef = preload("res://src/game/player/player_state.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var settings = MovementSettingsRef.new()
	if not _run_ground_acceleration(settings):
		return 1
	if not _run_air_strafe_gain(settings):
		return 1
	if not _run_jump_and_duck_metadata(settings):
		return 1
	if not _run_no_contact_solver_guard():
		return 1

	print("PlayerMoveService smoke passed.")
	return 0


func _run_ground_acceleration(settings) -> bool:
	var service = MoveServiceRef.new(settings)
	var state = PlayerStateRef.new()
	var command = MoveCommandRef.new()
	command.configure(1.0, 0.0, false, false, 0.0, 0.0, settings.fixed_delta())
	var peak_speed := 0.0

	for frame in range(200):
		var result = service.move(state, command)
		state = result.state
		peak_speed = max(peak_speed, _horizontal_speed(state.velocity))

	return (
		_assert(_horizontal_speed(state.velocity) >= settings.max_speed - 0.01, "PlayerMoveService ground acceleration should reach sv_maxspeed", state.to_dictionary())
		and _assert(peak_speed <= settings.max_speed + 0.01, "PlayerMoveService ground acceleration should not exceed sv_maxspeed", {"peak_speed": peak_speed, "state": state.to_dictionary()})
		and _assert(str(state.last_trace_summary.get("mode", "")) == MoveServiceRef.TRACE_MODE_FREE_VOLUME, "PlayerMoveService should report free-volume mode", state.last_trace_summary)
		and _assert(not bool(state.last_trace_summary.get("contact_movement", true)), "PlayerMoveService PR-08F should not report contact movement", state.last_trace_summary)
	)


func _run_air_strafe_gain(settings) -> bool:
	var service = MoveServiceRef.new(settings)
	var state = PlayerStateRef.new()
	state.configure(Vector3(0.0, 4096.0, 0.0), Vector3(0.0, 0.0, settings.max_speed), 0.0, 0.0, false, false)
	var delta: float = settings.fixed_delta()

	for frame in range(100):
		var horizontal := Vector3(state.velocity.x, 0.0, state.velocity.z)
		var perpendicular := Vector3(horizontal.z, 0.0, -horizontal.x).normalized()
		var command = MoveCommandRef.new()
		command.configure(perpendicular.z, perpendicular.x, false, false, 0.0, 0.0, delta)
		var result = service.move(state, command)
		state = result.state

	var expected_speed := sqrt(pow(settings.max_speed, 2.0) + pow(settings.air_max_wishspeed, 2.0) * 100.0)
	return (
		_assert(not state.on_ground, "PlayerMoveService air-strafe smoke should remain airborne", state.to_dictionary())
		and _assert(_horizontal_speed(state.velocity) >= expected_speed - 0.01, "PlayerMoveService air-strafe lower bound should match existing movement smoke", {"expected_speed": expected_speed, "state": state.to_dictionary()})
		and _assert(_horizontal_speed(state.velocity) <= expected_speed + 0.01, "PlayerMoveService air-strafe upper bound should match existing movement smoke", {"expected_speed": expected_speed, "state": state.to_dictionary()})
	)


func _run_jump_and_duck_metadata(settings) -> bool:
	var service = MoveServiceRef.new(settings)
	var state = PlayerStateRef.new()
	var jump_command = MoveCommandRef.new()
	jump_command.configure(1.0, 0.0, true, false, 0.25, -0.1, settings.fixed_delta())
	var jump_result = service.move(state, jump_command)
	var jumped_state = jump_result.state
	if not (
		_assert(not jumped_state.on_ground, "PlayerMoveService jump should leave ground", jumped_state.to_dictionary())
		and _assert(jumped_state.velocity.y > 0.0, "PlayerMoveService jump should apply upward velocity", jumped_state.to_dictionary())
		and _assert(jumped_state.view_yaw == 0.25, "PlayerMoveService should preserve command yaw in state", jumped_state.to_dictionary())
	):
		return false

	var duck_state = PlayerStateRef.new()
	var duck_command = MoveCommandRef.new()
	duck_command.configure(0.0, 0.0, false, true, 0.0, 0.0, settings.fixed_delta())
	var duck_result = service.move(duck_state, duck_command)
	var result_state = duck_result.state
	return (
		_assert(result_state.ducked, "PlayerMoveService should apply duck intent", result_state.to_dictionary())
		and _assert(str(result_state.last_trace_summary.get("hull", {}).get("kind", "")) == "duck", "PlayerMoveService should report duck hull metadata", result_state.last_trace_summary)
		and _assert(float(result_state.last_trace_summary.get("hull", {}).get("height", 0.0)) == settings.duck_height, "PlayerMoveService should report duck hull height metadata", result_state.last_trace_summary)
	)


func _run_no_contact_solver_guard() -> bool:
	var file := FileAccess.open("res://src/game/player/player_move_service.gd", FileAccess.READ)
	if not _assert(file != null, "PlayerMoveService source should be readable", {}):
		return false
	var source := file.get_as_text()
	return (
		_assert(not source.contains("move_and_slide"), "PlayerMoveService must not use Godot move_and_slide", {})
		and _assert(not source.contains("CharacterBody3D"), "PlayerMoveService must not depend on CharacterBody3D", {})
	)


func _horizontal_speed(velocity: Vector3) -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length()


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
