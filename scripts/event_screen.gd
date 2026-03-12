extends Node2D

## Event encounter screen — displays an event, choices, and applies outcomes.

var _event: EventData
var _pulse := 0.0
var _state: int = 0  # 0=choosing, 1=showing outcome, 2=transitioning
var _choice_rects: Array = []  # Array of Rect2
var _choice_scales: Array = []  # parallel array of floats (1.0 = normal)
var _hover_choice := -1
var _outcome_text := ""
var _outcome_timer := 0.0
var _chosen_index := -1

const OUTCOME_DISPLAY_TIME := 2.0

# Colors
const TITLE_COLOR := Color(0.8, 0.3, 1.0)
const DESC_COLOR := Color(0.6, 0.7, 0.85)
const CHOICE_COLOR := Color(0.3, 0.85, 1.0)
const CHOICE_HOVER_COLOR := Color(0.5, 1.0, 1.0)
const OUTCOME_GOOD_COLOR := Color(0.3, 1.0, 0.5)
const OUTCOME_BAD_COLOR := Color(1.0, 0.4, 0.3)
const OUTCOME_NEUTRAL_COLOR := Color(0.7, 0.7, 0.8)
const BORDER_COLOR := Color(0.8, 0.3, 1.0)

@onready var background := $Background

func _ready() -> void:
	_pick_event()
	_build_choice_rects()

func _pick_event() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = RunState.run_seed + RunState.route_position * 37 + RunState.current_act * 7
	_event = EventCatalog.get_random_event(RunState.current_act, rng)

func _process(delta: float) -> void:
	_pulse += delta * 2.5
	match _state:
		0:
			_update_hover()
			# Lerp choice scales toward target
			for i in range(_choice_scales.size()):
				var target := 1.04 if i == _hover_choice else 1.0
				_choice_scales[i] = lerpf(_choice_scales[i], target, clampf(delta * 12.0, 0.0, 1.0))
		1:
			_outcome_timer += delta
			if _outcome_timer >= OUTCOME_DISPLAY_TIME:
				_state = 2
				SceneManager.go_to_route_map()
	queue_redraw()

func _build_choice_rects() -> void:
	_choice_rects.clear()
	_choice_scales.clear()
	if not _event:
		return
	var vp := GameConfig.VIEWPORT_SIZE
	var choice_count := _event.choices.size()
	var btn_width := 500.0
	var btn_height := 50.0
	var spacing := 16.0
	var total_h := float(choice_count) * btn_height + float(choice_count - 1) * spacing
	var start_y := 420.0
	var start_x := (vp.x - btn_width) / 2.0

	for i in range(choice_count):
		var y := start_y + float(i) * (btn_height + spacing)
		_choice_rects.append(Rect2(start_x, y, btn_width, btn_height))
		_choice_scales.append(1.0)

func _update_hover() -> void:
	var mouse := get_global_mouse_position()
	_hover_choice = -1
	for i in range(_choice_rects.size()):
		if _choice_rects[i].has_point(mouse):
			_hover_choice = i
			break

func _input(event: InputEvent) -> void:
	if _state != 0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_pos: Vector2 = event.position
		var clicked := -1
		for i in range(_choice_rects.size()):
			if _choice_rects[i].has_point(click_pos):
				clicked = i
				break
		if clicked < 0:
			clicked = _hover_choice
		if clicked >= 0:
			_select_choice(clicked)

func _select_choice(index: int) -> void:
	_chosen_index = index
	var choice: Dictionary = _event.choices[index]
	var outcomes: Dictionary = choice.get("outcomes", {})
	var probability: float = choice.get("probability", 1.0)

	# Roll probability
	var rng := RandomNumberGenerator.new()
	rng.seed = RunState.run_seed + index * 13 + RunState.route_position * 71
	var roll := rng.randf()

	if roll <= probability:
		# Success
		_outcome_text = _apply_outcomes(outcomes, true)
	else:
		# Failure (for probability-based choices)
		if outcomes.has("balls_risk"):
			# On failure for Warden's Challenge, lose the ball
			RunState.add_balls(outcomes["balls_risk"])
			_outcome_text = "Failed! Lost %d ball(s)." % absi(outcomes["balls_risk"])
		else:
			_outcome_text = "Nothing happens."

	_state = 1
	_outcome_timer = 0.0

