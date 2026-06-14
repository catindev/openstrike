extends SceneTree

const ConfigLoaderRef = preload("res://src/core/config/config_loader.gd")
const MovementInputRef = preload("res://src/game/movement/cs_movement_input.gd")
const MovementSettingsRef = preload("res://src/game/movement/cs_movement_settings.gd")
const MovementSimulatorRef = preload("res://src/game/movement/cs_movement_simulator.gd")
const MovementStateRef = preload("res://src/game/movement/cs_movement_state.gd")
const MovementTelemetryRef = preload("res://src/game/movement/cs_movement_telemetry.gd")


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var cvars = ConfigLoaderRef.load_default_cvars()
	var settings = MovementSettingsRef.new()
	settings.apply_cvars(cvars)

	if not _assert(settings.max_speed == 320.0, "movement settings should read sv_maxspeed", settings.to_dictionary()):
		return 1
	if not _assert(settings.sim_tick_hz == 100.0, "movement settings should read 100 Hz simulation tick", settings.to_dictionary()):
		return 1
	if not _assert(settings.ground_accelerate == 5.0, "movement settings should use CS16 sv_accelerate", settings.to_dictionary()):
		return 1
	if not _assert(settings.stop_speed == 75.0, "movement settings should use CS16 sv_stopspeed", settings.to_dictionary()):
		return 1
	if not _assert(settings.air_max_wishspeed == 30.0, "movement settings should read air wishspeed cap", settings.to_dictionary()):
		return 1

	if not _run_ground_acceleration(settings):
		return 1
	if not _run_ground_maxvelocity_input(settings):
		return 1
	if not _run_fastrun_transient(settings):
		return 1
	if not _run_friction(settings):
		return 1
	if not _run_air_cap(settings):
		return 1
	if not _run_air_strafe_gain(settings):
		return 1
	if not _run_air_strafe_maxvelocity(settings):
		return 1
	if not _run_jump_frame_order(settings):
		return 1
	if not _run_jump_and_gravity(settings):
		return 1
	if not _run_duck_and_step(settings):
		return 1

	print("Movement smoke passed.")
	return 0


func _run_ground_acceleration(settings) -> bool:
	var simulator = MovementSimulatorRef.new(settings)
	var state = MovementStateRef.new()
	var input = MovementInputRef.new(1.0, 0.0, false, false)
	var telemetry = MovementTelemetryRef.new()
	var delta: float = settings.fixed_delta()

	for frame in range(200):
		simulator.step(state, input, delta, telemetry)

	return (
		_assert(state.horizontal_speed() >= settings.max_speed - 0.01, "ground acceleration should reach sv_maxspeed", state.snapshot())
		and _assert(telemetry.max_horizontal_speed() <= settings.max_speed + 0.01, "ground speed should not exceed sv_maxspeed", telemetry.last_frame())
	)


func _run_ground_maxvelocity_input(settings) -> bool:
	var simulator = MovementSimulatorRef.new(settings)
	var state = MovementStateRef.new()
	state.velocity = Vector3(settings.max_velocity * 2.0, 0.0, 0.0)
	var input = MovementInputRef.new()
	var delta: float = settings.fixed_delta()

	simulator.step(state, input, delta)

	var clamped_start_speed: float = settings.max_velocity
	var friction_drop: float = max(clamped_start_speed, settings.stop_speed) * settings.friction * delta
	var expected_velocity_x: float = max(clamped_start_speed - friction_drop, 0.0)
	var expected_position_x: float = expected_velocity_x * delta
	return (
		_assert(abs(state.velocity.x - expected_velocity_x) <= 0.01, "ground maxvelocity should clamp before friction", {"expected_velocity_x": expected_velocity_x, "state": state.snapshot()})
		and _assert(abs(state.position.x - expected_position_x) <= 0.01, "ground maxvelocity should clamp before position integration", {"expected_position_x": expected_position_x, "state": state.snapshot()})
	)


