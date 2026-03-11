extends Node2D

var _pulse := 0.0
var _entrance_time := 0.0
var _unlock_nodes: Array[Dictionary] = []
var _hover_index := -1
var _scroll_offset := 0.0

@onready var background := $Background

func _ready() -> void:
	_build_unlock_tree()

func _build_unlock_tree() -> void:
	_unlock_nodes.clear()
	var vp := GameConfig.VIEWPORT_SIZE
	var start_x := 160.0
	var start_y := 140.0
	var col_spacing := 220.0
	var row_spacing := 90.0

	# Relics to unlock (15 additional relics)
	var relic_unlocks := [
		{"id": "unlock_relic_1", "name": "Unlock: Iron Ball", "cost": 100, "type": "relic", "relic_id": "iron_ball"},
		{"id": "unlock_relic_2", "name": "Unlock: Echo Peg", "cost": 150, "type": "relic", "relic_id": "echo_peg"},
		{"id": "unlock_relic_3", "name": "Unlock: Magnet Core", "cost": 200, "type": "relic", "relic_id": "magnet_core"},
		{"id": "unlock_relic_4", "name": "Unlock: Glass Cannon", "cost": 250, "type": "relic", "relic_id": "glass_cannon"},
		{"id": "unlock_relic_5", "name": "Unlock: Void Heart", "cost": 500, "type": "relic", "relic_id": "void_heart"},
	]

	# Power-up unlocks
	var powerup_unlocks := [
		{"id": "unlock_gravity_flip", "name": "Unlock: Gravity Flip", "cost": 300, "type": "powerup"},
		{"id": "unlock_sniper", "name": "Unlock: Sniper", "cost": 300, "type": "powerup"},
	]

	# Ascension unlocks
	var ascension_unlocks: Array[Dictionary] = []
	for i in range(10):
		ascension_unlocks.append({"id": "ascension_%d" % (i + 1), "name": "Ascension %d" % (i + 1), "cost": 200 + i * 100, "type": "ascension", "level": i + 1})

	# Cosmetic unlocks
	var cosmetic_unlocks := [
		{"id": "trail_fire", "name": "Fire Trail", "cost": 150, "type": "cosmetic"},
		{"id": "trail_ice", "name": "Ice Trail", "cost": 150, "type": "cosmetic"},
		{"id": "trail_void", "name": "Void Trail", "cost": 200, "type": "cosmetic"},
	]

	var all_unlocks: Array = []
	all_unlocks.append_array(relic_unlocks)
	all_unlocks.append_array(powerup_unlocks)
	all_unlocks.append_array(ascension_unlocks)
	all_unlocks.append_array(cosmetic_unlocks)

	var cols := 5
	for i in range(all_unlocks.size()):
		var col := i % cols
		var row := i / cols
		var x := start_x + float(col) * col_spacing
		var y := start_y + float(row) * row_spacing
		var node: Dictionary = all_unlocks[i]
		node["rect"] = Rect2(x, y, 200, 70)
		node["unlocked"] = SaveData.is_unlocked(node["id"])
		_unlock_nodes.append(node)

func _process(delta: float) -> void:
	_pulse += delta * 2.5
	_entrance_time += delta
	_update_hover()
	queue_redraw()

func _update_hover() -> void:
	var mouse := get_global_mouse_position()
	_hover_index = -1
	for i in range(_unlock_nodes.size()):
		var node: Dictionary = _unlock_nodes[i]
		var rect: Rect2 = node["rect"]
		var adj_rect := Rect2(rect.position + Vector2(0, -_scroll_offset), rect.size)
		if adj_rect.has_point(mouse):
			_hover_index = i
			break

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _hover_index >= 0:
				_try_unlock(_hover_index)
			# Check back button
			var back_rect := Rect2(20, 20, 100, 40)
			if back_rect.has_point(event.position):
				SceneManager.go_to_main_menu()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_offset = maxf(0, _scroll_offset - 40)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_offset += 40