func _apply_outcomes(outcomes: Dictionary, success: bool) -> String:
	var parts: Array[String] = []

	if outcomes.has("balls"):
		var amount: int = outcomes["balls"]
		RunState.add_balls(amount)
		if amount > 0:
			parts.append("+%d ball(s)" % amount)
		elif amount < 0:
			parts.append("-%d ball(s)" % absi(amount))

	if outcomes.has("coins"):
		var amount: int = outcomes["coins"]
		RunState.add_coins(amount)
		if amount > 0:
			parts.append("+%d coins" % amount)
		elif amount < 0:
			parts.append("-%d coins" % absi(amount))

	if outcomes.has("coins_random"):
		var range_arr: Array = outcomes["coins_random"]
		var rng := RandomNumberGenerator.new()
		rng.seed = RunState.run_seed + _chosen_index * 23
		var amount := rng.randi_range(int(range_arr[0]), int(range_arr[1]))
		RunState.add_coins(amount)
		parts.append("+%d coins" % amount)

	if outcomes.has("score_bonus"):
		var amount: int = outcomes["score_bonus"]
		RunState.add_score(amount)
		parts.append("+%d score" % amount)

	if outcomes.has("permanent_coin_bonus"):
		var amount: int = outcomes["permanent_coin_bonus"]
		RunState.permanent_coin_bonus += amount
		parts.append("+%d coin per peg (permanent)" % amount)

	if outcomes.has("permanent_orange_score_bonus"):
		var amount: int = outcomes["permanent_orange_score_bonus"]
		RunState.permanent_orange_score_bonus += amount
		parts.append("+%d score per orange (permanent)" % amount)

	if outcomes.has("next_board_mods"):
		var mods: Dictionary = outcomes["next_board_mods"]
		for key in mods:
			RunState.next_board_mods[key] = mods[key]
		parts.append("Board modifier applied!")

	if parts.is_empty():
		return "Nothing happens."
	return ", ".join(parts)

