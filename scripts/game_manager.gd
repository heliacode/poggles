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
var _boss_data: BossData = null
var _boss_hp := 0
var _boss_max_hp := 0
var _boss_phases_triggered: Array[int] = []
var _boss_intro_done := false
var _tutorial: Node = null
var _last_peg_slowmo := false
var _last_peg_zoom_target := Vector2.ZERO
var _last_peg_zoom_progress := 0.0
var _near_miss_pegs: Array[Node] = []
var _bucket_catch_sparks := false
var _score_tally_items: Array[Dictionary] = []
var _score_tally_time := 0.0
var _showing_tally := false

@onready var cannon := $Cannon
@onready var pegs_container := $Pegs
@onready var bucket := $Bucket
@onready var hud := $HUD
@onready var pause_menu := $PauseMenu

var _board_mods: Dictionary = {}

func _ready() -> void:
	ball_scene = load(GameConfig.BALL_SCENE_PATH)
	_is_roguelite = RunState.is_run_active
	if _is_roguelite:
		_board_mods = RunState.next_board_mods.duplicate()
	_load_level()
	_connect_signals()
	_start_intro()
	FeverManager.fever_triggered.connect(_on_fever_triggered)
	FeverManager.on_new_board()
	PowerUpManager.reset()
	# Apply gameplay mods from events
	if _board_mods.has("gravity_pegs_pre_triggered"):
		# Pre-trigger all gravity wells at their peg positions
		for peg in pegs_container.get_children():
			if peg.has_method("get_special_type") and peg.get_special_type() == "gravity":
				_active_gravity_wells.append({
					"position": peg.global_position,
					"time_left": GameConfig.GRAVITY_WELL_DURATION * 2.0,
				})
	if _board_mods.has("multiplier_pegs_pre_activated"):
		# Pre-activate all multiplier pegs (mark as hit)
		for peg in pegs_container.get_children():
			if peg.has_method("get_special_type") and peg.get_special_type() == "multiplier":
				peg.hit()
	# Start gameplay music
	if _is_roguelite and RunState.is_boss_board():
		AudioManager.play_music("boss")
	else:
		AudioManager.play_music("gameplay")
	# Relic board start effects
	if _is_roguelite:
		RelicManager.on_board_start()
		balls_remaining = RunState.balls_remaining
	# Tutorial for first-time players
	if SaveData.is_first_run() and not SaveData.has_completed_tutorial():
		var tutorial_script := load("res://scripts/tutorial.gd")
		_tutorial = Node.new()
		_tutorial.set_script(tutorial_script)
		add_child(_tutorial)
		_tutorial.start_tutorial(self)
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
		var params := RunState.get_difficulty_params()
		# Boss-specific setup
		if RunState.is_boss_board():
			_boss_data = BossData.get_boss(RunState.current_act)
			_boss_hp = _boss_data.hp
			_boss_max_hp = _boss_data.hp
			_boss_phases_triggered = []
			params["template"] = _boss_data.layout_type
			params["total_pegs"] += 6
			params["orange_count"] += 4
		_level_data = BoardGenerator.generate(params)
		balls_remaining = RunState.balls_remaining
	else:
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
	var delay := 0.5
	if _boss_data:
		delay = 2.5  # Longer intro for boss
		_boss_intro_done = false
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func():
		_boss_intro_done = true
		_start_playing()
	)

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
		if SaveData.get_screen_shake():
			_camera_offset = Vector2(
				randf_range(-_shake_amount, _shake_amount),
				randf_range(-_shake_amount, _shake_amount)
			)
			pegs_container.position = _camera_offset
	elif _camera_offset != Vector2.ZERO:
		_camera_offset = Vector2.ZERO
		pegs_container.position = Vector2.ZERO

	# Near-miss detection: ball passes within 5px of un-hit peg
	if current_ball:
		for peg in pegs_container.get_children():
			if peg.has_method("is_hit") and not peg.is_hit():
				var dist := current_ball.global_position.distance_to(peg.global_position)
				var near_threshold := GameConfig.PEG_RADIUS + GameConfig.BALL_RADIUS + 5.0
				if dist < near_threshold and dist > GameConfig.PEG_RADIUS + GameConfig.BALL_RADIUS and peg not in _near_miss_pegs:
					_near_miss_pegs.append(peg)
					peg.flash_celebrate()
					AudioManager.play_sfx("near_miss")

	# Last peg zoom effect
	if _last_peg_slowmo:
		_last_peg_zoom_progress = minf(_last_peg_zoom_progress + delta * 2.0, 1.0)
		queue_redraw()

	# Score tally animation
	if _showing_tally:
		_score_tally_time += delta
		queue_redraw()

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
				var strength := GameConfig.GRAVITY_WELL_FORCE * RelicManager.get_gravity_force_multiplier() / (dist * dist) * 100.0
				strength = minf(strength, GameConfig.GRAVITY_WELL_MAX_ACCEL)
				current_ball.apply_central_force(to_well.normalized() * strength)
			i -= 1

