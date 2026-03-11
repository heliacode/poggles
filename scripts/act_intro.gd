extends Node2D

var _time := 0.0
var _alpha := 0.0
var _phase := 0  # 0=fade_in, 1=hold, 2=fade_out
var _phase_time := 0.0
var _act_number := 1

const FADE_IN_DURATION := 0.8
const HOLD_DURATION := 3.0
const FADE_OUT_DURATION := 0.6

const ACT_NAMES := {
	1: "THE SURFACE",
	2: "THE CORE",
	3: "THE ABYSS",
}

const ACT_FLAVOR := {
	1: "The geometry here is still recognizable. Hexagons. Triangles.\nBut the color is wrong — everything flickers, static-edged.\nThe Anchor Nodes pulse orange with trapped corruption.",
	2: "Deeper, the geometry warps. Pegs drift. Gravity inverts in pockets.\nThe Lattice here was always unstable — experimental, alive.\nThe Corruption amplified what was already chaotic.",
	3: "There is no geometry here. Only the memory of it.\nThe Corruption's source is a void that unmakes shapes.\nIf VERTEX can reach it, one vertex is enough to seed a new Lattice.",
}

const ACT_COLORS := {
	1: Color(0.3, 1.0, 0.5),
	2: Color(1.0, 0.4, 0.05),
	3: Color(0.8, 0.2, 1.0),
}

func _ready() -> void:
	_act_number = SceneManager.current_act_intro
	_phase = 0
	_phase_time = 0.0
	_alpha = 0.0

func _process(delta: float) -> void:
	_time += delta
	_phase_time += delta

	match _phase:
		0:  # Fade in
			_alpha = clampf(_phase_time / FADE_IN_DURATION, 0.0, 1.0)
			if _phase_time >= FADE_IN_DURATION:
				_phase = 1
				_phase_time = 0.0
		1:  # Hold
			_alpha = 1.0
			if _phase_time >= HOLD_DURATION:
				_phase = 2
				_phase_time = 0.0
		2:  # Fade out
			_alpha = clampf(1.0 - _phase_time / FADE_OUT_DURATION, 0.0, 1.0)
			if _phase_time >= FADE_OUT_DURATION:
				SceneManager.go_to_route_map()
				set_process(false)
				return

	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := GameConfig.VIEWPORT_SIZE
	var center_x := vp.x / 2.0

	# Background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.01, 0.01, 0.03, 1.0))

	var act_color: Color = ACT_COLORS.get(_act_number, Color(0.5, 0.8, 1.0))
	var act_name: String = ACT_NAMES.get(_act_number, "UNKNOWN")
	var flavor: String = ACT_FLAVOR.get(_act_number, "")

	# Draw wireframe decorative lines
	_draw_wireframe_decoration(act_color)

	# Act label: "ACT 1: THE SURFACE"
	var act_label := "ACT %d: %s" % [_act_number, act_name]
	var label_size := font.get_string_size(act_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 36)
	var label_pos := Vector2(center_x - label_size.x / 2.0, 260)

	# Glow layers
	for i in range(3):
		var offset := float(i + 1) * 2.0
		var glow_alpha := 0.08 * _alpha * (1.0 - float(i) * 0.25)
		var glow_color := Color(act_color.r, act_color.g, act_color.b, glow_alpha)
		draw_string(font, label_pos + Vector2(-offset, -offset), act_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, glow_color)
		draw_string(font, label_pos + Vector2(offset, offset), act_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, glow_color)

	# Core label
	draw_string(font, label_pos, act_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(act_color.r, act_color.g, act_color.b, _alpha))
	draw_string(font, label_pos, act_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1, 1, 1, 0.25 * _alpha))

	# Horizontal rule
	var rule_y := 290.0
	var rule_half := 180.0
	draw_line(Vector2(center_x - rule_half, rule_y), Vector2(center_x + rule_half, rule_y), Color(act_color.r, act_color.g, act_color.b, 0.3 * _alpha), 1.0)

	# Flavor text — draw each line with staggered entrance during hold phase
	var lines := flavor.split("\n")
	var line_y := 330.0
	var hold_elapsed := 0.0
	if _phase >= 1:
		hold_elapsed = _phase_time if _phase == 1 else HOLD_DURATION
	for line_idx in range(lines.size()):
		var line: String = lines[line_idx]
		var line_size := font.get_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		# Stagger: each line slides in 0.15s after the previous
		var line_delay := float(line_idx) * 0.15
		var line_t := clampf((hold_elapsed - line_delay) / 0.25, 0.0, 1.0)
		# During fade_in phase, show nothing; during hold, stagger in
		var line_alpha := _alpha * 0.7 * line_t if _phase >= 1 else _alpha * 0.7 * 0.0
		if _phase == 0:
			# Not yet in hold, don't show flavor
			line_y += 24.0
			continue
		var x_offset := 20.0 * (1.0 - line_t)
		draw_string(font, Vector2(center_x - line_size.x / 2.0 + x_offset, line_y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.7, 0.8, line_alpha))
		line_y += 24.0

func _draw_wireframe_decoration(act_color: Color) -> void:
	var vp := GameConfig.VIEWPORT_SIZE
	var center_x := vp.x / 2.0
	var base_alpha := 0.06 * _alpha

	# Draw subtle geometric shapes based on act
	match _act_number:
		1:
			# Clean hexagons
			for i in range(3):
				var radius := 120.0 + float(i) * 60.0
				var offset := _time * 0.2 * (1.0 if i % 2 == 0 else -1.0)
				_draw_polygon_outline(Vector2(center_x, 360), radius, 6, offset, Color(act_color.r, act_color.g, act_color.b, base_alpha * (1.0 - float(i) * 0.25)))
		2:
			# Spiraling triangles
			for i in range(4):
				var radius := 100.0 + float(i) * 50.0
				var offset := _time * 0.3 * (1.0 if i % 2 == 0 else -1.0)
				_draw_polygon_outline(Vector2(center_x, 360), radius, 3, offset, Color(act_color.r, act_color.g, act_color.b, base_alpha * (1.0 - float(i) * 0.2)))
		3:
			# Fragmented lines — anti-geometry
			var rng := RandomNumberGenerator.new()
			rng.seed = int(_time * 2.0) + 42
			for i in range(8):
				var x1 := center_x + rng.randf_range(-200, 200)
				var y1 := 360.0 + rng.randf_range(-150, 150)
				var x2 := x1 + rng.randf_range(-80, 80)
				var y2 := y1 + rng.randf_range(-80, 80)
				var flicker := rng.randf_range(0.02, 0.08) * _alpha
				draw_line(Vector2(x1, y1), Vector2(x2, y2), Color(act_color.r, act_color.g, act_color.b, flicker), 1.0)

func _draw_polygon_outline(center: Vector2, radius: float, sides: int, angle_offset: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(sides + 1):
		var angle := angle_offset + TAU * float(i) / float(sides)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(points, color, 1.0, true)

func _input(event: InputEvent) -> void:
	# Allow skip on click or key press
	if event is InputEventMouseButton and event.pressed:
		_skip_to_route_map()
	elif event is InputEventKey and event.pressed:
		_skip_to_route_map()

func _skip_to_route_map() -> void:
	if _phase < 2:
		_phase = 2
		_phase_time = 0.0
