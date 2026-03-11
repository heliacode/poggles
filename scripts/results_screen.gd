extends Node2D

var _pulse := 0.0
var _score := 0
var _orange_total := 0
var _orange_cleared := 0
var _balls_used := 0
var _stars := 0
var _won := false
var _reveal_time := 0.0
var _display_score := 0

@onready var background := $Background

func _ready() -> void:
	_score = SceneManager.last_score
	_orange_total = SceneManager.last_orange_total
	_orange_cleared = SceneManager.last_orange_cleared
	_balls_used = SceneManager.last_balls_used
	_won = _orange_cleared >= _orange_total
	_calculate_stars()
	_save_progress()
	# Hide buttons initially, fade in after stars
	var ui := get_node_or_null("UI")
	if ui:
		for child in ui.get_children():
			_set_modulate_recursive(child, 0.0)

func _calculate_stars() -> void:
	if not _won:
		_stars = 0
		return
	var level_data := LevelLoader.load_level(SceneManager.current_level)
	if not level_data:
		_stars = 1
		return
	var max_score := level_data.get_max_possible_score()
	if max_score <= 0:
		_stars = 1
		return
	var ratio := float(_score) / float(max_score)
	_stars = 0
	for threshold in GameConfig.STAR_THRESHOLDS:
		if ratio >= threshold:
			_stars += 1

func _save_progress() -> void:
	if _won:
		SaveData.set_level_completed(SceneManager.current_level)
	SaveData.set_level_score(SceneManager.current_level, _score)
	SaveData.set_level_stars(SceneManager.current_level, _stars)

func _set_modulate_recursive(node: Node, alpha: float) -> void:
	if node is CanvasItem:
		node.modulate.a = alpha
	for child in node.get_children():
		_set_modulate_recursive(child, alpha)

func _process(delta: float) -> void:
	_pulse += delta * 2.0
	_reveal_time += delta

	# Count up score over 1s
	if _reveal_time < 1.0:
		_display_score = int(float(_score) * clampf(_reveal_time / 1.0, 0.0, 1.0))
	else:
		_display_score = _score

	# Fade in buttons after stars are done (stars finish at ~1.0 + 0.3*3 = 1.9s)
	var button_fade_start := 2.2
	var ui := get_node_or_null("UI")
	if ui and _reveal_time > button_fade_start:
		var fade := clampf((_reveal_time - button_fade_start) / 0.3, 0.0, 1.0)
		for child in ui.get_children():
			_set_modulate_recursive(child, fade)

	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := GameConfig.VIEWPORT_SIZE
	var center_x := vp.x / 2.0
	var pulse := sin(_pulse) * 0.15 + 0.85

	# Result title
	var title := "LEVEL COMPLETE!" if _won else "GAME OVER"
	var title_color := Color(0.3, 1.0, 0.5) if _won else Color(1.0, 0.3, 0.3)
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 42)
	draw_string(font, Vector2(center_x - title_size.x / 2.0, 120), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color(title_color.r, title_color.g, title_color.b, pulse))

	# Score (counts up)
	var score_text := "Score: %d" % _display_score
	var score_size := font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	draw_string(font, Vector2(center_x - score_size.x / 2.0, 200), score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.3, 0.85, 1.0, 0.9))

	# Orange pegs
	var orange_text := "Orange Pegs: %d / %d" % [_orange_cleared, _orange_total]
	var orange_size := font.get_string_size(orange_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
	draw_string(font, Vector2(center_x - orange_size.x / 2.0, 240), orange_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.4, 0.1, 0.8))

	# Balls used
	var balls_text := "Balls Used: %d" % _balls_used
	var balls_size := font.get_string_size(balls_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
	draw_string(font, Vector2(center_x - balls_size.x / 2.0, 275), balls_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.5, 0.8, 1.0, 0.7))

	# Stars (staggered reveal after score finishes counting)
	if _won:
		var star_y := 330.0
		for i in range(3):
			var star_appear_time := 1.0 + float(i) * 0.3
			if _reveal_time < star_appear_time:
				continue
			var star_fade := clampf((_reveal_time - star_appear_time) / 0.2, 0.0, 1.0)
			var star_x := center_x + (float(i) - 1.0) * 50.0
			var filled := i < _stars
			var star_col := Color(1.0, 0.85, 0.3, pulse * star_fade) if filled else Color(0.3, 0.3, 0.4, 0.4 * star_fade)
			var star_label := "*" if filled else "-"
			var s_size := font.get_string_size(star_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 40)
			draw_string(font, Vector2(star_x - s_size.x / 2.0, star_y), star_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, star_col)

func _on_next_pressed() -> void:
	var next := SceneManager.current_level + 1
	if next > GameConfig.TOTAL_LEVELS:
		SceneManager.go_to_level_select()
	else:
		SceneManager.go_to_gameplay(next)

func _on_retry_pressed() -> void:
	SceneManager.go_to_gameplay(SceneManager.current_level)

func _on_menu_pressed() -> void:
	SceneManager.go_to_level_select()
