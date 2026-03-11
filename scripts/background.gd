extends ColorRect

var _time := 0.0
var _score_pulse := 0.0

func _ready() -> void:
	color = GameConfig.BG_COLOR
	z_index = -10

func _process(delta: float) -> void:
	_time += delta
	if _score_pulse > 0:
		_score_pulse = maxf(0, _score_pulse - delta * 2.0)
	queue_redraw()

func pulse(intensity: float) -> void:
	_score_pulse = clampf(intensity, 0.0, 1.0)

func _draw() -> void:
	var vp := GameConfig.VIEWPORT_SIZE
	var center := vp / 2.0
	var grid_spacing := GameConfig.BG_GRID_SPACING
	var pulse_boost := _score_pulse * 0.3
	var grid_color := Color(0.1, 0.2, 0.4, 0.15 + pulse_boost)
	var grid_color_bright := Color(0.15, 0.3, 0.6, 0.08 + pulse_boost)

	for i in range(6):
		var t := float(i) / 6.0
		var radius := vp.length() * 0.5 * (1.0 - t * 0.4)
		var alpha := t * 0.04
		draw_circle(center, radius, Color(0.05, 0.1, 0.2, alpha))

	var y_offset := fmod(_time * 5.0, grid_spacing)
	var y := y_offset
	while y < vp.y:
		var dist_from_center := absf(y - center.y) / (vp.y * 0.5)
		var alpha := grid_color.a * (1.0 - dist_from_center * 0.5)
		draw_line(Vector2(0, y), Vector2(vp.x, y), Color(grid_color.r, grid_color.g, grid_color.b, alpha), 1.0)
		y += grid_spacing

	var x_offset := fmod(_time * 3.0, grid_spacing)
	var x := x_offset
	while x < vp.x:
		var dist_from_center := absf(x - center.x) / (vp.x * 0.5)
		var alpha := grid_color.a * (1.0 - dist_from_center * 0.5)
		draw_line(Vector2(x, 0), Vector2(x, vp.y), Color(grid_color.r, grid_color.g, grid_color.b, alpha), 1.0)
		x += grid_spacing

	draw_line(Vector2(0, center.y), Vector2(vp.x, center.y), grid_color_bright, 1.5)
	draw_line(Vector2(center.x, 0), Vector2(center.x, vp.y), grid_color_bright, 1.5)