func _run_fastrun_transient(settings) -> bool:
	var fastrun_settings = MovementSettingsRef.new()
	fastrun_settings.sim_tick_hz = settings.sim_tick_hz
	fastrun_settings.ground_accelerate = settings.ground_accelerate
	fastrun_settings.friction = settings.friction
	fastrun_settings.stop_speed = settings.stop_speed
	fastrun_settings.max_speed = 250.0

	var simulator = MovementSimulatorRef.new(fastrun_settings)
	var state = MovementStateRef.new()
	state.velocity = Vector3(0.0, 0.0, fastrun_settings.max_speed)
	var telemetry = MovementTelemetryRef.new()
	var delta: float = fastrun_settings.fixed_delta()

	var first_left_press = _movement_from_button_states(
		MovementInputRef.BUTTON_HELD,
		MovementInputRef.BUTTON_RELEASED,
		MovementInputRef.BUTTON_RELEASED,
		MovementInputRef.BUTTON_JUST_PRESSED
	)
	simulator.step(state, first_left_press, delta, telemetry)
	var first_speed := state.horizontal_speed()

	var held_diagonal = _movement_from_button_states(
		MovementInputRef.BUTTON_HELD,
		MovementInputRef.BUTTON_RELEASED,
		MovementInputRef.BUTTON_RELEASED,
		MovementInputRef.BUTTON_HELD
	)
	for frame in range(80):
		simulator.step(state, held_diagonal, delta, telemetry)

	var peak_speed := telemetry.max_horizontal_speed()
	return (
		_assert(abs(first_speed - 251.24) <= 0.02, "W+A half-state fastrun frame should match CS16 reference speed", {"first_speed": first_speed, "telemetry": telemetry.frames[0]})
		and _assert(peak_speed >= 261.0, "held diagonal fastrun should produce a transient speed gain", {"peak_speed": peak_speed, "last": telemetry.last_frame()})
		and _assert(peak_speed <= 264.0, "held diagonal fastrun should stay in CS16 reference range", {"peak_speed": peak_speed, "last": telemetry.last_frame()})
	)


func _movement_from_button_states(
	forward_state: float,
	back_state: float,
	right_state: float,
	left_state: float,
	wants_jump: bool = false,
	wants_duck: bool = false
):
	return MovementInputRef.new(
		MovementInputRef.button_axis(forward_state, back_state),
		MovementInputRef.button_axis(right_state, left_state),
		wants_jump,
		wants_duck
	)


func _run_friction(settings) -> bool:
	var simulator = MovementSimulatorRef.new(settings)
	var state = MovementStateRef.new()
	state.velocity = Vector3(settings.max_speed, 0.0, 0.0)
	var input = MovementInputRef.new()
	var delta: float = settings.fixed_delta()

	for frame in range(120):
		simulator.step(state, input, delta)

	return _assert(state.horizontal_speed() <= 0.01, "ground friction should stop a released player", state.snapshot())


func _run_air_cap(settings) -> bool:
	var simulator = MovementSimulatorRef.new(settings)
	var state = MovementStateRef.new()
	state.position.y = 4096.0
	state.on_ground = false
	var input = MovementInputRef.new(1.0, 0.0, false, false)

	simulator.step(state, input, 0.1)

	return _assert(state.horizontal_speed() <= settings.air_max_wishspeed + 0.01, "air acceleration should respect wishspeed cap", state.snapshot())


