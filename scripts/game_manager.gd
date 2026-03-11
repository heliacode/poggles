extends Node2D

signal ball_used
signal score_changed(new_score: int)
signal orange_pegs_changed(remaining: int)

enum State { LEVEL_INTRO, PLAYING, BALL_LOST, LEVEL_COMPLETE, GAME_OVER }

var state: State = State.LEVEL_INTRO
var score := 0
var balls_remaining := GameConfig.STARTING_BALLS
var orange_pegs_total := 0
var orange_pegs_remaining := 0
var current_ball: RigidBody2D = null
var ball_scene: PackedScene
var _shake_amount := 0.0
var _shake_decay := 5.0
var _camera_offset := Vector2.ZERO
var _flash_alpha := 0.0
var _flash_color := Color(1.0, 0.6, 0.1)
var _combo_count := 0
var _level_data: LevelData
var _balls_used := 0
var _is_roguelite := false
var _board_score := 0
var _active_gravity_wells: Array[Dictionary] = []
var _bot: Node = null
var _hit_streak_positions: Array[Vector2] = []

@onready var cannon := $Cannon
@onready var pegs_container := $Pegs
@onready var bucket := $Bucket
@onready var hud := $HUD
@onready var pause_menu := $PauseMenu

func _ready() -> void:
	ball_scene = load(GameConfig.BALL_SCENE_PATH)
	_is_roguelite = RunState.is_run_active
	_load_level()
	_connect_signals()
	_start_intro()
	if OS.has_feature("playtest") or OS.get_cmdline_args().has("--bot"):
		_enable_bot()

func _enable_bot(difficulty: int = 1) -> void:
	var bot_script: Script = load("res://scripts/playtest/playtest_bot.gd")
	_bot = Node.new()
	_bot.set_script(bot_script)
	_bot.difficulty = difficulty
	_bot.enabled = true
	add_child(_bot)

func _load_level() -> void:
	if _is_roguelite:
		# Procedural generation from RunState
		var params := RunState.get_difficulty_params()
		_level_data = BoardGenerator.generate(params)
		balls_remaining = RunState.balls_remaining
	else:
		# Practice mode: load from file
		_level_data = LevelLoader.load_level(SceneManager.current_level)
		if _level_data:
			balls_remaining = _level_data.starting_balls

	if _level_data:
		var peg_script := load("res://scripts/peg.gd")
		LevelLoader.spawn_pegs(_level_data, pegs_container, peg_script)
		await get_tree().process_frame
		_connect_peg_signals()
		_count_orange_pegs()
	_update_hud()

func _connect_signals() -> void:
	cannon.ball_fired.connect(_on_ball_fired)
	bucket.ball_caught.connect(_on_ball_caught)

func _connect_peg_signals() -> void:
	for peg in pegs_container.get_children():
		if peg.has_signal("peg_hit"):
			peg.peg_hit.connect(_on_peg_hit)

func _start_intro() -> void:
	state = State.LEVEL_INTRO
	cannon.can_shoot = false
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(_start_playing)

func _start_playing() -> void:
	state = State.PLAYING
	cannon.can_shoot = true

func _process(delta: float) -> void:
	if _flash_alpha > 0:
		_flash_alpha *= 0.85
		if _flash_alpha < 0.005:
			_flash_alpha = 0.0
		queue_redraw()

	if _shake_amount > 0:
		_shake_amount = max(0, _shake_amount - _shake_decay * delta)
		_camera_offset = Vector2(
			randf_range(-_shake_amount, _shake_amount),
			randf_range(-_shake_amount, _shake_amount)
		)
		pegs_container.position = _camera_offset
	elif _camera_offset != Vector2.ZERO:
		_camera_offset = Vector2.ZERO
		pegs_container.position = Vector2.ZERO

	# Apply gravity well forces to ball
	if current_ball and not _active_gravity_wells.is_empty():
		var i := _active_gravity_wells.size() - 1
		while i >= 0:
			var well: Dictionary = _active_gravity_wells[i]
			well["time_left"] -= delta
			if well["time_left"] <= 0:
				_active_gravity_wells.remove_at(i)
				i -= 1
				continue
			var to_well: Vector2 = well["position"] - current_ball.global_position
			var dist := to_well.length()
			if dist < GameConfig.GRAVITY_WELL_RADIUS and dist > 5.0:
				var strength := GameConfig.GRAVITY_WELL_FORCE / (dist * dist) * 100.0
				strength = minf(strength, GameConfig.GRAVITY_WELL_MAX_ACCEL)
				current_ball.apply_central_force(to_well.normalized() * strength)
			i -= 1

