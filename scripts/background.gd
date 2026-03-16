extends ColorRect

## Geometry Wars-inspired neon grid background.
## Static grid with sine brightness pulsing, radial gradient falloff,
## intersection glow dots, and shockwave ripple reactions on hit.

var _time := 0.0
var _score_pulse := 0.0

# Shockwave ripple tracking
var _ripples: Array[Dictionary] = []
const MAX_RIPPLES := 8

# Grid visual constants
const GRID_BASE_COLOR := Color(0.08, 0.18, 0.45)  # Electric blue
const GRID_BRIGHT_COLOR := Color(0.12, 0.28, 0.65)  # Brighter center lines
const DOT_COLOR := Color(0.15, 0.35, 0.75)
const PULSE_FREQ := 2.5  # Hz for sine brightness pulse
const PULSE_AMP := 0.10  # 10% brightness amplitude
const RIPPLE_SPEED := 400.0  # px/sec expansion
const RIPPLE_MAX_RADIUS := 500.0
const RIPPLE_WIDTH := 60.0  # thickness of the ripple ring

func _ready() -> void:
	color = GameConfig.BG_COLOR
	z_index = -10

func _process(delta: float) -> void:
	_time += delta
	if _score_pulse > 0:
		_score_pulse = maxf(0, _score_pulse - delta * 2.0)

	# Advance ripples and remove expired ones
	var i := _ripples.size() - 1
	while i >= 0:
		_ripples[i]["radius"] += RIPPLE_SPEED * delta
		_ripples[i]["life"] -= delta
		if _ripples[i]["life"] <= 0 or _ripples[i]["radius"] > RIPPLE_MAX_RADIUS:
			_ripples.remove_at(i)
		i -= 1

	queue_redraw()

func pulse(intensity: float) -> void:
	_score_pulse = clampf(intensity, 0.0, 1.0)

func pulse_at(pos: Vector2, intensity: float) -> void:
	_score_pulse = clampf(intensity, 0.0, 1.0)
	if _ripples.size() < MAX_RIPPLES:
		_ripples.append({
			"pos": pos,
			"radius": 0.0,
			"life": 0.8,
			"life_max": 0.8,
			"intensity": clampf(intensity, 0.1, 1.0),
		})

func _draw() -> void:
	var vp := GameConfig.VIEWPORT_SIZE
	var center := vp / 2.0
	var grid_spacing := GameConfig.BG_GRID_SPACING
	var max_dist := center.length()

	# Sine-based brightness pulse (2.5 Hz, subtle)
	var sine_pulse := 1.0 + sin(_time * TAU * PULSE_FREQ) * PULSE_AMP
	var pulse_boost := _score_pulse * 0.25

	# Soft radial glow behind grid (atmosphere)
	for i in range(5):
		var t := float(i) / 5.0
		var radius := max_dist * (1.0 - t * 0.35)
		var alpha := t * 0.025 * sine_pulse
		draw_circle(center, radius, Color(0.04, 0.08, 0.18, alpha))

	# --- Draw grid lines ---
	# Horizontal lines (static, no scrolling)
	var y := fmod(center.y, grid_spacing)
	while y < vp.y:
		_draw_grid_line_h(y, vp, center, max_dist, grid_spacing, sine_pulse, pulse_boost)
		y += grid_spacing

	# Vertical lines (static, no scrolling)
	var x := fmod(center.x, grid_spacing)
	while x < vp.x:
		_draw_grid_line_v(x, vp, center, max_dist, grid_spacing, sine_pulse, pulse_boost)
		x += grid_spacing

	# --- Intersection dots ---
	var dot_y := fmod(center.y, grid_spacing)
	while dot_y < vp.y:
		var dot_x := fmod(center.x, grid_spacing)
		while dot_x < vp.x:
			var dot_pos := Vector2(dot_x, dot_y)
			var dist_ratio := dot_pos.distance_to(center) / max_dist
			var dot_alpha := (1.0 - dist_ratio * 0.7) * 0.2 * sine_pulse + pulse_boost * 0.15

			# Brighten dots near ripples
			for ripple in _ripples:
				var rdist: float = dot_pos.distance_to(ripple["pos"])
				var rradius: float = ripple["radius"]
				var ring_dist := absf(rdist - rradius)
				if ring_dist < RIPPLE_WIDTH:
					var ring_factor := 1.0 - ring_dist / RIPPLE_WIDTH
					var life_factor: float = ripple["life"] / ripple["life_max"]
					dot_alpha += ring_factor * life_factor * ripple["intensity"] * 0.4

			dot_alpha = clampf(dot_alpha, 0.0, 0.6)
			if dot_alpha > 0.01:
				draw_circle(dot_pos, 1.5, Color(DOT_COLOR.r, DOT_COLOR.g, DOT_COLOR.b, dot_alpha))
			dot_x += grid_spacing
		dot_y += grid_spacing

	# --- Center cross (slightly brighter accent lines) ---
	var center_alpha := 0.08 * sine_pulse + pulse_boost * 0.1
	var cc := Color(GRID_BRIGHT_COLOR.r, GRID_BRIGHT_COLOR.g, GRID_BRIGHT_COLOR.b, center_alpha)
	draw_line(Vector2(0, center.y), Vector2(vp.x, center.y), cc, 1.5)
	draw_line(Vector2(center.x, 0), Vector2(center.x, vp.y), cc, 1.5)

	# --- Draw ripple shockwave rings ---
	for ripple in _ripples:
		var life_factor: float = ripple["life"] / ripple["life_max"]
		var rradius: float = ripple["radius"]
		var ring_alpha: float = life_factor * ripple["intensity"] * 0.25
		if ring_alpha > 0.005:
			var ring_color := Color(0.2, 0.4, 0.9, ring_alpha)
			# Draw the shockwave as a thin arc ring
			var point_count := 64
			var prev_point: Vector2 = ripple["pos"] + Vector2(rradius, 0)
			for p in range(1, point_count + 1):
				var angle := float(p) / float(point_count) * TAU
				var next_point: Vector2 = ripple["pos"] + Vector2(cos(angle), sin(angle)) * rradius
				draw_line(prev_point, next_point, ring_color, 1.5 * life_factor + 0.5)
				prev_point = next_point


