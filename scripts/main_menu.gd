extends Node2D

var _pulse := 0.0
var _time := 0.0
var _intro_time := 0.0

@onready var background := $Background

func _ready() -> void:
	AudioManager.play_music("menu")
	# Stagger button fade-in
	var vbox := get_node_or_null("UI/VBox")
	if vbox:
		var btn_idx := 0
		for child in vbox.get_children():
			if child is CanvasItem:
				child.modulate.a = 0.0
				var delay := 0.5 + float(btn_idx) * 0.1
				var tw := create_tween()
				tw.tween_interval(delay)
				tw.tween_property(child, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
				btn_idx += 1

func _process(delta: float) -> void:
	_pulse += delta * 2.0
	_time += delta
	_intro_time = minf(_intro_time + delta, 2.0)
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := GameConfig.VIEWPORT_SIZE
	var center_x := vp.x / 2.0

	# Intro animation easing
	var title_t := clampf(_intro_time / 0.6, 0.0, 1.0)
	var title_ease := 1.0 - pow(1.0 - title_t, 3.0)  # cubic ease-out
	var sub_t := clampf((_intro_time - 0.3) / 0.4, 0.0, 1.0)
	var tagline_t := clampf((_intro_time - 0.5) / 0.4, 0.0, 1.0)
	var stats_t := clampf((_intro_time - 0.8) / 0.4, 0.0, 1.0)

	# Title: POGGLES
	var title := "POGGLES"
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 72)
	var title_y_offset := -30.0 * (1.0 - title_ease)
	var title_pos := Vector2(center_x - title_size.x / 2.0, 200 + title_y_offset)
	var pulse := sin(_pulse) * 0.15 + 0.85
	var title_color := Color(0.3, 1.0, 0.5)

	# Title glow layers
	for i in range(3):
		var offset := float(i + 1) * 2.0
		var glow_alpha := 0.1 * pulse * (1.0 - float(i) * 0.3) * title_ease
		draw_string(font, title_pos + Vector2(-offset, -offset), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 72 + i * 2, Color(title_color.r, title_color.g, title_color.b, glow_alpha))
		draw_string(font, title_pos + Vector2(offset, offset), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 72 + i * 2, Color(title_color.r, title_color.g, title_color.b, glow_alpha))

	# Title core
	draw_string(font, title_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(title_color.r, title_color.g, title_color.b, pulse * title_ease))
	draw_string(font, title_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(1, 1, 1, 0.3 * pulse * title_ease))

	# Subtitle
	var sub := "Rebuild the Lattice"
	var sub_size := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
	draw_string(font, Vector2(center_x - sub_size.x / 2.0, 240), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.5, 0.8, 1.0, 0.5 * pulse * sub_t))

	# Lore tagline
	var tagline := "One vertex. One chance. Descend."
	var tagline_size := font.get_string_size(tagline, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	draw_string(font, Vector2(center_x - tagline_size.x / 2.0, 262), tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.6, 0.8, 0.3 * pulse * tagline_t))

	# Stats line
	var runs := SaveData.get_runs_completed()
	var best := SaveData.get_best_run_score()
	var dust := SaveData.get_stardust()
	if runs > 0:
		var stats := "Runs: %d  |  Best: %d  |  Stardust: %d" % [runs, best, dust]
		var stats_size := font.get_string_size(stats, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		draw_string(font, Vector2(center_x - stats_size.x / 2.0, 690), stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.5, 0.7, 0.4 * stats_t))

func _on_new_run_pressed() -> void:
	SceneManager.go_to_character_select()

func _on_unlocks_pressed() -> void:
	SceneManager.go_to_unlock_screen()

func _on_practice_pressed() -> void:
	SceneManager.go_to_level_select()

func _on_settings_pressed() -> void:
	SceneManager.go_to_settings()

func _on_quit_pressed() -> void:
	get_tree().quit()