func _draw() -> void:
	if _flash_alpha > 0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(_flash_color.r, _flash_color.g, _flash_color.b, _flash_alpha))

func _count_orange_pegs() -> void:
	orange_pegs_total = 0
	for peg in pegs_container.get_children():
		if peg.has_method("get_peg_type") and peg.get_peg_type() == "orange":
			orange_pegs_total += 1
	orange_pegs_remaining = orange_pegs_total

func _on_ball_fired(pos: Vector2, direction: Vector2, power: float) -> void:
	if state != State.PLAYING:
		return
	if current_ball != null or balls_remaining <= 0:
		cannon.can_shoot = true
		return

	balls_remaining -= 1
	_balls_used += 1
	if _is_roguelite:
		RunState.use_ball()
	_update_hud()
	ball_used.emit()

	current_ball = ball_scene.instantiate()
	current_ball.position = pos
	add_child(current_ball)
	current_ball.launch(direction * power)
	current_ball.ball_lost.connect(_on_ball_lost)

func _on_ball_lost() -> void:
	state = State.BALL_LOST
	_combo_count = 0
	_hit_streak_positions.clear()
	if current_ball:
		current_ball.queue_free()
		current_ball = null
	_active_gravity_wells.clear()
	_remove_hit_pegs()

	await get_tree().create_timer(0.3).timeout

	if orange_pegs_remaining <= 0:
		_on_board_cleared()
	elif balls_remaining <= 0:
		_on_out_of_balls()
	else:
		state = State.PLAYING
		cannon.can_shoot = true

func _celebrate_clear() -> void:
	# Flash remaining pegs
	for peg in pegs_container.get_children():
		if peg.has_method("flash_celebrate"):
			peg.flash_celebrate()
	# Radial spark burst from center
	var center := Vector2(640, 360)
	for i in range(32):
		var spark := _CelebrationSpark.new()
		spark._angle = TAU * float(i) / 32.0 + randf() * 0.1
		spark._speed = randf_range(200, 500)
		spark._color = Color(1.0, 0.85, 0.3)  # Gold
		spark.global_position = center
		add_child(spark)
	_flash_alpha = 0.25
	_shake_amount = 6.0

func _on_board_cleared() -> void:
	state = State.LEVEL_COMPLETE
	_celebrate_clear()
	await get_tree().create_timer(1.0).timeout

	if _is_roguelite:
		var prev_act := RunState.current_act
		RunState.complete_board(orange_pegs_total, orange_pegs_total, _board_score)
		# Sync balls back (complete_board may have added refund)
		balls_remaining = RunState.balls_remaining
		if RunState.is_run_active:
			if RunState.current_act != prev_act:
				# New act — show act intro first
				SceneManager.go_to_act_intro(RunState.current_act)
			else:
				SceneManager.go_to_route_map()
		else:
			# Run was won (act 3 boss cleared)
			SceneManager.go_to_run_results()
	else:
		SceneManager.go_to_results(score, orange_pegs_total, orange_pegs_total - orange_pegs_remaining, _balls_used)

func _on_out_of_balls() -> void:
	state = State.GAME_OVER
	await get_tree().create_timer(1.0).timeout

	if _is_roguelite:
		var orange_cleared := orange_pegs_total - orange_pegs_remaining
		RunState.complete_board(orange_pegs_total, orange_cleared, _board_score)
		RunState.end_run(false)
		SceneManager.go_to_run_results()
	else:
		SceneManager.go_to_results(score, orange_pegs_total, orange_pegs_total - orange_pegs_remaining, _balls_used)

