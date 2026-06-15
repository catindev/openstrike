extends RefCounted

class_name OpenStrikeBspWalkableTraceLogger

const LAB_ID := "bsp_walkable"

var enabled := false
var session_id := ""
var session_user_dir := ""
var trace_user_path := ""
var summary_user_path := ""
var trace_file: FileAccess = null
var summary := {}


func start(initial_summary: Dictionary, trace_enabled: bool = true) -> void:
	enabled = trace_enabled
	session_id = _make_session_id()
	session_user_dir = "user://telemetry/%s/%s" % [LAB_ID, session_id]
	trace_user_path = session_user_dir.path_join("trace.jsonl")
	summary_user_path = session_user_dir.path_join("summary.json")

	var absolute_session_dir := ProjectSettings.globalize_path(session_user_dir)
	DirAccess.make_dir_recursive_absolute(absolute_session_dir)

	summary = initial_summary.duplicate(true)
	summary["lab_id"] = LAB_ID
	summary["session_id"] = session_id
	summary["trace_path"] = trace_user_path
	summary["summary_path"] = summary_user_path
	summary["tick_count"] = 0
	summary["duration_sec"] = 0.0
	summary["max_speed_ups"] = 0.0
	summary["max_horizontal_speed_ups"] = 0.0
	summary["jump_presses"] = 0
	summary["duck_ticks"] = 0
	summary["air_ticks"] = 0
	summary["floor_ticks"] = 0
	summary["step_up_attempts"] = 0
	summary["step_up_successes"] = 0
	summary["slide_collision_count"] = 0
	summary["movement_adapter"] = "local_game_session_snapshot"

	if enabled:
		trace_file = FileAccess.open(trace_user_path, FileAccess.WRITE)

	_write_summary("started")


func record_tick(entry: Dictionary) -> void:
	if summary.is_empty():
		return

	summary["tick_count"] = int(summary.get("tick_count", 0)) + 1
	summary["duration_sec"] = float(entry.get("time_sec", summary.get("duration_sec", 0.0)))
	summary["max_speed_ups"] = max(float(summary.get("max_speed_ups", 0.0)), float(entry.get("speed_ups", 0.0)))
	summary["max_horizontal_speed_ups"] = max(float(summary.get("max_horizontal_speed_ups", 0.0)), float(entry.get("horizontal_speed_ups", 0.0)))
	summary["slide_collision_count"] = int(summary.get("slide_collision_count", 0)) + int(entry.get("slide_collision_count", 0))

	var input: Dictionary = entry.get("input", {})
	if bool(input.get("jump_pressed", false)):
		summary["jump_presses"] = int(summary.get("jump_presses", 0)) + 1
	if bool(input.get("duck", false)):
		summary["duck_ticks"] = int(summary.get("duck_ticks", 0)) + 1
	if bool(entry.get("on_floor", false)):
		summary["floor_ticks"] = int(summary.get("floor_ticks", 0)) + 1
	else:
		summary["air_ticks"] = int(summary.get("air_ticks", 0)) + 1
	if bool(entry.get("step_up_attempted", false)):
		summary["step_up_attempts"] = int(summary.get("step_up_attempts", 0)) + 1
	if bool(entry.get("step_up_applied", false)):
		summary["step_up_successes"] = int(summary.get("step_up_successes", 0)) + 1

	var movement_audio_events = entry.get("movement_audio_events", [])
	if movement_audio_events is Array:
		var movement_audio_counts: Dictionary = summary.get("movement_audio_events", {})
		for event in movement_audio_events:
			var event_name := str(event)
			if event_name == "":
				continue
			movement_audio_counts[event_name] = int(movement_audio_counts.get(event_name, 0)) + 1
		summary["movement_audio_events"] = movement_audio_counts

	if enabled and trace_file != null:
		trace_file.store_string(JSON.stringify(entry) + "\n")


func finish(reason: String = "finished") -> void:
	if trace_file != null:
		trace_file.flush()
		trace_file.close()
		trace_file = null
	_write_summary(reason)


func get_paths() -> Dictionary:
	return {
		"session_id": session_id,
		"session_dir": session_user_dir,
		"trace_path": trace_user_path,
		"summary_path": summary_user_path,
	}


func _write_summary(status: String) -> void:
	if summary_user_path == "":
		return
	summary["status"] = status
	var summary_file := FileAccess.open(summary_user_path, FileAccess.WRITE)
	if summary_file != null:
		summary_file.store_string(JSON.stringify(summary, "\t"))
		summary_file.close()


func _make_session_id() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d_%d" % [
		int(now["year"]),
		int(now["month"]),
		int(now["day"]),
		int(now["hour"]),
		int(now["minute"]),
		int(now["second"]),
		int(Time.get_ticks_msec() % 100000),
	]