func _check_boss_phases() -> void:
	if not _boss_data:
		return
	var hp_ratio := float(_boss_hp) / float(_boss_max_hp)
	for i in range(_boss_data.phases.size()):
		if i in _boss_phases_triggered:
			continue
		var phase: Dictionary = _boss_data.phases[i]
		if hp_ratio <= phase["hp_threshold"]:
			_boss_phases_triggered.append(i)
			_execute_boss_phase(phase)

func _execute_boss_phase(phase: Dictionary) -> void:
	_flash_alpha = 0.3
	_flash_color = Color(1.0, 0.2, 0.2)
	_shake_amount = 8.0
	match phase["action"]:
		"spawn_armored":
			# Spawn new armored pegs
			var count: int = phase.get("count", 2)
			var peg_script := load("res://scripts/peg.gd")
			for _i in range(count):
				var pos := Vector2(
					randf_range(BoardGenerator.PLAY_AREA.position.x + 50, BoardGenerator.PLAY_AREA.end.x - 50),
					randf_range(BoardGenerator.PLAY_AREA.position.y + 50, BoardGenerator.PLAY_AREA.end.y - 50)
				)
				var peg := StaticBody2D.new()
				peg.set_script(peg_script)
				peg.position = pos
				peg.peg_type = "blue"
				peg.special_type = "armored"
				pegs_container.add_child(peg)
				if peg.has_signal("peg_hit"):
					peg.peg_hit.connect(_on_peg_hit)
		"narrow_bucket":
			# Make bucket narrower
			if bucket:
				bucket.scale.x *= 0.7
		"add_movement":
			# Future: make pegs move (handled in peg.gd with movement component)
			pass
		"spawn_gravity":
			var count: int = phase.get("count", 1)
			for _i in range(count):
				var pos := Vector2(
					randf_range(BoardGenerator.PLAY_AREA.position.x + 100, BoardGenerator.PLAY_AREA.end.x - 100),
					randf_range(BoardGenerator.PLAY_AREA.position.y + 100, BoardGenerator.PLAY_AREA.end.y - 100)
				)
				_active_gravity_wells.append({
					"position": pos,
					"time_left": GameConfig.GRAVITY_WELL_DURATION * 3.0,
				})
		"hide_pegs":
			# Make un-hit pegs semi-invisible
			for peg in pegs_container.get_children():
				if peg.has_method("is_hit") and not peg.is_hit():
					peg.modulate.a = 0.15
		"shrink_area":
			# Visual warning - shake and flash
			_shake_amount = 10.0

