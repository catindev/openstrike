extends SceneTree

const GodotSceneBackendRef = preload("res://src/core/collision/godot_scene_trace_backend.gd")
const MovementSettingsRef = preload("res://src/game/movement/cs_movement_settings.gd")
const MoveCommandRef = preload("res://src/game/player/player_move_command.gd")
const MoveServiceRef = preload("res://src/game/player/player_move_service.gd")
const PlayerStateRef = preload("res://src/game/player/player_state.gd")
const SelectorRef = preload("res://src/dev/smoke/trace_backend_dev_selector.gd")
const TraceBackendRef = preload("res://src/core/collision/openstrike_trace_backend.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var settings = MovementSettingsRef.new()
	if not _run_synthetic_wall_stops_player(settings):
		return 1
	if not _run_synthetic_open_space_moves_freely(settings):
		return 1
	if not _run_godot_backend_stays_telemetry_only(settings):
		return 1

	print("PlayerMoveService contact smoke passed.")
	return 0


func _run_synthetic_wall_stops_player(settings) -> bool:
	var service = MoveServiceRef.new(settings, _synthetic_backend())
	var state = PlayerStateRef.new()
	state.configure(Vector3(32.0, 0.0, 0.0), Vector3(-2000.0, 0.0, 0.0), 0.0, 0.0, false, true)
	var command = _command(settings.fixed_delta())
	var result = service.move(state, command)
	var next_state = result.state
	var summary: Dictionary = result.trace_summary
	var contact: Dictionary = summary.get("contact", {})
	var contacts: Array = contact.get("contacts", [])
	var first_contact: Dictionary = contacts[0] if not contacts.is_empty() else {}
	return (
		_assert(str(summary.get("mode", "")) == MoveServiceRef.TRACE_MODE_SYNTHETIC_CONTACT, "Synthetic backend should enable contact movement mode", result.to_dictionary())
		and _assert(bool(summary.get("contact_movement", false)), "Synthetic backend should report contact movement", result.to_dictionary())
		and _assert(bool(summary.get("trace_backend_used", false)), "Synthetic backend should report trace backend use", result.to_dictionary())
		and _assert(abs(next_state.origin.x - 16.0) <= 0.001, "Standing hull should stop at synthetic wall contact x=16", result.to_dictionary())
		and _assert(abs(next_state.velocity.x) <= 0.001, "Wall contact should remove into-plane velocity", result.to_dictionary())
		and _assert(bool(contact.get("blocked", false)), "Wall contact should be reported as blocked", result.to_dictionary())
		and _assert(int(contact.get("iterations", 0)) == 1, "Single-plane wall should resolve in one trace iteration", result.to_dictionary())
		and _assert(contacts.size() == 1, "Wall contact should record one contact", result.to_dictionary())
		and _assert(_vec3_close(first_contact.get("normal", []), [1.0, 0.0, 0.0]), "Wall contact should keep BSP plane normal", result.to_dictionary())
	)


func _run_synthetic_open_space_moves_freely(settings) -> bool:
	var service = MoveServiceRef.new(settings, _synthetic_backend())
	var state = PlayerStateRef.new()
	state.configure(Vector3(32.0, 0.0, 0.0), Vector3(100.0, 0.0, 0.0), 0.0, 0.0, false, true)
	var command = _command(settings.fixed_delta())
	var result = service.move(state, command)
	var next_state = result.state
	var contact: Dictionary = result.trace_summary.get("contact", {})
	return (
		_assert(str(result.trace_summary.get("mode", "")) == MoveServiceRef.TRACE_MODE_SYNTHETIC_CONTACT, "Synthetic open-space movement should still use contact mode", result.to_dictionary())
		and _assert(bool(result.trace_summary.get("trace_backend_used", false)), "Synthetic open-space movement should trace once", result.to_dictionary())
		and _assert(next_state.origin.x > 32.0, "Open-space movement should advance freely", result.to_dictionary())
		and _assert(not bool(contact.get("blocked", true)), "Open-space movement should stay unblocked", result.to_dictionary())
		and _assert(int(contact.get("iterations", 0)) == 1, "Open-space movement should stop after clear trace", result.to_dictionary())
		and _assert((contact.get("contacts", []) as Array).is_empty(), "Open-space movement should record no contacts", result.to_dictionary())
	)


func _run_godot_backend_stays_telemetry_only(settings) -> bool:
	var godot_backend = GodotSceneBackendRef.new()
	var service = MoveServiceRef.new(settings, godot_backend)
	var state = PlayerStateRef.new()
	state.configure(Vector3(32.0, 0.0, 0.0), Vector3(-2000.0, 0.0, 0.0), 0.0, 0.0, false, true)
	var result = service.move(state, _command(settings.fixed_delta()))
	var capabilities: Dictionary = result.trace_summary.get("trace_backend_capabilities", {})
	return (
		_assert(str(result.trace_summary.get("mode", "")) == MoveServiceRef.TRACE_MODE_FREE_VOLUME, "Godot backend should not enable contact movement", result.to_dictionary())
		and _assert(not bool(result.trace_summary.get("contact_movement", true)), "Godot backend contact remains telemetry-only", result.to_dictionary())
		and _assert(not bool(result.trace_summary.get("trace_backend_used", true)), "Godot backend should not be used for PlayerMoveService contact goldens", result.to_dictionary())
		and _assert(result.state.origin.x < 16.0, "Without synthetic contact, free-volume movement should pass the synthetic wall plane", result.to_dictionary())
		and _assert(str(capabilities.get("source", "")) == TraceBackendRef.SOURCE_GODOT_SCENE, "Godot backend capabilities should still be reported as metadata", result.to_dictionary())
	)


func _synthetic_backend():
	var selector = SelectorRef.new()
	return selector.select_backend(SelectorRef.BACKEND_SYNTHETIC_BSP_CLIPNODE)


func _command(delta: float):
	var command = MoveCommandRef.new()
	command.configure(0.0, 0.0, false, false, 0.0, 0.0, delta)
	return command


func _vec3_close(value, expected: Array, epsilon: float = 0.001) -> bool:
	var actual: Array = value
	if actual.size() != 3 or expected.size() != 3:
		return false
	return (
		abs(float(actual[0]) - float(expected[0])) <= epsilon
		and abs(float(actual[1]) - float(expected[1])) <= epsilon
		and abs(float(actual[2]) - float(expected[2])) <= epsilon
	)


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
