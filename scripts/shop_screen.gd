extends Node2D

var _items: Array[Dictionary] = []
var _item_rects: Array[Rect2] = []
var _hover_index := -1
var _pulse := 0.0
var _entrance_time := 0.0
var _reroll_rect := Rect2()
var _leave_rect := Rect2()
var _reroll_cost := 10

const REROLL_COST_BASE := 10

@onready var background := $Background

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = RunState.run_seed + RunState.route_position * 97 + RunState.current_act * 13
	var exclude := RelicManager.get_active_ids()
	_items = ShopCatalog.generate_shop_items(rng, exclude)
	_build_rects()

func _build_rects() -> void:
	_item_rects.clear()
	var vp := GameConfig.VIEWPORT_SIZE
	var card_w := 260.0
	var card_h := 160.0
	var spacing := 20.0
	var total_w := float(_items.size()) * card_w + float(_items.size() - 1) * spacing
	var start_x := (vp.x - total_w) / 2.0
	var y := 220.0
	for i in range(_items.size()):
		var x := start_x + float(i) * (card_w + spacing)
		_item_rects.append(Rect2(x, y, card_w, card_h))
	# Reroll button
	_reroll_rect = Rect2(vp.x / 2.0 - 80, 440, 160, 40)
	# Leave button
	_leave_rect = Rect2(vp.x / 2.0 - 80, 500, 160, 40)

func _process(delta: float) -> void:
	_pulse += delta * 2.5
	_entrance_time += delta
	_update_hover()
	queue_redraw()

func _update_hover() -> void:
	var mouse := get_global_mouse_position()
	_hover_index = -1
	for i in range(_item_rects.size()):
		if _item_rects[i].has_point(mouse):
			_hover_index = i
			break
	# Check reroll/leave hover
	if _reroll_rect.has_point(mouse):
		_hover_index = -2  # reroll
	elif _leave_rect.has_point(mouse):
		_hover_index = -3  # leave

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_pos: Vector2 = event.position
		# Check items
		for i in range(_item_rects.size()):
			if _item_rects[i].has_point(click_pos):
				_try_buy(i)
				return
		# Check reroll
		if _reroll_rect.has_point(click_pos):
			_try_reroll()
			return
		# Check leave
		if _leave_rect.has_point(click_pos):
			SceneManager.go_to_route_map()
			return

func _try_buy(index: int) -> void:
	if index >= _items.size():
		return
	var item: Dictionary = _items[index]
	var cost: int = item["cost"]
	if RunState.coins < cost:
		return
	RunState.add_coins(-cost)
	AudioManager.play_sfx("shop_buy")
	# Apply item
	match item["type"]:
		"balls", "heal":
			RunState.add_balls(item["amount"])
		"relic":
			RelicManager.add_relic(item["relic"])
		"score_bonus":
			RunState.add_score(item["amount"])
		"permanent_coin":
			RunState.permanent_coin_bonus += item["amount"]
		"permanent_orange":
			RunState.permanent_orange_score_bonus += item["amount"]
	# Remove bought item
	_items.remove_at(index)
	_build_rects()

func _try_reroll() -> void:
	if RunState.coins < _reroll_cost:
		return
	RunState.add_coins(-_reroll_cost)
	AudioManager.play_sfx("shop_reroll")
	_reroll_cost += 5  # Escalating cost
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var exclude := RelicManager.get_active_ids()
	_items = ShopCatalog.generate_shop_items(rng, exclude)
	_build_rects()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := GameConfig.VIEWPORT_SIZE
	var cx := vp.x / 2.0
	var pulse := sin(_pulse) * 0.15 + 0.85

	# Title
	var title := "SHOP"
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 36)
	draw_string(font, Vector2(cx - title_size.x / 2.0, 60), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1.0, 0.85, 0.3, pulse))

	# Coins display
	var coins_text := "Coins: %d" % RunState.coins
	var coins_size := font.get_string_size(coins_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
	draw_string(font, Vector2(cx - coins_size.x / 2.0, 95), coins_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.85, 0.3, 0.8))

	# Draw item cards
	for i in range(_items.size()):
		var item: Dictionary = _items[i]
		var rect: Rect2 = _item_rects[i]
		var is_hovered := i == _hover_index
		var can_afford := RunState.coins >= item["cost"]
		var c: Color = item.get("rarity_color", Color(0.5, 0.7, 1.0))
		if not can_afford:
			c = Color(0.4, 0.4, 0.5)
		var alpha := 0.8 if is_hovered else 0.5
		var card_entrance := clampf((_entrance_time - 0.2 - float(i) * 0.08) / 0.25, 0.0, 1.0)
		if card_entrance <= 0.0:
			continue
		alpha *= card_entrance

		if is_hovered and can_afford:
			draw_rect(rect, Color(c.r, c.g, c.b, 0.06), true)

		var border := PackedVector2Array([
			rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y), rect.position
		])
		draw_polyline(border, Color(c.r, c.g, c.b, alpha * pulse), 1.5)

		# Item name
		var name_text: String = item["name"]
		var name_size := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		draw_string(font, Vector2(rect.position.x + (rect.size.x - name_size.x) / 2.0, rect.position.y + 30), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(c.r, c.g, c.b, alpha * pulse))

		# Description
		var desc: String = item["description"]
		var desc_size := font.get_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(font, Vector2(rect.position.x + (rect.size.x - desc_size.x) / 2.0, rect.position.y + 60), desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.7, 0.85, 0.7 * card_entrance))

		# Cost
		var cost_text := "%d coins" % item["cost"]
		var cost_color := Color(1.0, 0.85, 0.3) if can_afford else Color(1.0, 0.3, 0.3)
		var cost_size := font.get_string_size(cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(font, Vector2(rect.position.x + (rect.size.x - cost_size.x) / 2.0, rect.position.y + 130), cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(cost_color.r, cost_color.g, cost_color.b, alpha * pulse))

	# Reroll button
	var reroll_hovered := _hover_index == -2
	var can_reroll := RunState.coins >= _reroll_cost
	var reroll_c := Color(0.3, 0.85, 1.0) if can_reroll else Color(0.4, 0.4, 0.5)
	var reroll_alpha := 0.8 if reroll_hovered and can_reroll else 0.5
	_draw_button(_reroll_rect, "Reroll (%d coins)" % _reroll_cost, reroll_c, reroll_alpha, pulse, font)

	# Leave button
	var leave_hovered := _hover_index == -3
	var leave_alpha := 0.8 if leave_hovered else 0.5
	_draw_button(_leave_rect, "Leave Shop", Color(0.5, 0.7, 0.8), leave_alpha, pulse, font)

	# Stats bar
	var stats := "Balls: %d  |  Score: %d  |  Relics: %d" % [RunState.balls_remaining, RunState.score, RelicManager.active_relics.size()]
	var stats_size := font.get_string_size(stats, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(font, Vector2(cx - stats_size.x / 2.0, vp.y - 40), stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.8, 1.0, 0.7))

func _draw_button(rect: Rect2, text: String, color: Color, alpha: float, pulse: float, font: Font) -> void:
	var border := PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y), rect.position
	])
	draw_polyline(border, Color(color.r, color.g, color.b, alpha * pulse), 1.5)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, Vector2(rect.position.x + (rect.size.x - text_size.x) / 2.0, rect.position.y + rect.size.y / 2.0 + 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(color.r, color.g, color.b, alpha * pulse))