func _run_air_strafe_gain(settings) -> bool:
	var simulator = MovementSimulatorRef.new(settings)
	var state = MovementStateRef.new()
	state.position.y = 4096.0
	state.velocity = Vector3(0.0, 0.0, settings.max_speed)
	state.on_ground = false
	var telemetry = MovementTelemetryRef.new()
	var delta: float = settings.fixed_delta()

	for frame in range(100):
		var horizontal := state.horizontal_velocity()
		var perpendicular := Vector3(horizontal.z, 0.0, -horizontal.x).normalized()
		var strafe_input = MovementInputRef.new(perpendicular.z, perpendicular.x, false, false)
		simulator.step(state, strafe_input, delta, telemetry)

	var expected_speed := sqrt(pow(settings.max_speed, 2.0) + pow(settings.air_max_wishspeed, 2.0) * 100.0)
	return (
		_assert(not state.on_ground, "air strafe smoke should remain airborne", state.snapshot())
		and _assert(state.horizontal_speed() >= settings.max_speed + 100.0, "air strafe should gain meaningful horizontal speed over one second", state.snapshot())
		and _assert(state.horizontal_speed() >= expected_speed - 0.01, "air strafe should match independently calculated gain lower bound", {"expected_speed": expected_speed, "state": state.snapshot(), "telemetry": telemetry.last_frame()})
		and _assert(state.horizontal_speed() <= expected_speed + 0.01, "air strafe should match independently calculated gain upper bound", {"expected_speed": expected_speed, "state": state.snapshot(), "telemetry": telemetry.last_frame()})
	)


func _run_air_strafe_maxvelocity(settings) -> bool:
	var simulator = MovementSimulatorRef.new(settings)
	var state = MovementStateRef.new()
	state.position.y = 1000000.0
	state.velocity = Vector3(0.0, 0.0, settings.max_speed)
	state.on_ground = false
	var telemetry = MovementTelemetryRef.new()
	var delta: float = settings.fixed_delta()
	var frame_count := 10000

	for frame in range(frame_count):
		var horizontal := state.horizontal_velocity()
		var perpendicular := Vector3(horizontal.z, 0.0, -horizontal.x).normalized()
		var strafe_input = MovementInputRef.new(perpendicular.z, perpendicular.x, false, false)
		simulator.step(state, strafe_input, delta, telemetry)

	var expected_velocity := _expected_perpendicular_air_strafe_velocity(settings, Vector3(0.0, 0.0, settings.max_speed), frame_count, delta)
	var expected_speed := Vector3(expected_velocity.x, 0.0, expected_velocity.z).length()
	var unlimited_speed := sqrt(pow(settings.max_speed, 2.0) + pow(settings.air_max_wishspeed, 2.0) * float(frame_count))
	return (
		_assert(not state.on_ground, "long-run air strafe smoke should remain airborne", state.snapshot())
		and _assert(abs(state.velocity.x) <= settings.max_velocity + 0.01, "sv_maxvelocity should clamp velocity.x component-wise", state.snapshot())
		and _assert(abs(state.velocity.y) <= settings.max_velocity + 0.01, "sv_maxvelocity should clamp velocity.y component-wise", state.snapshot())
		and _assert(abs(state.velocity.z) <= settings.max_velocity + 0.01, "sv_maxvelocity should clamp velocity.z component-wise", state.snapshot())
		and _assert(state.horizontal_speed() <= unlimited_speed - 10.0, "long-run air strafe should not preserve the old unlimited speed model", {"unlimited_speed": unlimited_speed, "state": state.snapshot()})
		and _assert(state.horizontal_speed() >= expected_speed - 0.05, "long-run air strafe should match component-wise maxvelocity lower bound", {"expected_speed": expected_speed, "state": state.snapshot(), "telemetry": telemetry.last_frame()})
		and _assert(state.horizontal_speed() <= expected_speed + 0.05, "long-run air strafe should match component-wise maxvelocity upper bound", {"expected_speed": expected_speed, "state": state.snapshot(), "telemetry": telemetry.last_frame()})
	)


