extends RefCounted

class_name CSMovementSimulator

const SettingsRef = preload("res://src/game/movement/cs_movement_settings.gd")

const STOP_EPSILON := 0.01

var settings


func _init(custom_settings = null) -> void:
	settings = custom_settings if custom_settings != null else SettingsRef.new()


func step(state, input, delta: float, telemetry = null) -> void:
	var frame_delta: float = max(delta, 0.0)
	_apply_duck(state, input.duck)

	if state.on_ground:
		state.position.y = max(state.position.y, state.ground_height)
		if input.jump:
			state.velocity.y = settings.jump_velocity
			state.on_ground = false
		else:
			state.velocity.y = 0.0
			_apply_friction(state, frame_delta)
			_accelerate(state, input, settings.max_speed, settings.ground_accelerate, frame_delta)

	if not state.on_ground:
		_air_accelerate(state, input, frame_delta)
		_apply_half_gravity(state, frame_delta)

	state.position += state.velocity * frame_delta
	_resolve_ground(state)

	if not state.on_ground:
		_apply_half_gravity(state, frame_delta)

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


func _apply_friction(state, delta: float) -> void:
	var speed: float = state.horizontal_speed()
	if speed < STOP_EPSILON:
		state.velocity.x = 0.0
		state.velocity.z = 0.0
		return

	var control: float = max(speed, settings.stop_speed)
	var drop: float = control * settings.friction * delta
	var new_speed: float = max(speed - drop, 0.0)
	var scale: float = new_speed / speed
	state.velocity.x *= scale
	state.velocity.z *= scale


func _air_accelerate(state, input, delta: float) -> void:
	var wish := _wish_direction_and_speed(input, settings.max_speed)
	var wish_speed: float = min(float(wish["speed"]), settings.air_max_wishspeed)
	_accelerate_along(state, wish["direction"], wish_speed, settings.air_accelerate, delta)


func _apply_half_gravity(state, delta: float) -> void:
	state.velocity.y -= settings.gravity * delta * 0.5


func _accelerate(state, input, max_wishspeed: float, acceleration: float, delta: float) -> void:
	var wish := _wish_direction_and_speed(input, max_wishspeed)
	_accelerate_along(state, wish["direction"], float(wish["speed"]), acceleration, delta)


func _accelerate_along(state, wish_direction: Vector3, wish_speed: float, acceleration: float, delta: float) -> void:
	if wish_speed <= 0.0 or wish_direction == Vector3.ZERO:
		return

	var current_speed: float = state.horizontal_velocity().dot(wish_direction)
	var add_speed: float = wish_speed - current_speed
	if add_speed <= 0.0:
		return

	var accel_speed: float = min(acceleration * wish_speed * delta, add_speed)
	state.velocity.x += accel_speed * wish_direction.x
	state.velocity.z += accel_speed * wish_direction.z


func _wish_direction_and_speed(input, max_wishspeed: float) -> Dictionary:
	var wish_vector := Vector3(input.side_move, 0.0, input.forward_move)
	var input_length: float = min(wish_vector.length(), 1.0)
	if input_length <= 0.0:
		return {
			"direction": Vector3.ZERO,
			"speed": 0.0,
		}

	return {
		"direction": wish_vector.normalized(),
		"speed": max_wishspeed * input_length,
	}


func _resolve_ground(state) -> void:
	if state.position.y <= state.ground_height:
		state.position.y = state.ground_height
		if state.velocity.y < 0.0:
			state.velocity.y = 0.0
		state.on_ground = true
	else:
		state.on_ground = false
