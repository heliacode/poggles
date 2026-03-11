extends Node

## Tracks all state for a single roguelite run.
## Persists across boards within a run, resets on new run.

signal run_started
signal board_completed(board_index: int)
signal run_ended(won: bool)
signal balls_changed(amount: int)
signal coins_changed(amount: int)
signal score_changed(amount: int)

# Run progress
var is_run_active := false
var current_act := 1
var current_board_index := 0  # 0-4 within act (4 = boss)
var total_boards_cleared := 0
var run_seed := 0

# Player resources (persist across boards)
var balls_remaining := 10
var coins := 0
var score := 0

# Board tracking
var boards_in_act := 5  # 4 normal + 1 boss
var acts_total := 3
var pegs_hit_this_run := 0
var orange_cleared_this_run := 0

# Route map
var route_map: Array = []  # Array of arrays of MapNode dicts
var route_position := 0

# Event / board modifiers
var next_board_mods: Dictionary = {}  # Cleared after each board
var permanent_coin_bonus: int = 0     # +N coins per peg hit, persists for the run
var permanent_orange_score_bonus: int = 0  # +N score per orange cleared, persists for the run

# Constants
const BOARD_CLEAR_BALL_REFUND_MIN := 1
const BOARD_CLEAR_BALL_REFUND_MAX := 3
const COINS_PER_BLUE := 1
const COINS_PER_ORANGE := 3
const COINS_PER_GREEN := 5
const COINS_PER_PURPLE := 10
const COINS_BOARD_CLEAR := 20
const COINS_BUCKET_CATCH := 5

func start_new_run() -> void:
	is_run_active = true
	current_act = 1
	current_board_index = 0
	total_boards_cleared = 0
	var ascension := SaveData.get_ascension_level()
	balls_remaining = maxi(5, GameConfig.STARTING_BALLS - ascension)
	coins = 0
	score = 0
	pegs_hit_this_run = 0
	orange_cleared_this_run = 0
	route_position = 0
	run_seed = randi()
	next_board_mods = {}
	permanent_coin_bonus = 0
	permanent_orange_score_bonus = 0
	RelicManager.reset()
	_generate_route_map()
	run_started.emit()

func get_current_board_number() -> int:
	return (current_act - 1) * boards_in_act + current_board_index + 1

func get_total_boards() -> int:
	return acts_total * boards_in_act

func is_boss_board() -> bool:
	return current_board_index == boards_in_act - 1

func get_act_label() -> String:
	match current_act:
		1: return "The Surface"
		2: return "The Core"
		3: return "The Abyss"
	return "Act %d" % current_act

func complete_board(orange_total: int, orange_cleared: int, board_score: int) -> void:
	var cleared_all := orange_cleared >= orange_total
	total_boards_cleared += 1
	orange_cleared_this_run += orange_cleared

	# Ball refund based on performance
	if cleared_all:
		var ratio := 1.0 if orange_total == 0 else float(orange_cleared) / float(orange_total)
		var refund := BOARD_CLEAR_BALL_REFUND_MIN
		if ratio >= 1.0:
			refund = BOARD_CLEAR_BALL_REFUND_MAX
		elif ratio >= 0.75:
			refund = 2
		add_balls(refund)

		# Board clear coin bonus
		add_coins(COINS_BOARD_CLEAR)

	# Clear one-time board modifiers
	next_board_mods = {}

	# Advance to next board
	current_board_index += 1
	if current_board_index >= boards_in_act:
		# Act complete
		current_act += 1
		current_board_index = 0
		if current_act > acts_total:
			# Run won!
			end_run(true)
			return

	route_position = 0
	_generate_route_map()
	board_completed.emit(total_boards_cleared)

func end_run(won: bool) -> void:
	is_run_active = false
	# Calculate stardust
	var stardust := total_boards_cleared * 50 + score / 100
	if won:
		stardust += 500
	SaveData.add_stardust(stardust)
	SaveData.add_run_stats(total_boards_cleared, score, pegs_hit_this_run, won)
	run_ended.emit(won)

