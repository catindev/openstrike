extends RefCounted

class_name CSMovementSimulator

const SettingsRef = preload("res://src/game/movement/cs_movement_settings.gd")
const MovementMathRef = preload("res://src/game/movement/cs_movement_math.gd")

var settings


func _init(custom_settings = null) -> void:
	settings = custom_settings if custom_settings != null else SettingsRef.new()


func step(state, input, delta: float, telemetry = null) -> void:
	var frame_delta: float = max(delta, 0.0)
	_check_velocity(state)
	_apply_duck(state, input.duck)

	if state.on_ground:
		state.position.y = max(state.position.y, state.ground_height)
		state.velocity.y = 0.0
		state.velocity = MovementMathRef.apply_friction(
			state.velocity,
			settings.stop_speed,
			settings.friction,
			frame_delta
		)
		var ground_wish := MovementMathRef.wish_direction_and_speed(
			input.forward_move,
			input.side_move,
			settings.max_speed
		)
		state.velocity = MovementMathRef.accelerate(
			state.velocity,
			ground_wish["direction"],
			float(ground_wish["speed"]),
			settings.ground_accelerate,
			frame_delta
		)

		if input.jump:
			state.velocity.y = settings.jump_velocity
			state.on_ground = false
		_check_velocity(state)

	if not state.on_ground:
		var air_wish := MovementMathRef.wish_direction_and_speed(
			input.forward_move,
			input.side_move,
			settings.max_speed
		)
		state.velocity = MovementMathRef.air_accelerate(
			state.velocity,
			air_wish["direction"],
			float(air_wish["speed"]),
			settings.air_max_wishspeed,
			settings.air_accelerate,
			frame_delta
		)
		_apply_half_gravity(state, frame_delta)
		_check_velocity(state)

	state.position += state.velocity * frame_delta
	_resolve_ground(state)
	_check_velocity(state)

	if not state.on_ground:
		_apply_half_gravity(state, frame_delta)
		_check_velocity(state)

	if telemetry != null:
		telemetry.record(frame_delta, state, input, settings)


func try_step_up(state, step_height: float) -> bool:
	if not state.on_ground:
		return false
	if step_height < 0.0 or step_height > settings.step_size:
		return false

	state.ground_height += step_height
	state.position.y = state.ground_height
	state.velocity.y = 0.0
	state.on_ground = true
	return true


func _apply_duck(state, wants_duck: bool) -> void:
	state.ducked = wants_duck
	state.body_height = settings.duck_height if state.ducked else settings.stand_height


func _apply_half_gravity(state, delta: float) -> void:
	state.velocity.y -= settings.gravity * delta * 0.5


func _check_velocity(state) -> void:
	var max_velocity: float = max(settings.max_velocity, 0.0)
	state.velocity = MovementMathRef.check_velocity_components(state.velocity, max_velocity)


func _resolve_ground(state) -> void:
	if state.position.y <= state.ground_height:
		state.position.y = state.ground_height
		if state.velocity.y < 0.0:
			state.velocity.y = 0.0
		state.on_ground = true
	else:
		state.on_ground = false