func _on_ball_caught() -> void:
	balls_remaining += 1
	if _is_roguelite:
		RunState.add_balls(1)
		RunState.on_bucket_catch()
	_update_hud()
	_spawn_score_popup("+1 BALL!", Color(0.3, 1.0, 0.5), bucket.global_position + Vector2(0, -30))

func _on_peg_hit(peg: Node) -> void:
	var peg_type: String = peg.get_peg_type()
	var special: String = peg.get_special_type() if peg.has_method("get_special_type") else ""

	_combo_count += 1

	# Apply score multiplier from ball
	var multiplier := 1.0
	if current_ball and current_ball.score_multiplier > 1.0:
		multiplier = current_ball.score_multiplier

	var points := int(float(GameConfig.PEG_SCORES.get(peg_type, 0)) * multiplier)
	_add_score(points)
	_shake_amount = clampf(float(points) / 50.0 * (1.0 + _combo_count * 0.3), 1.0, 8.0)
	var color: Color = GameConfig.SCORE_POPUP_COLORS.get(peg_type, Color.WHITE)
	var popup_text := "+%d" % points
	if multiplier > 1.0:
		popup_text = "+%d x%d" % [points, int(multiplier)]
	if _combo_count >= 3:
		popup_text += " x%d COMBO!" % _combo_count
	_spawn_score_popup(popup_text, color, peg.global_position)

	# Screen flash on orange peg hit
	if peg_type == "orange":
		_flash_color = Color(1.0, 0.6, 0.1)
		_flash_alpha = 0.15
	# Cyan tint on high combo
	if _combo_count >= 5:
		_flash_color = Color(0.2, 0.8, 1.0)
		_flash_alpha = maxf(_flash_alpha, 0.1)

	if _is_roguelite:
		RunState.on_peg_hit_coin(peg_type)

	# Hit streak lightning
	_hit_streak_positions.append(peg.global_position)
	if _hit_streak_positions.size() > 5:
		_hit_streak_positions.remove_at(0)
	if _hit_streak_positions.size() >= 3:
		var bolt := _ChainBoltEffect.new()
		bolt._start = _hit_streak_positions[-2]
		bolt._end = _hit_streak_positions[-1]
		bolt._color = Color(0.8, 0.6, 1.0)  # Purple lightning
		bolt._lifetime = 0.4
		add_child(bolt)

	# Handle special peg effects
	match special:
		"bomb": _effect_bomb(peg)
		"chain": _effect_chain(peg)
		"multiplier": _effect_multiplier()
		"gravity": _effect_gravity(peg)

func _effect_bomb(peg: Node2D) -> void:
	var center := peg.global_position
	for other in pegs_container.get_children():
		if other == peg or not other.has_method("hit"):
			continue
		if other.is_hit():
			continue
		if center.distance_to(other.global_position) <= GameConfig.BOMB_RADIUS:
			other.hit()

func _effect_chain(peg: Node2D) -> void:
	var center := peg.global_position
	# Find nearest un-hit pegs within chain radius
	var candidates: Array[Dictionary] = []
	for other in pegs_container.get_children():
		if other == peg or not other.has_method("hit"):
			continue
		if other.is_hit():
			continue
		var dist: float = center.distance_to(other.global_position)
		if dist <= GameConfig.CHAIN_RADIUS:
			candidates.append({"peg": other, "dist": dist})
	# Sort by distance
	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])
	# Hit up to CHAIN_MAX_TARGETS with visual bolt + delay
	var targets := mini(GameConfig.CHAIN_MAX_TARGETS, candidates.size())
	for i in range(targets):
		var target: Node = candidates[i]["peg"]
		# Spawn chain bolt visual (simple line effect)
		var bolt := _ChainBoltEffect.new()
		bolt._start = peg.global_position
		bolt._end = target.global_position
		add_child(bolt)
		# Hit the target after a short delay
		var delay := 0.1 + float(i) * 0.1
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(target) and not target.is_hit():
				target.hit()
		)