func _draw() -> void:
	if _flash_alpha > 0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(_flash_color.r, _flash_color.g, _flash_color.b, _flash_alpha))

	# Boss intro overlay
	if _boss_data and not _boss_intro_done:
		var font := ThemeDB.fallback_font
		var cx := 640.0
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.0, 0.0, 0.0, 0.6))
		var name_size := font.get_string_size(_boss_data.boss_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 42)
		draw_string(font, Vector2(cx - name_size.x / 2.0, 320), _boss_data.boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color(1.0, 0.2, 0.2))
		var title_size := font.get_string_size(_boss_data.title, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
		draw_string(font, Vector2(cx - title_size.x / 2.0, 360), _boss_data.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.4, 0.4, 0.7))

	# Boss HP bar
	if _boss_data and _boss_intro_done:
		_draw_boss_hp_bar()

	# Last peg zoom vignette effect
	if _last_peg_slowmo and _last_peg_zoom_progress > 0:
		var vignette_alpha := _last_peg_zoom_progress * 0.3
		# Dark vignette around edges
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, vignette_alpha * 0.4))
		# Bright ring around target
		var target_local := _last_peg_zoom_target - global_position
		var ring_radius := 60.0 - _last_peg_zoom_progress * 20.0
		draw_arc(target_local, ring_radius, 0, TAU, 48, Color(1.0, 0.6, 0.1, vignette_alpha), 2.0, true)
		draw_arc(target_local, ring_radius + 8, 0, TAU, 48, Color(1.0, 0.6, 0.1, vignette_alpha * 0.3), 1.0, true)

	# Score tally overlay
	if _showing_tally:
		var font := ThemeDB.fallback_font
		var cx := 640.0
		var base_y := 240.0
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.5))
		for item in _score_tally_items:
			if _score_tally_time < item["delay"]:
				continue
			var item_alpha := minf((_score_tally_time - item["delay"]) * 4.0, 1.0)
			var y_offset := (1.0 - item_alpha) * -15.0
			var label: String = item["label"]
			var value: String = item["value"]
			if value == "":
				# Header line
				var sz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
				draw_string(font, Vector2(cx - sz.x / 2.0, base_y + y_offset), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1.0, 0.85, 0.3, item_alpha))
			else:
				var lsz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
				var vsz := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
				draw_string(font, Vector2(cx - 120, base_y + y_offset), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.7, 0.85, 1.0, item_alpha))
				draw_string(font, Vector2(cx + 80, base_y + y_offset), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 1.0, 1.0, item_alpha))
			base_y += 40.0

func _draw_boss_hp_bar() -> void:
	var font := ThemeDB.fallback_font
	var bar_width := 400.0
	var bar_height := 12.0
	var bar_x := (1280.0 - bar_width) / 2.0
	var bar_y := 120.0
	# Background
	draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_width + 2, bar_height + 2), Color(0.15, 0.05, 0.05, 0.8))
	# Fill
	var ratio := float(_boss_hp) / float(_boss_max_hp)
	var fill_color := Color(1.0, 0.2, 0.1)
	if ratio < 0.25:
		fill_color = Color(1.0, 0.1, 0.05)
	elif ratio < 0.5:
		fill_color = Color(1.0, 0.5, 0.1)
	draw_rect(Rect2(bar_x, bar_y, bar_width * ratio, bar_height), fill_color)
	# Border
	draw_rect(Rect2(bar_x, bar_y, bar_width, bar_height), Color(1.0, 0.3, 0.2, 0.6), false, 1.5)
	# Name
	var label := _boss_data.boss_name
	var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, Vector2(bar_x + (bar_width - label_size.x) / 2.0, bar_y - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.4, 0.3, 0.9))
	# HP text
	var hp_text := "%d / %d" % [_boss_hp, _boss_max_hp]
	var hp_size := font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	draw_string(font, Vector2(bar_x + bar_width + 8, bar_y + bar_height - 1), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.5, 0.4, 0.7))

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
	AudioManager.play_sfx("cannon_fire")
	AudioManager.reset_combo_pitch()
	if _tutorial and _tutorial.is_active():
		_tutorial.on_event("fire")

