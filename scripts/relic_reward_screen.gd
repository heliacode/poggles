extends Node2D

var _relics: Array[RelicData] = []
var _relic_rects: Array[Rect2] = []
var _hover_index := -1
var _pulse := 0.0
var _entrance_time := 0.0
var _chosen := false

@onready var background := $Background

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = RunState.run_seed + RunState.total_boards_cleared * 53
	var exclude := RelicManager.get_active_ids()
	var guaranteed_rare := RunState.is_boss_board()
	_relics = RelicCatalog.get_weighted_random_relics(3, exclude, guaranteed_rare, rng)
	_build_rects()

func _build_rects() -> void:
	_relic_rects.clear()
	var vp := GameConfig.VIEWPORT_SIZE
	var card_w := 300.0
	var card_h := 180.0
	var spacing := 30.0
	var total_w := float(_relics.size()) * card_w + float(_relics.size() - 1) * spacing
	var start_x := (vp.x - total_w) / 2.0
	var y := 280.0
	for i in range(_relics.size()):
		var x := start_x + float(i) * (card_w + spacing)
		_relic_rects.append(Rect2(x, y, card_w, card_h))

func _process(delta: float) -> void:
	_pulse += delta * 2.5
	_entrance_time += delta
	if not _chosen:
		_update_hover()
	queue_redraw()

func _update_hover() -> void:
	var mouse := get_global_mouse_position()
	_hover_index = -1
	for i in range(_relic_rects.size()):
		if _relic_rects[i].has_point(mouse):
			_hover_index = i
			break

func _input(event: InputEvent) -> void:
	if _chosen:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_pos: Vector2 = event.position
		var clicked := -1
		for i in range(_relic_rects.size()):
			if _relic_rects[i].has_point(click_pos):
				clicked = i
				break
		if clicked < 0:
			clicked = _hover_index
		if clicked >= 0 and clicked < _relics.size():
			_chosen = true
			RelicManager.add_relic(_relics[clicked])
			await get_tree().create_timer(0.8).timeout
			SceneManager.go_to_route_map()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := GameConfig.VIEWPORT_SIZE
	var cx := vp.x / 2.0
	var pulse := sin(_pulse) * 0.15 + 0.85

	# Title
	var title := "CHOOSE A RELIC"
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
	var title_alpha := minf(_entrance_time / 0.4, 1.0)
	draw_string(font, Vector2(cx - title_size.x / 2.0, 100), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.8, 0.3, 1.0, pulse * title_alpha))

	# Subtitle
	var sub := "Relics persist for the entire run"
	var sub_size := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(font, Vector2(cx - sub_size.x / 2.0, 130), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.6, 0.8, 0.5 * title_alpha))

	# Draw relic cards
	for i in range(_relics.size()):
		var relic := _relics[i]
		var rect := _relic_rects[i]
		var is_hovered := i == _hover_index and not _chosen
		var card_entrance := clampf((_entrance_time - 0.3 - float(i) * 0.1) / 0.3, 0.0, 1.0)
		if card_entrance <= 0.0:
			continue

		var c := relic.get_rarity_color()
		var alpha := 0.8 if is_hovered else 0.5
		alpha *= card_entrance

		# Card background
		if is_hovered:
			draw_rect(rect, Color(c.r, c.g, c.b, 0.06), true)

		# Card border
		var border := PackedVector2Array([
			rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y), rect.position
		])
		draw_polyline(border, Color(c.r, c.g, c.b, alpha * pulse), 2.0 if is_hovered else 1.5)
		draw_polyline(border, Color(c.r, c.g, c.b, alpha * 0.15), 5.0)

		# Relic icon (drawn procedurally based on rarity)
		var icon_center := Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y + 50.0)
		_draw_relic_icon(icon_center, c, relic.rarity, pulse * card_entrance)

		# Rarity label
		var rarity_text := relic.rarity.to_upper()
		var rarity_size := font.get_string_size(rarity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		draw_string(font, Vector2(rect.position.x + (rect.size.x - rarity_size.x) / 2.0, rect.position.y + 85), rarity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(c.r, c.g, c.b, 0.6 * card_entrance))

		# Name
		var name_size := font.get_string_size(relic.relic_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		draw_string(font, Vector2(rect.position.x + (rect.size.x - name_size.x) / 2.0, rect.position.y + 115), relic.relic_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(c.r, c.g, c.b, alpha * pulse))

		# Description (word-wrapped)
		_draw_wrapped(font, relic.description, Vector2(rect.position.x + 12, rect.position.y + 135), rect.size.x - 24, 12, Color(0.6, 0.7, 0.85, 0.7 * card_entrance))

	# Stats bar
	var stats := "Balls: %d  |  Coins: %d  |  Relics: %d" % [RunState.balls_remaining, RunState.coins, RelicManager.active_relics.size()]
	var stats_size := font.get_string_size(stats, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(font, Vector2(cx - stats_size.x / 2.0, vp.y - 40), stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.8, 1.0, 0.7))

func _draw_relic_icon(center: Vector2, color: Color, rarity: String, alpha: float) -> void:
	match rarity:
		"common":
			draw_arc(center, 15.0, 0, TAU, 32, Color(color.r, color.g, color.b, alpha * 0.8), 2.0, true)
			draw_circle(center, 5.0, Color(color.r, color.g, color.b, alpha * 0.5))
		"uncommon":
			for i in range(6):
				var angle := TAU * float(i) / 6.0 + _pulse * 0.3
				var p := center + Vector2.from_angle(angle) * 15.0
				draw_circle(p, 3.0, Color(color.r, color.g, color.b, alpha * 0.6))
			draw_arc(center, 15.0, 0, TAU, 32, Color(color.r, color.g, color.b, alpha * 0.4), 1.0, true)
		"rare":
			var pts := PackedVector2Array()
			for i in range(5):
				var angle := TAU * float(i) / 5.0 - PI / 2.0 + _pulse * 0.2
				pts.append(center + Vector2.from_angle(angle) * 18.0)
				var inner_angle := angle + TAU / 10.0
				pts.append(center + Vector2.from_angle(inner_angle) * 8.0)
			pts.append(pts[0])
			draw_polyline(pts, Color(color.r, color.g, color.b, alpha * 0.8), 2.0)
		"legendary":
			for ring in range(3):
				var r := 8.0 + float(ring) * 6.0
				draw_arc(center, r, _pulse * (0.5 + float(ring) * 0.2), _pulse * (0.5 + float(ring) * 0.2) + TAU * 0.7, 24, Color(color.r, color.g, color.b, alpha * (0.8 - float(ring) * 0.2)), 2.0, true)
			draw_circle(center, 4.0, Color(color.r, color.g, color.b, alpha))

func _draw_wrapped(font: Font, text: String, pos: Vector2, max_width: float, font_size: int, color: Color) -> void:
	var words := text.split(" ")
	var line := ""
	var y := pos.y
	var line_height := float(font_size) * 1.4
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
