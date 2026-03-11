extends Node

signal fever_triggered
signal fever_ended
signal meter_changed(value: float)

var meter := 0.0
var streak := 0
var is_fever_active := false
var _stunned_pegs: Array = []  # positions of pegs to detonate

const STREAK_GAIN_LOW := 0.08   # hits 1-3
const STREAK_GAIN_MID := 0.12   # hits 4-6
const STREAK_GAIN_HIGH := 0.18  # hits 7+
const GREEN_BONUS := 0.15
const ORANGE_BONUS := 0.05
const MISS_PENALTY := 0.5  # multiply by this on total miss

func reset() -> void:
	meter = 0.0
	streak = 0
	is_fever_active = false
	_stunned_pegs.clear()
	meter_changed.emit(meter)

func on_peg_hit(peg_type: String) -> void:
	if is_fever_active:
		return  # Don't fill during fever
	streak += 1
	var gain := STREAK_GAIN_LOW
	if streak >= 7:
		gain = STREAK_GAIN_HIGH
	elif streak >= 4:
		gain = STREAK_GAIN_MID
	if peg_type == "green":
		gain += GREEN_BONUS
	if peg_type == "orange":
		gain += ORANGE_BONUS
	meter = minf(meter + gain, 1.0)
	meter_changed.emit(meter)
	if meter >= 1.0 and not is_fever_active:
		_trigger_fever()

func on_ball_lost(hit_any: bool) -> void:
	streak = 0
	if not hit_any and not is_fever_active:
		meter *= MISS_PENALTY
		meter_changed.emit(meter)

func on_new_board() -> void:
	streak = 0
	# meter persists across boards within an act

func on_new_act() -> void:
	reset()

func _trigger_fever() -> void:
	is_fever_active = true
	fever_triggered.emit()

func end_fever() -> void:
	is_fever_active = false
	meter = 0.0
	streak = 0
	_stunned_pegs.clear()
	meter_changed.emit(meter)
	fever_ended.emit()
