extends RefCounted

class_name CSMovementSettings

var sim_tick_hz := 100.0
var gravity := 800.0
var ground_accelerate := 5.0
var friction := 4.0
var stop_speed := 75.0
var step_size := 18.0
var air_accelerate := 10.0
var air_max_wishspeed := 30.0
var jump_velocity := 270.0
var max_speed := 320.0
var max_velocity := 2000.0
var edge_friction := 2.0
var stand_height := 72.0
var duck_height := 36.0


func apply_cvars(cvars) -> void:
	sim_tick_hz = cvars.get_float("movement_sim_hz", sim_tick_hz)
	gravity = cvars.get_float("sv_gravity", gravity)
	ground_accelerate = cvars.get_float("sv_accelerate", ground_accelerate)
	friction = cvars.get_float("sv_friction", friction)
	stop_speed = cvars.get_float("sv_stopspeed", stop_speed)
	step_size = cvars.get_float("sv_stepsize", step_size)
	air_accelerate = cvars.get_float("sv_airaccelerate", air_accelerate)
	air_max_wishspeed = cvars.get_float("sv_air_max_wishspeed", air_max_wishspeed)
	jump_velocity = cvars.get_float("sv_jumpvelocity", jump_velocity)
	max_speed = cvars.get_float("sv_maxspeed", max_speed)
	max_velocity = cvars.get_float("sv_maxvelocity", max_velocity)
	edge_friction = cvars.get_float("edgefriction", edge_friction)
	stand_height = cvars.get_float("sv_player_stand_height", stand_height)
	duck_height = cvars.get_float("sv_player_duck_height", duck_height)


func fixed_delta() -> float:
	return 1.0 / max(sim_tick_hz, 1.0)


func to_dictionary() -> Dictionary:
	return {
		"sim_tick_hz": sim_tick_hz,
		"fixed_delta": fixed_delta(),
		"gravity": gravity,
		"ground_accelerate": ground_accelerate,
		"friction": friction,
		"stop_speed": stop_speed,
		"step_size": step_size,
		"air_accelerate": air_accelerate,
		"air_max_wishspeed": air_max_wishspeed,
		"jump_velocity": jump_velocity,
		"max_speed": max_speed,
		"max_velocity": max_velocity,
		"edge_friction": edge_friction,
		"stand_height": stand_height,
		"duck_height": duck_height,
	}