func _on_ball_lost() -> void:
	# If the ball that was lost is a clone, just remove it
	if current_ball and current_ball.is_clone:
		current_ball.queue_free()
		return

	state = State.BALL_LOST
	var hit_any := _combo_count > 0
	var was_fever := FeverManager.is_fever_active
	FeverManager.on_ball_lost(hit_any)
	if was_fever:
		FeverManager.end_fever()
		# Fever gives a free ball refund
		balls_remaining += 1
		if _is_roguelite:
			RunState.add_balls(1)
		_spawn_score_popup("FEVER BALL!", Color(1.0, 0.85, 0.0), Vector2(640, 360))
	else:
		# Relic ball-lost hooks
		var lost_result := RelicManager.on_ball_lost(hit_any)
		if lost_result["refund_ball"]:
			balls_remaining += 1
			if _is_roguelite:
				RunState.add_balls(1)
			_spawn_score_popup("SAVED!", Color(0.3, 1.0, 0.5), Vector2(640, 360))
	_combo_count = 0
	_hit_streak_positions.clear()
	_near_miss_pegs.clear()
	if current_ball:
		current_ball.queue_free()
		current_ball = null
	_active_gravity_wells.clear()
	_remove_hit_pegs()

	await get_tree().create_timer(0.3).timeout

	if orange_pegs_remaining <= 0:
		_on_board_cleared()
	elif balls_remaining <= 0:
		AudioManager.play_sfx("ball_lost")
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
	# Ensure time scale is normal
	Engine.time_scale = 1.0
	_last_peg_slowmo = false
	_last_peg_zoom_progress = 0.0
	AudioManager.play_sfx("level_complete")
	_celebrate_clear()
	# Score tally overlay
	_score_tally_items = [
		{"label": "BOARD CLEARED!", "value": "", "delay": 0.0},
		{"label": "Pegs Hit", "value": str(orange_pegs_total), "delay": 0.3},
		{"label": "Board Score", "value": str(_board_score), "delay": 0.6},
		{"label": "Balls Left", "value": str(balls_remaining), "delay": 0.9},
	]
	if _combo_count > 0:
		_score_tally_items.append({"label": "Best Combo", "value": "x%d" % _combo_count, "delay": 1.2})
	_score_tally_time = 0.0
	_showing_tally = true
	await get_tree().create_timer(2.5).timeout
	_showing_tally = false

	if _is_roguelite:
		# Apply relic board clear bonuses
		var clear_result := RelicManager.on_board_clear()
		if clear_result["coin_bonus"] > 0:
			RunState.add_coins(clear_result["coin_bonus"])
		if clear_result["ball_bonus"] > 0:
			RunState.add_balls(clear_result["ball_bonus"])

		var prev_act := RunState.current_act
		RunState.complete_board(orange_pegs_total, orange_pegs_total, _board_score)
		# Sync balls back (complete_board may have added refund)
		balls_remaining = RunState.balls_remaining
		if RunState.is_run_active:
			if RunState.current_act != prev_act:
				# New act — reset fever meter and show act intro
				FeverManager.on_new_act()
				SceneManager.go_to_act_intro(RunState.current_act)
			else:
				# Show relic reward screen after board clear
				SceneManager.go_to_relic_reward()
		else:
			# Run was won (act 3 boss cleared)
			SceneManager.go_to_run_results()
	else:
		SceneManager.go_to_results(score, orange_pegs_total, orange_pegs_total - orange_pegs_remaining, _balls_used)

func _on_out_of_balls() -> void:
	state = State.GAME_OVER
	Engine.time_scale = 1.0
	_last_peg_slowmo = false
	_last_peg_zoom_progress = 0.0
	AudioManager.play_sfx("game_over")
	await get_tree().create_timer(1.0).timeout

	if _is_roguelite:
		var orange_cleared := orange_pegs_total - orange_pegs_remaining
		RunState.complete_board(orange_pegs_total, orange_cleared, _board_score)
		RunState.end_run(false)
		SceneManager.go_to_run_results()
	else:
		SceneManager.go_to_results(score, orange_pegs_total, orange_pegs_total - orange_pegs_remaining, _balls_used)

func _on_ball_caught() -> void:
	AudioManager.play_sfx("ball_catch")
	balls_remaining += 1
	if _is_roguelite:
		RunState.add_balls(1)
		RunState.on_bucket_catch()
	var catch_result := RelicManager.on_ball_caught()
	if catch_result["score_bonus"] > 0:
		_add_score(catch_result["score_bonus"])
	_update_hud()
	_spawn_score_popup("+1 BALL!", Color(0.3, 1.0, 0.5), bucket.global_position + Vector2(0, -30))
	# Bucket catch sparkle burst
	for i in range(12):
		var spark := _CelebrationSpark.new()
		spark._angle = TAU * float(i) / 12.0 + randf() * 0.2
		spark._speed = randf_range(80, 200)
		spark._color = Color(0.3, 1.0, 0.5)
		spark._lifetime = 0.6
		spark.global_position = bucket.global_position
		add_child(spark)