func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

func add_balls(amount: int) -> void:
	balls_remaining += amount
	balls_changed.emit(balls_remaining)

func use_ball() -> void:
	balls_remaining -= 1
	balls_changed.emit(balls_remaining)

func on_peg_hit_coin(peg_type: String) -> void:
	pegs_hit_this_run += 1
	match peg_type:
		"blue": add_coins(COINS_PER_BLUE)
		"orange": add_coins(COINS_PER_ORANGE)
		"green": add_coins(COINS_PER_GREEN)
		"purple": add_coins(COINS_PER_PURPLE)

func on_bucket_catch() -> void:
	add_coins(COINS_BUCKET_CATCH)

func get_difficulty_params() -> Dictionary:
	## Returns generation parameters based on current act/board progression
	var base_orange := 8
	var base_total := 24
	var min_spacing := GameConfig.PEG_RADIUS * 3.0

	match current_act:
		1:
			base_orange = 8 + current_board_index
			base_total = 24 + current_board_index * 2
		2:
			base_orange = 12 + current_board_index
			base_total = 30 + current_board_index * 2
			min_spacing *= 0.9
		3:
			base_orange = 16 + current_board_index
			base_total = 36 + current_board_index * 2
			min_spacing *= 0.85

	# Ascension modifiers
	var ascension := SaveData.get_ascension_level()
	if ascension > 0:
		base_orange += ascension  # More orange pegs per ascension level
		min_spacing *= maxf(0.7, 1.0 - float(ascension) * 0.03)  # Tighter spacing

	return {
		"orange_count": base_orange,
		"total_pegs": base_total,
		"green_count": 2,
		"purple_count": 1,
		"min_spacing": min_spacing,
		"is_boss": is_boss_board(),
		"act": current_act,
		"seed": run_seed + get_current_board_number(),
	}

# --- Route Map Generation ---

enum NodeType { BOARD, ELITE, SHOP, REST, EVENT, BOSS }

func _generate_route_map() -> void:
	route_map.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + current_act * 100 + current_board_index

	# Simple linear map for now: 3-4 choice rows then boss
	var rows_before_boss := 3
	for row in range(rows_before_boss):
		var nodes := []
		if row == 0:
			# First row: always 2-3 board choices
			var count := rng.randi_range(2, 3)
			for i in range(count):
				var type := _pick_node_type(rng, row)
				nodes.append({"type": type, "label": _node_label(type)})
		else:
			var count := rng.randi_range(2, 3)
			for i in range(count):
				var type := _pick_node_type(rng, row)
				nodes.append({"type": type, "label": _node_label(type)})
		route_map.append(nodes)

	# Boss row
	route_map.append([{"type": NodeType.BOSS, "label": "BOSS"}])

func _pick_node_type(rng: RandomNumberGenerator, row: int) -> NodeType:
	var roll := rng.randf()
	if row == 0:
		# First row is mostly boards
		if roll < 0.7: return NodeType.BOARD
		if roll < 0.85: return NodeType.EVENT
		return NodeType.SHOP
	else:
		if roll < 0.40: return NodeType.BOARD
		if roll < 0.55: return NodeType.ELITE
		if roll < 0.70: return NodeType.SHOP
		if roll < 0.85: return NodeType.REST
		return NodeType.EVENT

func _node_label(type: NodeType) -> String:
	match type:
		NodeType.BOARD: return "BOARD"
		NodeType.ELITE: return "ELITE"
		NodeType.SHOP: return "SHOP"
		NodeType.REST: return "REST"
		NodeType.EVENT: return "EVENT"
		NodeType.BOSS: return "BOSS"
	return "???"

func get_current_route_row() -> Array:
	if route_position < route_map.size():
		return route_map[route_position]
	return []

func advance_route(chosen_index: int) -> Dictionary:
	var row := get_current_route_row()
	if chosen_index < 0 or chosen_index >= row.size():
		return {}
	var chosen: Dictionary = row[chosen_index]
	route_position += 1
	return chosen
