class_name PlaytesterBot
extends Node

enum BotDifficulty { RANDOM, SMART, OPTIMAL }

@export var difficulty: BotDifficulty = BotDifficulty.SMART
@export var enabled: bool = false
@export var aim_delay: float = 0.5
@export var fire_delay: float = 0.3

var metrics := {
	"shots_fired": 0,
	"orange_cleared": 0,
	"boards_completed": 0,
	"boards_failed": 0,
	"total_score": 0,
}

var _game_manager: Node = null
var _cannon: Node2D = null
var _pegs_container: Node = null
var _waiting_for_ball := false
var _bot_active := false

func _ready() -> void:
	if not enabled:
		return
	_game_manager = get_parent()
	if _game_manager == null:
		push_warning("PlaytesterBot: No game_manager parent found.")
		return
	_cannon = _game_manager.get_node_or_null("Cannon")
	_pegs_container = _game_manager.get_node_or_null("Pegs")
	if _cannon == null or _pegs_container == null:
		push_warning("PlaytesterBot: Could not find Cannon or Pegs nodes.")
		return
	_bot_active = true
	# Connect to ball_lost signal via game_manager signals
	if _game_manager.has_signal("ball_used"):
		_game_manager.ball_used.connect(_on_ball_used)
	_start_loop()

func _start_loop() -> void:
	# Use a deferred call to begin the bot loop
	_do_bot_turn.call_deferred()

func _do_bot_turn() -> void:
	if not _bot_active or not enabled:
		return
	if not is_instance_valid(_game_manager):
		return

	# Wait for PLAYING state
	while is_instance_valid(_game_manager) and _game_manager.state != _game_manager.State.PLAYING:
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(_game_manager):
			return

	if not is_instance_valid(_game_manager):
		return

	# Aim delay
	await get_tree().create_timer(aim_delay).timeout
	if not is_instance_valid(_game_manager) or _game_manager.state != _game_manager.State.PLAYING:
		_do_bot_turn.call_deferred()
		return

	# Calculate and set aim
	var angle := _calculate_aim()
	if is_instance_valid(_cannon) and _cannon.has_method("set_aim_angle"):
		_cannon.set_aim_angle(angle)

	# Fire delay
	await get_tree().create_timer(fire_delay).timeout
	if not is_instance_valid(_game_manager) or _game_manager.state != _game_manager.State.PLAYING:
		_do_bot_turn.call_deferred()
		return

	# Fire
	if is_instance_valid(_cannon) and _cannon.has_method("force_fire"):
		_cannon.force_fire()
		metrics["shots_fired"] += 1

	# Wait for ball to be lost
	_waiting_for_ball = true
	while _waiting_for_ball and is_instance_valid(_game_manager):
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(_game_manager):
			return
		# Check if ball is gone (state changed from PLAYING while we wait)
		if _game_manager.current_ball == null and _game_manager.state != _game_manager.State.PLAYING:
			_waiting_for_ball = false
		# Also break if state went back to PLAYING (ball was lost and reset)
		if _game_manager.current_ball == null and _game_manager.state == _game_manager.State.PLAYING:
			_waiting_for_ball = false

	# Check end conditions
	if is_instance_valid(_game_manager):
		if _game_manager.state == _game_manager.State.LEVEL_COMPLETE:
			metrics["boards_completed"] += 1
			metrics["total_score"] = _game_manager.score
			_print_metrics()
			return
		elif _game_manager.state == _game_manager.State.GAME_OVER:
			metrics["boards_failed"] += 1
			metrics["total_score"] = _game_manager.score
			_print_metrics()
			return

	# Continue loop
	_do_bot_turn.call_deferred()

func _on_ball_used() -> void:
	pass

func _calculate_aim() -> float:
	match difficulty:
		BotDifficulty.RANDOM:
			return _aim_random()
		BotDifficulty.SMART:
			return _aim_smart()
		BotDifficulty.OPTIMAL:
			return _aim_optimal()
	return 0.0

func _aim_random() -> float:
	return deg_to_rad(randf_range(-75.0, 75.0))

func _aim_smart() -> float:
	if not is_instance_valid(_pegs_container) or not is_instance_valid(_cannon):
		return _aim_random()

	var cannon_pos: Vector2 = _cannon.global_position
	var best_score := -1.0
	var best_angle := 0.0

	var pegs := _get_active_pegs()
	if pegs.is_empty():
		return _aim_random()

	for peg_data in pegs:
		var peg_pos: Vector2 = peg_data["position"]
		var peg_score: float = _score_peg(peg_data, pegs)

		if peg_score > best_score:
			best_score = peg_score
			var direction: Vector2 = peg_pos - cannon_pos
			best_angle = direction.angle() - PI / 2.0

	return best_angle

func _aim_optimal() -> float:
	if not is_instance_valid(_pegs_container) or not is_instance_valid(_cannon):
		return _aim_random()

	var cannon_pos: Vector2 = _cannon.global_position
	var pegs := _get_active_pegs()
	if pegs.is_empty():
		return _aim_random()

	var best_score := -1.0
	var best_angle := 0.0

	# Sample 36 angles (every 5 degrees from -90 to 90)
	for i in range(37):
		var angle_deg := -90.0 + float(i) * 5.0
		var angle_rad := deg_to_rad(angle_deg)
		var direction := Vector2(sin(angle_rad), cos(angle_rad))  # Down-ish direction

		var trajectory_score := 0.0
		# Trace a line from cannon in this direction and score nearby pegs
		for peg_data in pegs:
			var peg_pos: Vector2 = peg_data["position"]
			# Calculate distance from peg to the trajectory line
			var to_peg: Vector2 = peg_pos - cannon_pos
			var proj := to_peg.dot(direction)
			if proj < 0:
				continue  # Behind cannon
			var closest_point: Vector2 = cannon_pos + direction * proj
			var dist := peg_pos.distance_to(closest_point)
			if dist <= 30.0:
				trajectory_score += _score_peg_simple(peg_data)

		if trajectory_score > best_score:
			best_score = trajectory_score
			best_angle = angle_rad

	return best_angle

func _get_active_pegs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(_pegs_container):
		return result

	for peg in _pegs_container.get_children():
		if not peg.has_method("is_hit") or peg.is_hit():
			continue
		var peg_type := "blue"
		if peg.has_method("get_peg_type"):
			peg_type = peg.get_peg_type()
		var special_type := ""
		if peg.has_method("get_special_type"):
			special_type = peg.get_special_type()
		result.append({
			"position": peg.global_position as Vector2,
			"type": peg_type,
			"special": special_type,
		})
	return result

func _score_peg(peg_data: Dictionary, all_pegs: Array[Dictionary]) -> float:
	var base_score := _score_peg_simple(peg_data)

	# Cluster bonus: nearby pegs within 80px
	var peg_pos: Vector2 = peg_data["position"]
	var cluster_bonus := 0.0
	for other in all_pegs:
		if other == peg_data:
			continue
		var other_pos: Vector2 = other["position"]
		if peg_pos.distance_to(other_pos) <= 80.0:
			cluster_bonus += _score_peg_simple(other) * 0.2

	return base_score + cluster_bonus

func _score_peg_simple(peg_data: Dictionary) -> float:
	var peg_type: String = peg_data["type"]
	match peg_type:
		"orange": return 1000.0
		"green": return 400.0
		"purple": return 300.0
		"blue": return 10.0
	return 10.0

func _print_metrics() -> void:
	print("[PlaytesterBot] Metrics: ", metrics)