func _try_unlock(index: int) -> void:
	var node: Dictionary = _unlock_nodes[index]
	if node["unlocked"]:
		return
	var cost: int = node["cost"]
	if SaveData.get_stardust() < cost:
		return
	SaveData.add_stardust(-cost)
	SaveData.unlock(node["id"])
	node["unlocked"] = true
	AudioManager.play_sfx("relic_acquire")

	# Apply ascension
	if node["type"] == "ascension":
		SaveData.set_ascension_level(node["level"])

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := GameConfig.VIEWPORT_SIZE
	var cx := vp.x / 2.0
	var pulse := sin(_pulse) * 0.15 + 0.85

	# Title
	var title := "STARDUST UNLOCKS"
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
	draw_string(font, Vector2(cx - title_size.x / 2.0, 45), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1.0, 0.85, 0.3, pulse))

	# Stardust display
	var dust_text := "Stardust: %d" % SaveData.get_stardust()
	var dust_size := font.get_string_size(dust_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
	draw_string(font, Vector2(cx - dust_size.x / 2.0, 75), dust_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.85, 0.3, 0.7))

	# Ascension display
	var asc := SaveData.get_ascension_level()
	if asc > 0:
		var asc_text := "Ascension: %d" % asc
		var asc_size := font.get_string_size(asc_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		draw_string(font, Vector2(cx - asc_size.x / 2.0, 100), asc_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.3, 1.0, 0.6))

	# Back button
	var back_rect := Rect2(20, 20, 100, 40)
	_draw_neon_button(back_rect, "< BACK", Color(0.5, 0.7, 1.0), 0.6, pulse, font)

	# Draw unlock nodes
	for i in range(_unlock_nodes.size()):
		var node: Dictionary = _unlock_nodes[i]
		var rect: Rect2 = node["rect"]
		var adj_rect := Rect2(rect.position + Vector2(0, -_scroll_offset), rect.size)
		if adj_rect.end.y < 100 or adj_rect.position.y > vp.y:
			continue
		var is_hovered := i == _hover_index
		var unlocked: bool = node["unlocked"]
		var can_afford := SaveData.get_stardust() >= node["cost"]

		var c: Color
		if unlocked:
			c = Color(0.3, 1.0, 0.5)
		elif can_afford:
			c = Color(1.0, 0.85, 0.3)
		else:
			c = Color(0.4, 0.4, 0.5)

		var alpha := 0.8 if is_hovered else 0.5
		if unlocked:
			alpha = 0.6

		# Border
		var border := PackedVector2Array([
			adj_rect.position, Vector2(adj_rect.end.x, adj_rect.position.y),
			adj_rect.end, Vector2(adj_rect.position.x, adj_rect.end.y), adj_rect.position
		])
		draw_polyline(border, Color(c.r, c.g, c.b, alpha * pulse), 1.5)

		if is_hovered and not unlocked and can_afford:
			draw_rect(adj_rect, Color(c.r, c.g, c.b, 0.05), true)

		# Name
		var name_text: String = node["name"]
		var name_size := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		draw_string(font, Vector2(adj_rect.position.x + (adj_rect.size.x - name_size.x) / 2.0, adj_rect.position.y + 25), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(c.r, c.g, c.b, alpha * pulse))

		# Cost or "UNLOCKED"
		var status_text: String
		if unlocked:
			status_text = "UNLOCKED"
		else:
			status_text = "%d stardust" % node["cost"]
		var status_size := font.get_string_size(status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var status_color := Color(0.3, 1.0, 0.5, 0.7) if unlocked else Color(c.r, c.g, c.b, 0.5)
		draw_string(font, Vector2(adj_rect.position.x + (adj_rect.size.x - status_size.x) / 2.0, adj_rect.position.y + 50), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, status_color)

	# Connection lines between nodes
	for i in range(_unlock_nodes.size() - 1):
		var a: Dictionary = _unlock_nodes[i]
		var b: Dictionary = _unlock_nodes[i + 1]
		var ar: Rect2 = a["rect"]
		var br: Rect2 = b["rect"]
		var a_center := Vector2(ar.end.x, ar.position.y + ar.size.y / 2.0 - _scroll_offset)
		var b_center := Vector2(br.position.x, br.position.y + br.size.y / 2.0 - _scroll_offset)
		if a_center.y > 100 and b_center.y < vp.y and (i + 1) % 5 != 0:
			draw_line(a_center, b_center, Color(0.3, 0.4, 0.6, 0.15), 1.0)

func _draw_neon_button(rect: Rect2, text: String, color: Color, alpha: float, pulse: float, font: Font) -> void:
	var border := PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y), rect.position
	])
	draw_polyline(border, Color(color.r, color.g, color.b, alpha * pulse), 1.5)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, Vector2(rect.position.x + (rect.size.x - text_size.x) / 2.0, rect.position.y + rect.size.y / 2.0 + 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(color.r, color.g, color.b, alpha * pulse))
