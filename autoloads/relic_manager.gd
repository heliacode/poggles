extends Node

signal relic_acquired(relic: RelicData)
signal relic_effect_triggered(relic_id: String, description: String)

var active_relics: Array[RelicData] = []
var _relic_ids: Array[String] = []
var _first_ball_lost_this_board := false
var _first_shot_this_board := true
var _combo_peg_count := 0

func reset() -> void:
	active_relics.clear()
	_relic_ids.clear()
	_first_ball_lost_this_board = false
	_first_shot_this_board = true
	_combo_peg_count = 0

func add_relic(relic: RelicData) -> void:
	if relic.id in _relic_ids:
		return
	active_relics.append(relic)
	_relic_ids.append(relic.id)
	relic_acquired.emit(relic)
	AudioManager.play_sfx("relic_acquire")

func has_relic(id: String) -> bool:
	return id in _relic_ids

func get_active_ids() -> Array[String]:
	return _relic_ids.duplicate()

func get_relic_count() -> int:
	return active_relics.size()

func on_board_start() -> void:
	_first_ball_lost_this_board = false
	_first_shot_this_board = true
	_combo_peg_count = 0

	if has_relic("thick_skin"):
		RunState.add_balls(1)
	if has_relic("pocket_change"):
		RunState.add_coins(5)
	if has_relic("glass_cannon"):
		RunState.add_balls(-2)

func on_peg_hit(peg_type: String, combo_count: int, peg: Node) -> Dictionary:
	var result := {"score_bonus": 0, "coin_bonus": 0, "trigger_bomb": false}
	_combo_peg_count += 1

	if has_relic("lucky_penny") and peg_type == "blue":
		result["coin_bonus"] += 1

	if has_relic("iron_ball") and peg_type == "blue":
		result["score_bonus"] += int(float(GameConfig.PEG_SCORES["blue"]) * 0.15)

	if has_relic("orange_hunter") and peg_type == "orange":
		result["score_bonus"] += 25

	if has_relic("glass_cannon"):
		result["score_bonus"] += int(float(GameConfig.PEG_SCORES.get(peg_type, 0)) * 0.5)

	if has_relic("combo_king") and combo_count >= 5:
		result["coin_bonus"] += 1

	if has_relic("combo_breaker") and _combo_peg_count % 10 == 0:
		result["trigger_bomb"] = true

	return result

func on_ball_fired() -> Dictionary:
	var result := {"skip_ball_use": false, "score_multiplier": 1.0}

	if has_relic("infinite_echo"):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		if rng.randf() < 0.2:
			result["skip_ball_use"] = true

	if has_relic("steady_hand") and _first_shot_this_board:
		result["score_multiplier"] = 2.0

	_first_shot_this_board = false
	return result

func on_ball_lost(hit_any: bool) -> Dictionary:
	var result := {"refund_ball": false}

	if has_relic("second_wind"):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		if rng.randf() < 0.25:
			result["refund_ball"] = true

	if has_relic("neon_shield") and not _first_ball_lost_this_board:
		_first_ball_lost_this_board = true
		result["refund_ball"] = true

	return result

func on_ball_caught() -> Dictionary:
	var result := {"score_bonus": 0}

	if has_relic("golden_bucket"):
		result["score_bonus"] += 50

	return result

func on_board_clear() -> Dictionary:
	var result := {"coin_bonus": 0, "ball_bonus": 0}

	if has_relic("coin_magnet"):
		result["coin_bonus"] += 2

	if has_relic("lattice_key"):
		result["ball_bonus"] += 1
		result["coin_bonus"] += int(float(RunState.coins) * 0.3)

	return result

func on_run_end(won: bool) -> Dictionary:
	var result := {"stardust_multiplier": 1.0}

	if has_relic("stardust_magnet"):
		result["stardust_multiplier"] = 1.25

	return result

func get_fever_multiplier() -> int:
	if has_relic("void_heart"):
		return 5
	return 3

func get_fever_fill_multiplier() -> float:
	if has_relic("fever_frenzy"):
		return 1.3
	return 1.0

func get_bomb_radius_multiplier() -> float:
	if has_relic("bomb_squad"):
		return 1.5
	return 1.0

func get_chain_extra_targets() -> int:
	if has_relic("chain_reaction"):
		return 1
	return 0

func get_bucket_width_multiplier() -> float:
	if has_relic("bounce_pad"):
		return 1.3
	return 1.0

func get_phantom_duration_bonus() -> float:
	if has_relic("phantom_drift"):
		return 1.0
	return 0.0

func get_gravity_force_multiplier() -> float:
	if has_relic("gravity_lens"):
		return 1.5
	return 1.0

func get_prism_extra_balls() -> int:
	if has_relic("prism_master"):
		return 1
	return 0
