extends Node2D

## Character selection screen — procedural _draw() UI.

var _selected_index := 0
var _pulse := 0.0
var _time := 0.0
var _intro_time := 0.0

const CARD_WIDTH := 180.0
const CARD_HEIGHT := 240.0
const CARD_GAP := 20.0
const CARDS_Y := 280.0

func _ready() -> void:
	AudioManager.play_music("menu")
	# Pre-select current character
	var current := CharacterManager.selected_character
	for i in range(CharacterManager.CHARACTER_ORDER.size()):
		if CharacterManager.CHARACTER_ORDER[i] == current:
			_selected_index = i
			break

func _process(delta: float) -> void:
	_pulse += delta * 2.5
	_time += delta
	_intro_time = minf(_intro_time + delta, 1.5)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_selected_index = maxi(0, _selected_index - 1)
				AudioManager.play_sfx("peg_blue")
			KEY_RIGHT, KEY_D:
				_selected_index = mini(CharacterManager.CHARACTER_ORDER.size() - 1, _selected_index + 1)
				AudioManager.play_sfx("peg_blue")
			KEY_ENTER, KEY_SPACE:
				_confirm_selection()
			KEY_ESCAPE:
				SceneManager.go_to_main_menu()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse: Vector2 = event.position
		var card_idx := _get_card_at(mouse)
		if card_idx >= 0:
			if card_idx == _selected_index:
				_confirm_selection()
			else:
				_selected_index = card_idx
				AudioManager.play_sfx("peg_blue")

func _confirm_selection() -> void:
	var id: String = CharacterManager.CHARACTER_ORDER[_selected_index]
	if CharacterManager.is_unlocked(id):
		CharacterManager.select_character(id)
		AudioManager.play_sfx("level_complete")
		RunState.start_new_run()
		SceneManager.go_to_act_intro(RunState.current_act)
	else:
		# Try to unlock
		if CharacterManager.unlock_character(id):
			AudioManager.play_sfx("fever_trigger")
		else:
			AudioManager.play_sfx("ball_lost")

func _get_total_width() -> float:
	var count := CharacterManager.CHARACTER_ORDER.size()
	return float(count) * CARD_WIDTH + float(count - 1) * CARD_GAP

func _get_card_rect(index: int) -> Rect2:
	var total_w := _get_total_width()
	var start_x := (GameConfig.VIEWPORT_WIDTH - total_w) / 2.0
	var x := start_x + float(index) * (CARD_WIDTH + CARD_GAP)
	return Rect2(x, CARDS_Y, CARD_WIDTH, CARD_HEIGHT)

func _get_card_at(pos: Vector2) -> int:
	for i in range(CharacterManager.CHARACTER_ORDER.size()):
		if _get_card_rect(i).has_point(pos):
			return i
	return -1

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := GameConfig.VIEWPORT_SIZE
	var cx := vp.x / 2.0
	var pulse := sin(_pulse) * 0.15 + 0.85
	var intro_t := clampf(_intro_time / 0.5, 0.0, 1.0)
	var intro_ease := 1.0 - pow(1.0 - intro_t, 3.0)

	# Title
	var title := "CHOOSE YOUR VERTEX"
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 36)
	var title_color := Color(0.3, 1.0, 0.5)
	# Glow
	for i in range(2):
		var offset := float(i + 1) * 1.5
		var ga := 0.08 * pulse * intro_ease
		draw_string(font, Vector2(cx - title_size.x / 2.0 - offset, 80 - offset), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(title_color.r, title_color.g, title_color.b, ga))
	draw_string(font, Vector2(cx - title_size.x / 2.0, 80), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(title_color.r, title_color.g, title_color.b, pulse * intro_ease))

	# Stardust display
	var dust := SaveData.get_stardust()
	var dust_text := "Stardust: %d" % dust
	var dust_size := font.get_string_size(dust_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, Vector2(cx - dust_size.x / 2.0, 115), dust_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.85, 0.0, 0.6 * intro_ease))

	# Cards
	for i in range(CharacterManager.CHARACTER_ORDER.size()):
		var card_t := clampf((_intro_time - 0.2 - float(i) * 0.08) / 0.3, 0.0, 1.0)
		var card_ease := 1.0 - pow(1.0 - card_t, 3.0)
		_draw_card(i, pulse, card_ease)

	# Bottom hint
	var hint := "Arrow Keys / Click to Select  |  Enter to Confirm  |  ESC to Back"
	var hint_size := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	draw_string(font, Vector2(cx - hint_size.x / 2.0, 580), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.5, 0.7, 0.4 * intro_ease))

