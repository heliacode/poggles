extends Node2D

var _pulse := 0.0
var _won := false
var _score := 0
var _boards_cleared := 0
var _pegs_hit := 0
var _stardust_earned := 0

@onready var background := $Background

func _ready() -> void:
	_won = not RunState.is_run_active  # If run ended, check how
	_score = RunState.score
	_boards_cleared = RunState.total_boards_cleared
	_pegs_hit = RunState.pegs_hit_this_run
	_stardust_earned = _boards_cleared * 50 + _score / 100
	if _won and _boards_cleared >= RunState.get_total_boards():
		_stardust_earned += 500

func _process(delta: float) -> void:
	_pulse += delta * 2.0
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := GameConfig.VIEWPORT_SIZE
	var center_x := vp.x / 2.0
	var pulse := sin(_pulse) * 0.15 + 0.85

	# Title
	var won_run := _boards_cleared >= RunState.get_total_boards()
	var title := "RUN COMPLETE!" if won_run else "RUN OVER"
	var title_color := Color(0.3, 1.0, 0.5) if won_run else Color(1.0, 0.3, 0.3)
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 42)

	# Title glow
	for i in range(2):
		var offset := float(i + 1) * 1.5
		draw_string(font, Vector2(center_x - title_size.x / 2.0 - offset, 100 - offset), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color(title_color.r, title_color.g, title_color.b, 0.1 * pulse))
	draw_string(font, Vector2(center_x - title_size.x / 2.0, 100), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color(title_color.r, title_color.g, title_color.b, pulse))

	# Stats
	var y := 180.0
	var line_height := 40.0
	var stats := [
		["Score", "%d" % _score, Color(0.3, 0.85, 1.0)],
		["Boards Cleared", "%d / %d" % [_boards_cleared, RunState.get_total_boards()], Color(0.5, 0.8, 1.0)],
		["Pegs Hit", "%d" % _pegs_hit, Color(0.4, 0.7, 1.0)],
		["Stardust Earned", "+%d" % _stardust_earned, Color(1.0, 0.85, 0.3)],
	]

	for stat in stats:
		var label: String = stat[0]
		var value: String = stat[1]
		var col: Color = stat[2]

		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		draw_string(font, Vector2(center_x - 150, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(col.r, col.g, col.b, 0.6))

		var value_size := font.get_string_size(value, HORIZONTAL_ALIGNMENT_RIGHT, -1, 22)
		draw_string(font, Vector2(center_x + 150 - value_size.x, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(col.r, col.g, col.b, 0.9))

		y += line_height

	# Total stardust
	y += 20
	var total_label := "Total Stardust: %d" % SaveData.get_stardust()
	var total_size := font.get_string_size(total_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	draw_string(font, Vector2(center_x - total_size.x / 2.0, y), total_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.85, 0.3, 0.5))

func _on_new_run_pressed() -> void:
	RunState.start_new_run()
	SceneManager.change_scene(GameConfig.ROUTE_MAP_SCENE_PATH)

func _on_main_menu_pressed() -> void:
	SceneManager.go_to_main_menu()
