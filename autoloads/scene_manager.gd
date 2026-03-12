extends Node

var current_level := 1
var current_act_intro := 1
var last_score := 0
var last_orange_total := 0
var last_orange_cleared := 0
var last_balls_used := 0

var _fade_layer: CanvasLayer
var _transition_overlay: Control
var _is_transitioning := false

func _ready() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)

	_transition_overlay = _TransitionOverlay.new()
	_transition_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_transition_overlay)

func change_scene(scene_path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	AudioManager.play_sfx("transition_whoosh")
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "progress", 1.0, 0.2)
	await tween.finished

	get_tree().change_scene_to_file(scene_path)

	var tween2 := create_tween()
	tween2.tween_property(_transition_overlay, "progress", 0.0, 0.2)
	await tween2.finished

	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false


class _TransitionOverlay extends Control:
	var progress := 0.0  # 0=invisible, 1=fully covered
	var _line_count := 24  # horizontal bands

	func _draw() -> void:
		if progress <= 0.0:
			return
		var h := size.y / float(_line_count)
		for i in range(_line_count):
			# Each line fills based on progress with stagger
			var line_progress := clampf(progress * 1.5 - float(i) / float(_line_count) * 0.5, 0.0, 1.0)
			if line_progress <= 0.0:
				continue
			var y := float(i) * h
			# Dark fill
			draw_rect(Rect2(0, y, size.x, h), Color(0.01, 0.01, 0.03, line_progress))
			# Leading edge bright line
			if line_progress < 1.0 and line_progress > 0.1:
				var edge_alpha := (1.0 - line_progress) * 0.8
				draw_line(Vector2(0, y + h * line_progress), Vector2(size.x, y + h * line_progress), Color(0.3, 0.8, 1.0, edge_alpha), 2.0)

	func _process(_delta: float) -> void:
		queue_redraw()

func go_to_main_menu() -> void:
	change_scene(GameConfig.MAIN_MENU_SCENE_PATH)

func go_to_level_select() -> void:
	change_scene(GameConfig.LEVEL_SELECT_SCENE_PATH)

func go_to_gameplay(level_number: int) -> void:
	current_level = level_number
	change_scene(GameConfig.GAMEPLAY_SCENE_PATH)

func go_to_results(score: int, orange_total: int, orange_cleared: int, balls_used: int) -> void:
	last_score = score
	last_orange_total = orange_total
	last_orange_cleared = orange_cleared
	last_balls_used = balls_used
	change_scene(GameConfig.RESULTS_SCENE_PATH)

func go_to_settings() -> void:
	change_scene(GameConfig.SETTINGS_SCENE_PATH)

func go_to_route_map() -> void:
	change_scene(GameConfig.ROUTE_MAP_SCENE_PATH)

func go_to_act_intro(act_number: int) -> void:
	current_act_intro = act_number
	change_scene(GameConfig.ACT_INTRO_SCENE_PATH)

func go_to_run_results() -> void:
	change_scene(GameConfig.RUN_RESULTS_SCENE_PATH)

func go_to_event() -> void:
	change_scene(GameConfig.EVENT_SCENE_PATH)

func go_to_relic_reward() -> void:
	change_scene(GameConfig.RELIC_REWARD_SCENE_PATH)

func go_to_shop() -> void:
	change_scene(GameConfig.SHOP_SCENE_PATH)

func go_to_unlock_screen() -> void:
	change_scene(GameConfig.UNLOCK_SCENE_PATH)

func go_to_character_select() -> void:
	change_scene(GameConfig.CHARACTER_SELECT_SCENE_PATH)