func _effect_multiplier() -> void:
	if current_ball:
		current_ball.score_multiplier = 2.0

func _effect_gravity(peg: Node2D) -> void:
	_active_gravity_wells.append({
		"position": peg.global_position,
		"time_left": GameConfig.GRAVITY_WELL_DURATION,
	})

func _add_score(points: int) -> void:
	score += points
	_board_score += points
	if _is_roguelite:
		RunState.add_score(points)
	score_changed.emit(score)
	_update_hud()
	if has_node("Background") and $Background.has_method("pulse"):
		$Background.pulse(clampf(float(points) / 100.0, 0.1, 0.5))

func _spawn_score_popup(text: String, col: Color, pos: Vector2) -> void:
	var popup := Node2D.new()
	var script = load(GameConfig.SCORE_POPUP_PATH)
	popup.set_script(script)
	add_child(popup)
	popup.setup(text, col, pos)

func _on_orange_peg_cleared() -> void:
	orange_pegs_remaining -= 1
	orange_pegs_changed.emit(orange_pegs_remaining)
	_update_hud()

func _remove_hit_pegs() -> void:
	for peg in pegs_container.get_children():
		if peg.has_method("is_hit") and peg.is_hit():
			if peg.get_peg_type() == "orange":
				_on_orange_peg_cleared()
			peg.remove_peg()

func _update_hud() -> void:
	if hud:
		if _is_roguelite:
			hud.update_score(RunState.score)
			hud.update_balls(RunState.balls_remaining)
		else:
			hud.update_score(score)
			hud.update_balls(balls_remaining)
		hud.update_orange(orange_pegs_remaining, orange_pegs_total)
		if _is_roguelite:
			hud.update_run_info(RunState.current_act, RunState.get_current_board_number(), RunState.coins)


class _ChainBoltEffect extends Node2D:
	var _start := Vector2.ZERO
	var _end := Vector2.ZERO
	var _color := Color(0.0, 1.0, 1.0)
	var _lifetime := 0.3
	var _age := 0.0
	var _path: PackedVector2Array = PackedVector2Array()

	func _ready() -> void:
		_generate_path()

	func _generate_path() -> void:
		_path.clear()
		_path.append(_start)
		var segments := 5
		var dir := (_end - _start)
		for i in range(1, segments):
			var t := float(i) / float(segments)
			var point := _start + dir * t
			var perp := Vector2(-dir.y, dir.x).normalized()
			point += perp * randf_range(-6, 6)
			_path.append(point)
		_path.append(_end)

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _lifetime:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := 1.0 - _age / _lifetime
		if _path.size() < 2:
			return
		# Convert global positions to local
		var local_path := PackedVector2Array()
		for p in _path:
			local_path.append(p - global_position)
		draw_polyline(local_path, Color(_color.r, _color.g, _color.b, t * 0.9), 2.0)
		draw_polyline(local_path, Color(_color.r, _color.g, _color.b, t * 0.2), 5.0)


class _CelebrationSpark extends Node2D:
	var _color := Color.GOLD
	var _angle := 0.0
	var _speed := 300.0
	var _lifetime := 1.0
	var _age := 0.0
	var _vel := Vector2.ZERO

	func _ready() -> void:
		_vel = Vector2.from_angle(_angle) * _speed

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _lifetime:
			queue_free()
			return
		position += _vel * delta
		_vel *= 0.97
		queue_redraw()

	func _draw() -> void:
		var t := 1.0 - _age / _lifetime
		draw_circle(Vector2.ZERO, 4.0 * t, Color(_color.r, _color.g, _color.b, t * 0.4))
		var dir := _vel.normalized()
		var len := _vel.length() * 0.03 * t
		draw_line(-dir * len, dir * len, Color(_color.r, _color.g, _color.b, t), 2.0)
		draw_circle(Vector2.ZERO, 1.5 * t, Color(1, 1, 1, t * 0.9))