func _draw_card(index: int, pulse: float, card_ease: float) -> void:
	var font := ThemeDB.fallback_font
	var id: String = CharacterManager.CHARACTER_ORDER[index]
	var data: Dictionary = CharacterManager.CHARACTERS[id]
	var color: Color = data["color"]
	var is_selected := index == _selected_index
	var is_locked := not CharacterManager.is_unlocked(id)

	var rect := _get_card_rect(index)
	var y_offset := (1.0 - card_ease) * 30.0
	rect.position.y += y_offset

	var scale_factor := 1.0
	if is_selected:
		scale_factor = 1.05 + sin(_pulse * 1.5) * 0.02
		# Expand rect from center
		var expand := (scale_factor - 1.0) * CARD_WIDTH / 2.0
		rect.position.x -= expand
		rect.position.y -= expand
		rect.size.x += expand * 2.0
		rect.size.y += expand * 2.0

	var alpha := 0.3 if is_locked else 1.0
	alpha *= card_ease
	var line_alpha := (0.8 if is_selected else 0.4) * alpha
	var fill_alpha := (0.08 if is_selected else 0.03) * alpha

	# Card background
	draw_rect(rect, Color(color.r, color.g, color.b, fill_alpha))

	# Card border
	var border_width := 2.0 if is_selected else 1.0
	if is_locked:
		# Dashed border
		_draw_dashed_rect(rect, Color(color.r, color.g, color.b, line_alpha * 0.5), border_width)
	else:
		draw_rect(rect, Color(color.r, color.g, color.b, line_alpha), false, border_width)

	# Selected glow
	if is_selected and not is_locked:
		for i in range(2):
			var glow_rect := Rect2(rect.position - Vector2(2 + float(i) * 2, 2 + float(i) * 2), rect.size + Vector2(4 + float(i) * 4, 4 + float(i) * 4))
			draw_rect(glow_rect, Color(color.r, color.g, color.b, 0.06 * pulse), false, 1.0)

	var center := rect.get_center()

	# Shape (large, centered in upper half)
	var shape_y := rect.position.y + rect.size.y * 0.3
	var shape_pos := Vector2(center.x, shape_y)
	var shape_radius := 28.0
	var shape_color := Color(color.r, color.g, color.b, alpha * pulse)
	CharacterManager.draw_character_shape(self, id, shape_pos, shape_radius, shape_color, 2.0)
	# Inner shape (smaller, dimmer)
	CharacterManager.draw_character_shape(self, id, shape_pos, shape_radius * 0.5, Color(color.r, color.g, color.b, alpha * 0.3), 1.0)

	# Name
	var name_text: String = data["name"]
	var name_size := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
	draw_string(font, Vector2(center.x - name_size.x / 2.0, rect.position.y + rect.size.y * 0.55), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(color.r, color.g, color.b, alpha))

	# Power name
	var power_text: String = data["power_name"]
	var power_size := font.get_string_size(power_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	draw_string(font, Vector2(center.x - power_size.x / 2.0, rect.position.y + rect.size.y * 0.67), power_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.1, 1.0, 0.3, alpha * 0.8))

	# Passive name
	var passive_text: String = data["passive_desc"]
	var passive_size := font.get_string_size(passive_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	draw_string(font, Vector2(center.x - passive_size.x / 2.0, rect.position.y + rect.size.y * 0.78), passive_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.7, 0.9, alpha * 0.6))

	# Lock overlay / cost
	if is_locked:
		var lock_text := "LOCKED"
		var lock_size := font.get_string_size(lock_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		draw_string(font, Vector2(center.x - lock_size.x / 2.0, rect.position.y + rect.size.y * 0.88), lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.5, 0.5, alpha * 1.5))

		var cost_text := "%d" % data["unlock_cost"]
		var cost_size := font.get_string_size(cost_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		draw_string(font, Vector2(center.x - cost_size.x / 2.0, rect.position.y + rect.size.y * 0.95), cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.0, alpha * 1.5))

func _draw_dashed_rect(rect: Rect2, color: Color, width: float) -> void:
	var corners := [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	for i in range(4):
		var from: Vector2 = corners[i]
		var to: Vector2 = corners[(i + 1) % 4]
		var edge := to - from
		var edge_len := edge.length()
		var dash_len := 8.0
		var gap_len := 6.0
		var d := 0.0
		while d < edge_len:
			var seg_end := minf(d + dash_len, edge_len)
			draw_line(from + edge.normalized() * d, from + edge.normalized() * seg_end, color, width)
			d = seg_end + gap_len