func _on_peg_hit(peg: Node) -> void:
	var peg_type: String = peg.get_peg_type()
	var special: String = peg.get_special_type() if peg.has_method("get_special_type") else ""

	_combo_count += 1

	# Audio
	AudioManager.play_peg_hit(peg_type)

	# Fever system
	FeverManager.on_peg_hit(peg_type)

	# Apply score multiplier from ball
	var multiplier := 1.0
	if current_ball and current_ball.score_multiplier > 1.0:
		multiplier = current_ball.score_multiplier

	var points := int(float(GameConfig.PEG_SCORES.get(peg_type, 0)) * multiplier)
	# Board mod: score multiplier bonus
	if _board_mods.has("score_multiplier"):
		points = int(float(points) * (1.0 + float(_board_mods["score_multiplier"])))
	# Board mod: extra score per orange
	if peg_type == "orange" and RunState.permanent_orange_score_bonus > 0:
		points += RunState.permanent_orange_score_bonus
	# Relic bonuses
	var relic_result := RelicManager.on_peg_hit(peg_type, _combo_count, peg)
	points += relic_result["score_bonus"]
	if relic_result["coin_bonus"] > 0:
		RunState.add_coins(relic_result["coin_bonus"])
	# Relic: combo_breaker triggers mini-bomb
	if relic_result["trigger_bomb"]:
		_effect_bomb(peg)
	# During fever: multiplier from relics
	if FeverManager.is_fever_active:
		points *= RelicManager.get_fever_multiplier()
	_add_score(points)

	# Boss HP damage — orange pegs damage the boss
	if _boss_data and peg_type == "orange":
		_boss_hp = maxi(0, _boss_hp - points)
		_check_boss_phases()
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
		"bomb":
			_effect_bomb(peg)
			AudioManager.play_sfx("bomb_explode")
		"chain":
			_effect_chain(peg)
			AudioManager.play_sfx("chain_zap")
		"multiplier": _effect_multiplier()
		"gravity":
			_effect_gravity(peg)
			AudioManager.play_sfx("gravity_well")

	# Overload power-up: mega bomb on next peg hit
	if current_ball and current_ball.overload_pending:
		current_ball.overload_pending = false
		var center: Vector2 = peg.global_position
		for other in pegs_container.get_children():
			if other == peg or not other.has_method("hit") or other.is_hit():
				continue
			if center.distance_to(other.global_position) <= GameConfig.BOMB_RADIUS * 3.0:
				other.hit()

	# Power-up activation from green pegs
	if "power_up_type" in peg:
		var pu: String = peg.power_up_type
		if pu != "" and current_ball:
			PowerUpManager.activate(pu, current_ball)
			match pu:
				"prism_split": AudioManager.play_sfx("powerup_prism")
				"overdrive": AudioManager.play_sfx("powerup_overdrive")
				"phantom_pass": AudioManager.play_sfx("powerup_phantom")
				"overload": AudioManager.play_sfx("powerup_overload")

func _effect_bomb(peg: Node2D) -> void:
	var center := peg.global_position
	var radius := GameConfig.BOMB_RADIUS * RelicManager.get_bomb_radius_multiplier()
	for other in pegs_container.get_children():
		if other == peg or not other.has_method("hit"):
			continue
		if other.is_hit():
			continue
		if center.distance_to(other.global_position) <= radius:
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
	var targets := mini(GameConfig.CHAIN_MAX_TARGETS + RelicManager.get_chain_extra_targets(), candidates.size())
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

func _on_fever_triggered() -> void:
	_flash_alpha = 0.3
	_flash_color = Color(1.0, 0.85, 0.0)  # Gold flash
	_shake_amount = 5.0
	AudioManager.play_sfx("fever_trigger")

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
	# Last peg slow-mo: when 1 orange remains, slow time and zoom
	if orange_pegs_remaining == 1 and not _last_peg_slowmo:
		_last_peg_slowmo = true
		Engine.time_scale = 0.3
		# Find the last orange peg for zoom target
		for peg in pegs_container.get_children():
			if peg.has_method("get_peg_type") and peg.get_peg_type() == "orange" and not peg.is_hit():
				_last_peg_zoom_target = peg.global_position
				break
	elif orange_pegs_remaining == 0 and _last_peg_slowmo:
		_last_peg_slowmo = false
		_last_peg_zoom_progress = 0.0
		Engine.time_scale = 1.0

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