func _draw() -> void:
	if not _event:
		return
	var font := ThemeDB.fallback_font
	var vp := GameConfig.VIEWPORT_SIZE
	var cx := vp.x / 2.0
	var pulse := sin(_pulse) * 0.15 + 0.85

	# Event frame border
	var frame := Rect2(80, 80, vp.x - 160, vp.y - 160)
	_draw_neon_border(frame, BORDER_COLOR, pulse)

	# Inner glow
	draw_rect(frame.grow(-2), Color(BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.02 * pulse), true)

	# "EVENT" header label
	var header := "// EVENT"
	var header_size := font.get_string_size(header, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(font, Vector2(frame.position.x + 10, frame.position.y - 6), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.5))

	# Title
	var title_size := font.get_string_size(_event.title, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	draw_string(font, Vector2(cx - title_size.x / 2.0, 140), _event.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b, pulse))

	# Decorative line under title
	var line_half := 120.0
	draw_line(Vector2(cx - line_half, 155), Vector2(cx + line_half, 155), Color(TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b, 0.3 * pulse), 1.0)

	# Description (word-wrapped manually)
	_draw_wrapped_text(font, _event.description, Vector2(160, 190), vp.x - 320, 16, DESC_COLOR)

	# Choices
	if _state == 0:
		for i in range(_choice_rects.size()):
			var base_rect: Rect2 = _choice_rects[i]
			var choice: Dictionary = _event.choices[i]
			var is_hovered := i == _hover_choice
			var c := CHOICE_HOVER_COLOR if is_hovered else CHOICE_COLOR
			var alpha := 0.9 if is_hovered else 0.6

			# Scale rect from center
			var sc: float = _choice_scales[i] if i < _choice_scales.size() else 1.0
			var grow_amount := (sc - 1.0) * base_rect.size.x * 0.5
			var rect := base_rect.grow(grow_amount)

			# Choice border
			_draw_neon_border(rect, c, alpha)

			# Hover fill
			if is_hovered:
				draw_rect(rect, Color(c.r, c.g, c.b, 0.06), true)

			# Choice letter prefix
			var prefix: String = ["A", "B", "C"][i] + ": "
			var text: String = prefix + choice["text"]

			# Probability hint
			var prob: float = choice.get("probability", 1.0)
			if prob < 1.0:
				text += " (%d%% chance)" % int(prob * 100.0)

			# Cost hint
			var outcomes: Dictionary = choice.get("outcomes", {})
			var cost_parts: Array[String] = []
			if outcomes.has("coins") and outcomes["coins"] < 0:
				cost_parts.append("costs %d coins" % absi(outcomes["coins"]))
			if outcomes.has("balls") and outcomes["balls"] < 0:
				cost_parts.append("costs %d ball(s)" % absi(outcomes["balls"]))
			if not cost_parts.is_empty():
				text += " [" + ", ".join(cost_parts) + "]"

			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			var text_pos := Vector2(
				rect.position.x + (rect.size.x - text_size.x) / 2.0,
				rect.position.y + rect.size.y / 2.0 + 5.0
			)
			draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(c.r, c.g, c.b, alpha * pulse))

	# Outcome display
	if _state >= 1:
		# Highlight chosen
		if _chosen_index >= 0 and _chosen_index < _choice_rects.size():
			var rect: Rect2 = _choice_rects[_chosen_index]
			draw_rect(rect, Color(CHOICE_COLOR.r, CHOICE_COLOR.g, CHOICE_COLOR.b, 0.08), true)
			_draw_neon_border(rect, CHOICE_COLOR, 0.9)
			var choice: Dictionary = _event.choices[_chosen_index]
			var text: String = _event.choices[_chosen_index]["text"]
			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			var text_pos := Vector2(
				rect.position.x + (rect.size.x - text_size.x) / 2.0,
				rect.position.y + rect.size.y / 2.0 + 5.0
			)
			draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(CHOICE_COLOR.r, CHOICE_COLOR.g, CHOICE_COLOR.b, 0.9))

		# Outcome text
		var outcome_y := 600.0
		var oc := OUTCOME_GOOD_COLOR if _outcome_text.begins_with("+") or _outcome_text.contains("+") else OUTCOME_NEUTRAL_COLOR
		if _outcome_text.begins_with("Failed") or _outcome_text.begins_with("Nothing"):
			oc = OUTCOME_BAD_COLOR if _outcome_text.begins_with("Failed") else OUTCOME_NEUTRAL_COLOR
		var ot_size := font.get_string_size(_outcome_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
		var fade := minf(_outcome_timer / 0.3, 1.0)
		draw_string(font, Vector2(cx - ot_size.x / 2.0, outcome_y), _outcome_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(oc.r, oc.g, oc.b, fade * pulse))

	# Stats bar at bottom
	var stats := "Balls: %d  |  Coins: %d  |  Score: %d" % [RunState.balls_remaining, RunState.coins, RunState.score]
	var stats_size := font.get_string_size(stats, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(font, Vector2(cx - stats_size.x / 2.0, vp.y - 40), stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.8, 1.0, 0.7))

func _draw_neon_border(rect: Rect2, color: Color, alpha: float) -> void:
	var points := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
		rect.position,
	])
	draw_polyline(points, Color(color.r, color.g, color.b, alpha), 1.5)
	# Outer glow
	draw_polyline(points, Color(color.r, color.g, color.b, alpha * 0.15), 4.0)

func _draw_wrapped_text(font: Font, text: String, pos: Vector2, max_width: float, font_size: int, color: Color) -> void:
	var words := text.split(" ")
	var line := ""
	var y := pos.y
	var line_height := float(font_size) * 1.5

	for word in words:
		var test := line + (" " if not line.is_empty() else "") + word
		var test_size := font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if test_size.x > max_width and not line.is_empty():
			draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			line = word
			y += line_height
		else:
			line = test
	if not line.is_empty():
		draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
