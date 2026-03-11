extends Node

var current_level := 1
var current_act_intro := 1
var last_score := 0
var last_orange_total := 0
var last_orange_cleared := 0
var last_balls_used := 0

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _is_transitioning := false

func _ready() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.anchors_preset = Control.PRESET_FULL_RECT
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

func change_scene(scene_path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, GameConfig.FADE_DURATION)
	await tween.finished

	get_tree().change_scene_to_file(scene_path)

	var tween2 := create_tween()
	tween2.tween_property(_fade_rect, "color:a", 0.0, GameConfig.FADE_DURATION)
	await tween2.finished

	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false

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