func _expected_perpendicular_air_strafe_velocity(settings, start_velocity: Vector3, frame_count: int, delta: float) -> Vector3:
	var velocity := start_velocity
	for frame in range(frame_count):
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		var wish_direction := Vector3.ZERO
		if horizontal != Vector3.ZERO:
			wish_direction = Vector3(horizontal.z, 0.0, -horizontal.x).normalized()

		if wish_direction != Vector3.ZERO:
			var full_wish_speed: float = settings.max_speed
			var capped_wish_speed: float = min(full_wish_speed, settings.air_max_wishspeed)
			var current_speed: float = horizontal.dot(wish_direction)
			var add_speed: float = capped_wish_speed - current_speed
			if add_speed > 0.0:
				var accel_speed: float = min(settings.air_accelerate * full_wish_speed * delta, add_speed)
				velocity.x += accel_speed * wish_direction.x
				velocity.z += accel_speed * wish_direction.z

		velocity = _expected_component_wise_maxvelocity(velocity, settings.max_velocity)
	return velocity


func _expected_component_wise_maxvelocity(velocity: Vector3, max_velocity: float) -> Vector3:
	var limit: float = max(max_velocity, 0.0)
	if limit <= 0.0:
		return velocity
	return Vector3(
		_expected_checked_velocity_component(velocity.x, limit),
		_expected_checked_velocity_component(velocity.y, limit),
		_expected_checked_velocity_component(velocity.z, limit)
	)


func _expected_checked_velocity_component(value: float, limit: float) -> float:
	if value != value:
		return 0.0
	if value > limit:
		return limit
	if value < -limit:
		return -limit
	return value


func _run_jump_frame_order(settings) -> bool:
	var simulator = MovementSimulatorRef.new(settings)
	var state = MovementStateRef.new()
	var jump_forward = MovementInputRef.new(1.0, 0.0, true, false)

	simulator.step(state, jump_forward, settings.fixed_delta())

	return (
		_assert(not state.on_ground, "jump frame should leave ground after ground acceleration", state.snapshot())
		and _assert(state.horizontal_speed() > 0.0, "jump frame should preserve ground acceleration before takeoff", state.snapshot())
	)


func _run_jump_and_gravity(settings) -> bool:
	var simulator = MovementSimulatorRef.new(settings)
	var state = MovementStateRef.new()
	var jump_input = MovementInputRef.new(0.0, 0.0, true, false)
	var empty_input = MovementInputRef.new()
	var delta: float = settings.fixed_delta()

	simulator.step(state, jump_input, delta)
	if not _assert(not state.on_ground, "jump should leave ground", state.snapshot()):
		return false
	if not _assert(state.velocity.y > 0.0, "jump should apply upward velocity", state.snapshot()):
		return false

	for frame in range(200):
		simulator.step(state, empty_input, delta)

	return (
		_assert(state.on_ground, "gravity should return player to ground", state.snapshot())
		and _assert(state.position.y == state.ground_height, "ground resolution should clamp to ground height", state.snapshot())
	)


func _run_duck_and_step(settings) -> bool:
	var simulator = MovementSimulatorRef.new(settings)
	var state = MovementStateRef.new()
	var delta: float = settings.fixed_delta()

	simulator.step(state, MovementInputRef.new(0.0, 0.0, false, true), delta)
	if not _assert(state.ducked, "duck input should set ducked state", state.snapshot()):
		return false
	if not _assert(state.body_height == settings.duck_height, "duck should use duck hull height", state.snapshot()):
		return false

	simulator.step(state, MovementInputRef.new(), delta)
	if not _assert(not state.ducked, "released duck should restore standing state", state.snapshot()):
		return false
	if not _assert(state.body_height == settings.stand_height, "standing should use standing hull height", state.snapshot()):
		return false

	if not _assert(simulator.try_step_up(state, settings.step_size), "step equal to sv_stepsize should be accepted", state.snapshot()):
		return false
	if not _assert(state.position.y == settings.step_size, "accepted step should raise ground height", state.snapshot()):
		return false
	if not _assert(not simulator.try_step_up(state, settings.step_size + 0.1), "step above sv_stepsize should be rejected", state.snapshot()):
		return false

	state.on_ground = false
	return _assert(not simulator.try_step_up(state, 1.0), "airborne player should not step up", state.snapshot())


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
