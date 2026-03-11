extends Node2D

var _text := ""
var _color := Color.WHITE
var _alpha := 1.0
var _scale_val := 0.5
var _drift_x := 0.0
var _time := 0.0

func setup(text: String, col: Color, pos: Vector2) -> void:
	_text = text
	_color = col
	global_position = pos
	_drift_x = randf_range(-20.0, 20.0)
	_scale_val = 1.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "_scale_val", 1.0, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position:y", position.y - 50, 0.9).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_property(self, "_alpha", 0.0, 0.25)
	tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	_time += delta
	# Horizontal drift and sine wobble
	position.x += _drift_x * delta
	position.x += sin(_time * 4.0) * 8.0 * _alpha * delta
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var font_size := 18
	var text_size := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var offset := -text_size / 2.0

	# Neon glow text (draw multiple times with increasing size/decreasing alpha)
	var glow_col := Color(_color.r, _color.g, _color.b, _alpha * 0.2)
	draw_string(font, (offset + Vector2(-1, -1)) * _scale_val, _text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size + 2, glow_col)
	draw_string(font, (offset + Vector2(1, 1)) * _scale_val, _text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size + 2, glow_col)

	# Core text
	var col := Color(_color.r, _color.g, _color.b, _alpha)
	draw_string(font, offset * _scale_val, _text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, col)

	# Bright center
	var bright := Color(1, 1, 1, _alpha * 0.5)
	draw_string(font, offset * _scale_val, _text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, bright)
