extends RefCounted

class_name CSMovementMath

const STOP_EPSILON := 0.01


static func apply_friction(velocity: Vector3, stop_speed: float, friction: float, delta: float) -> Vector3:
	var result := velocity
	var speed := horizontal_speed(result)
	if speed < STOP_EPSILON:
		result.x = 0.0
		result.z = 0.0
		return result

	var control: float = max(speed, stop_speed)
	var drop: float = control * friction * max(delta, 0.0)
	var new_speed: float = max(speed - drop, 0.0)
	var scale: float = new_speed / speed
	result.x *= scale
	result.z *= scale
	return result


static func accelerate(
	velocity: Vector3,
	wish_direction: Vector3,
	wish_speed: float,
	acceleration: float,
	delta: float
) -> Vector3:
	if wish_speed <= 0.0 or wish_direction == Vector3.ZERO:
		return velocity

	var result := velocity
	var current_speed: float = horizontal_velocity(result).dot(wish_direction)
	var add_speed: float = wish_speed - current_speed
	if add_speed <= 0.0:
		return result

	var accel_speed: float = min(acceleration * wish_speed * max(delta, 0.0), add_speed)
	result.x += accel_speed * wish_direction.x
	result.z += accel_speed * wish_direction.z
	return result


static func air_accelerate(
	velocity: Vector3,
	wish_direction: Vector3,
	full_wish_speed: float,
	air_max_wishspeed: float,
	acceleration: float,
	delta: float
) -> Vector3:
	if full_wish_speed <= 0.0 or wish_direction == Vector3.ZERO:
		return velocity

	var result := velocity
	var capped_wish_speed: float = min(full_wish_speed, air_max_wishspeed)
	var current_speed: float = horizontal_velocity(result).dot(wish_direction)
	var add_speed: float = capped_wish_speed - current_speed
	if add_speed <= 0.0:
		return result

	var accel_speed: float = min(acceleration * full_wish_speed * max(delta, 0.0), add_speed)
	result.x += accel_speed * wish_direction.x
	result.z += accel_speed * wish_direction.z
	return result


static func check_velocity_components(velocity: Vector3, max_velocity: float) -> Vector3:
	if max_velocity <= 0.0:
		return velocity

	return Vector3(
		_checked_velocity_component(velocity.x, max_velocity),
		_checked_velocity_component(velocity.y, max_velocity),
		_checked_velocity_component(velocity.z, max_velocity)
	)


static func wish_direction_from_axes(
	forward: float,
	side: float,
	forward_axis: Vector3,
	right_axis: Vector3
) -> Vector3:
	var wish := forward_axis * forward + right_axis * side
	wish.y = 0.0
	if wish.length_squared() <= 0.0:
		return Vector3.ZERO
	return wish.normalized()


static func wish_direction_and_speed(
	forward: float,
	side: float,
	max_wishspeed: float,
	forward_axis: Vector3 = Vector3.BACK,
	right_axis: Vector3 = Vector3.RIGHT
) -> Dictionary:
	var wish_vector := forward_axis * forward + right_axis * side
	wish_vector.y = 0.0
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


static func horizontal_velocity(velocity: Vector3) -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


static func horizontal_speed(velocity: Vector3) -> float:
	return horizontal_velocity(velocity).length()


static func _checked_velocity_component(value: float, max_velocity: float) -> float:
	if value != value:
		return 0.0
	if value > max_velocity:
		return max_velocity
	if value < -max_velocity:
		return -max_velocity
	return value
