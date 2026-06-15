extends RefCounted

class_name OpenStrikeRoundState

const PHASE_WARMUP := "warmup"
const PHASE_FREEZE_TIME := "freeze_time"
const PHASE_LIVE := "live"
const PHASE_ENDED := "ended"

var round_index := 0
var phase := PHASE_WARMUP
var phase_tick := 0
var elapsed_ticks := 0


func start_round(index: int, start_phase: String = PHASE_FREEZE_TIME) -> void:
	round_index = index
	phase = start_phase
	phase_tick = 0
	elapsed_ticks = 0


func advance_tick() -> void:
	phase_tick += 1
	elapsed_ticks += 1


func set_phase(next_phase: String) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	phase_tick = 0


func to_dictionary() -> Dictionary:
	return {
		"round_index": round_index,
		"phase": phase,
		"phase_tick": phase_tick,
		"elapsed_ticks": elapsed_ticks,
	}