func _draw_grid_line_h(y: float, vp: Vector2, center: Vector2, max_dist: float, spacing: float, sine_pulse: float, pulse_boost: float) -> void:
	var dist_from_center := absf(y - center.y) / (vp.y * 0.5)
	# Radial gradient: brighter near center, fading at edges
	var radial_fade := 1.0 - dist_from_center * 0.65
	var base_alpha := 0.12 * radial_fade * sine_pulse + pulse_boost * 0.08

	# Check ripple distortion
	var ripple_brightness := 0.0
	for ripple in _ripples:
		# For horizontal lines, check vertical distance to ripple ring
		var dy: float = absf(y - ripple["pos"].y)
		var rradius: float = ripple["radius"]
		var ring_dist := absf(dy - rradius)
		if ring_dist < RIPPLE_WIDTH:
			var ring_factor := 1.0 - ring_dist / RIPPLE_WIDTH
			var life_factor: float = ripple["life"] / ripple["life_max"]
			ripple_brightness += ring_factor * life_factor * ripple["intensity"] * 0.3

	var final_alpha := clampf(base_alpha + ripple_brightness, 0.0, 0.5)
	if final_alpha > 0.005:
		var line_color := Color(GRID_BASE_COLOR.r, GRID_BASE_COLOR.g, GRID_BASE_COLOR.b, final_alpha)
		var width := 1.0 + ripple_brightness * 1.5
		draw_line(Vector2(0, y), Vector2(vp.x, y), line_color, width)


func _draw_grid_line_v(x: float, vp: Vector2, center: Vector2, max_dist: float, spacing: float, sine_pulse: float, pulse_boost: float) -> void:
	var dist_from_center := absf(x - center.x) / (vp.x * 0.5)
	var radial_fade := 1.0 - dist_from_center * 0.65
	var base_alpha := 0.12 * radial_fade * sine_pulse + pulse_boost * 0.08

	var ripple_brightness := 0.0
	for ripple in _ripples:
		var dx: float = absf(x - ripple["pos"].x)
		var rradius: float = ripple["radius"]
		var ring_dist := absf(dx - rradius)
		if ring_dist < RIPPLE_WIDTH:
			var ring_factor := 1.0 - ring_dist / RIPPLE_WIDTH
			var life_factor: float = ripple["life"] / ripple["life_max"]
			ripple_brightness += ring_factor * life_factor * ripple["intensity"] * 0.3

	var final_alpha := clampf(base_alpha + ripple_brightness, 0.0, 0.5)
	if final_alpha > 0.005:
		var line_color := Color(GRID_BASE_COLOR.r, GRID_BASE_COLOR.g, GRID_BASE_COLOR.b, final_alpha)
		var width := 1.0 + ripple_brightness * 1.5
		draw_line(Vector2(x, 0), Vector2(x, vp.y), line_color, width)
