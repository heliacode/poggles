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

## 3D letter polygon outlines — each letter is an outer polygon + optional inner polygons (holes)
## Coordinates normalized 0.0–1.0 within a cell. Letters are "block" style with thickness.
const LETTER_POLYS := {
	"P": {
		"outer": [
			Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(0.85, 0.0),
			Vector2(1.0, 0.12), Vector2(1.0, 0.38), Vector2(0.85, 0.5),
			Vector2(0.35, 0.5), Vector2(0.35, 1.0),
		],
		"inner": [
			Vector2(0.35, 0.15), Vector2(0.35, 0.35),
			Vector2(0.65, 0.35), Vector2(0.7, 0.3), Vector2(0.7, 0.2),
			Vector2(0.65, 0.15),
		],
	},
	"O": {
		"outer": [
			Vector2(0.15, 0.0), Vector2(0.85, 0.0),
			Vector2(1.0, 0.12), Vector2(1.0, 0.88), Vector2(0.85, 1.0),
			Vector2(0.15, 1.0), Vector2(0.0, 0.88), Vector2(0.0, 0.12),
		],
		"inner": [
			Vector2(0.25, 0.18), Vector2(0.75, 0.18),
			Vector2(0.8, 0.25), Vector2(0.8, 0.75), Vector2(0.75, 0.82),
			Vector2(0.25, 0.82), Vector2(0.2, 0.75), Vector2(0.2, 0.25),
		],
	},
	"G": {
		"outer": [
			Vector2(1.0, 0.18), Vector2(0.85, 0.0), Vector2(0.15, 0.0),
			Vector2(0.0, 0.12), Vector2(0.0, 0.88), Vector2(0.15, 1.0),
			Vector2(0.85, 1.0), Vector2(1.0, 0.88), Vector2(1.0, 0.45),
			Vector2(0.55, 0.45), Vector2(0.55, 0.6),
			Vector2(0.7, 0.6), Vector2(0.7, 0.82), Vector2(0.25, 0.82),
			Vector2(0.2, 0.75), Vector2(0.2, 0.25), Vector2(0.25, 0.18),
			Vector2(0.7, 0.18), Vector2(0.7, 0.3),
		],
		"inner": [],
	},
	"L": {
		"outer": [
			Vector2(0.0, 0.0), Vector2(0.35, 0.0), Vector2(0.35, 0.8),
			Vector2(1.0, 0.8), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
		],
		"inner": [],
	},
	"E": {
		"outer": [
			Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.2),
			Vector2(0.35, 0.2), Vector2(0.35, 0.4),
			Vector2(0.8, 0.4), Vector2(0.8, 0.6),
			Vector2(0.35, 0.6), Vector2(0.35, 0.8),
			Vector2(1.0, 0.8), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
		],
		"inner": [],
	},
	"S": {
		"outer": [
			Vector2(1.0, 0.15), Vector2(0.85, 0.0), Vector2(0.15, 0.0),
			Vector2(0.0, 0.12), Vector2(0.0, 0.42),
			Vector2(0.12, 0.52), Vector2(0.75, 0.52),
			Vector2(0.75, 0.78), Vector2(0.2, 0.78),
			Vector2(0.0, 0.82),
			Vector2(0.15, 1.0), Vector2(0.85, 1.0),
			Vector2(1.0, 0.88), Vector2(1.0, 0.58),
			Vector2(0.88, 0.48), Vector2(0.25, 0.48),
			Vector2(0.25, 0.22), Vector2(0.8, 0.22),
			Vector2(1.0, 0.26),
		],
		"inner": [],
	},
}

## Per-letter neon colors
const LETTER_COLORS := [
	Color(0.0, 1.0, 0.9),   # P — cyan
	Color(1.0, 0.15, 0.55),  # O — hot pink
	Color(0.2, 1.0, 0.4),   # G — neon green
	Color(0.2, 1.0, 0.4),   # G — neon green
	Color(1.0, 0.85, 0.1),  # L — gold
	Color(0.4, 0.55, 1.0),  # E — electric blue
	Color(1.0, 0.15, 0.55),  # S — hot pink
]

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := GameConfig.VIEWPORT_SIZE
	var center_x := vp.x / 2.0

	# Intro animation easing
	var title_t := clampf(_intro_time / 0.6, 0.0, 1.0)
	var title_ease := 1.0 - pow(1.0 - title_t, 3.0)
	var sub_t := clampf((_intro_time - 0.3) / 0.4, 0.0, 1.0)
	var tagline_t := clampf((_intro_time - 0.5) / 0.4, 0.0, 1.0)
	var stats_t := clampf((_intro_time - 0.8) / 0.4, 0.0, 1.0)
	var pulse := sin(_pulse) * 0.15 + 0.85

	# === 3D WIREFRAME TITLE ===
	_draw_3d_title(center_x, title_ease, pulse)

	# Subtitle
	var sub := "Rebuild the Lattice"
	var sub_size := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
	draw_string(font, Vector2(center_x - sub_size.x / 2.0, 270), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.5, 0.8, 1.0, 0.5 * pulse * sub_t))

	# Lore tagline
	var tagline := "One vertex. One chance. Descend."
	var tagline_size := font.get_string_size(tagline, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	draw_string(font, Vector2(center_x - tagline_size.x / 2.0, 292), tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.6, 0.8, 0.3 * pulse * tagline_t))

	# Stats line
	var runs := SaveData.get_runs_completed()
	var best := SaveData.get_best_run_score()
	var dust := SaveData.get_stardust()
	if runs > 0:
		var stats := "Runs: %d  |  Best: %d  |  Stardust: %d" % [runs, best, dust]
		var stats_size := font.get_string_size(stats, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		draw_string(font, Vector2(center_x - stats_size.x / 2.0, 690), stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.5, 0.7, 0.4 * stats_t))

	# Debug hotkey hint
	var debug_hint := "F1-F6: Debug"
	var hint_size := font.get_string_size(debug_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	draw_string(font, Vector2(vp.x - hint_size.x - 8, vp.y - 8), debug_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 1.0, 1.0, 0.15))

func _draw_3d_title(center_x: float, ease_val: float, pulse: float) -> void:
	var letters := "POGGLES"
	var cell_w := 74.0
	var cell_h := 90.0
	var gap := 12.0
	var total_w := float(letters.length()) * cell_w + float(letters.length() - 1) * gap
	var start_x := center_x - total_w / 2.0
	var base_y := 80.0
	var y_offset := -30.0 * (1.0 - ease_val)

	# 3D extrusion: offset for back face (vanishing point above-right)
	var extrude := Vector2(6.0, -12.0)

	# Slow gentle rotation around Y axis (simulated as horizontal shear)
	var rot_angle := sin(_time * 0.4) * 0.03  # subtle sway

	for li in range(letters.length()):
		var ch: String = letters[li]
		var poly_data: Dictionary = LETTER_POLYS.get(ch, {})
		if poly_data.is_empty():
			continue
		var outer_norm: Array = poly_data["outer"]
		var inner_norm: Array = poly_data.get("inner", [])
		var color: Color = LETTER_COLORS[li]
		var lx := start_x + float(li) * (cell_w + gap)
		var ly := base_y + y_offset

		# Per-letter entrance stagger
		var letter_t := clampf((_intro_time - float(li) * 0.06) / 0.5, 0.0, 1.0)
		var letter_ease := 1.0 - pow(1.0 - letter_t, 3.0)
		if letter_ease <= 0.0:
			continue
		ly += (1.0 - letter_ease) * 40.0

		# Subtle per-letter float
		ly += sin(_time * 1.2 + float(li) * 1.1) * 2.5

		# Build front face vertices
		var front: Array[Vector2] = []
		for v in outer_norm:
			var sv: Vector2 = v
			var px := lx + sv.x * cell_w
			var py := ly + sv.y * cell_h
			# Apply subtle shear for 3D rotation feel
			px += (sv.y - 0.5) * rot_angle * cell_w * float(li - 3)
			front.append(Vector2(px, py))

		# Build back face vertices (offset + slightly scaled toward center for perspective)
		var back: Array[Vector2] = []
		var face_center := Vector2(lx + cell_w * 0.5, ly + cell_h * 0.5)
		var persp_scale := 0.94  # back face slightly smaller
		for fv in front:
			var toward_center := (fv - face_center) * persp_scale
			back.append(face_center + toward_center + extrude)

		# Build inner hole front/back
		var inner_front: Array[Vector2] = []
		var inner_back: Array[Vector2] = []
		for v in inner_norm:
			var sv: Vector2 = v
			var px := lx + sv.x * cell_w
			var py := ly + sv.y * cell_h
			px += (sv.y - 0.5) * rot_angle * cell_w * float(li - 3)
			inner_front.append(Vector2(px, py))
			var toward_center := (Vector2(px, py) - face_center) * persp_scale
			inner_back.append(face_center + toward_center + extrude)

		# === DRAW ORDER: back face → depth edges → front face ===

		var back_alpha := 0.2 * letter_ease * pulse
		var depth_alpha := 0.25 * letter_ease * pulse
		var front_alpha := 0.85 * letter_ease * pulse

		# --- Back face outline ---
		_draw_poly_outline(back, Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, back_alpha), 1.5)
		if not inner_back.is_empty():
			_draw_poly_outline(inner_back, Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, back_alpha * 0.7), 1.0)

		# --- Depth edges connecting front to back at each vertex ---
		var depth_color := Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, depth_alpha)
		for vi in range(front.size()):
			draw_line(front[vi], back[vi], depth_color, 1.5)
		for vi in range(inner_front.size()):
			draw_line(inner_front[vi], inner_back[vi], Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, depth_alpha * 0.6), 1.0)

		# --- Side face fills (subtle colored quads between front/back edges) ---
		for vi in range(front.size()):
			var vi_next := (vi + 1) % front.size()
			var quad := PackedVector2Array([front[vi], front[vi_next], back[vi_next], back[vi]])
			var side_alpha := 0.03 * letter_ease * pulse
			draw_polygon(quad, [Color(color.r, color.g, color.b, side_alpha)])

		# --- Front face: glow layers ---
		for gi in range(3):
			var glow_w := 5.0 + float(gi) * 3.5
			var glow_a := (0.07 - float(gi) * 0.02) * pulse * letter_ease
			_draw_poly_outline(front, Color(color.r, color.g, color.b, glow_a), glow_w)

		# --- Front face: core outline ---
		_draw_poly_outline(front, Color(color.r, color.g, color.b, front_alpha), 2.5)

		# --- Front face: white-hot highlight ---
		_draw_poly_outline(front, Color(1.0, 1.0, 1.0, 0.3 * letter_ease * pulse), 1.0)

		# --- Inner hole on front face ---
		if not inner_front.is_empty():
			for gi in range(2):
				var glow_w := 4.0 + float(gi) * 3.0
				var glow_a := (0.05 - float(gi) * 0.02) * pulse * letter_ease
				_draw_poly_outline(inner_front, Color(color.r, color.g, color.b, glow_a), glow_w)
			_draw_poly_outline(inner_front, Color(color.r, color.g, color.b, front_alpha * 0.8), 2.0)
			_draw_poly_outline(inner_front, Color(1.0, 1.0, 1.0, 0.2 * letter_ease * pulse), 0.8)

		# --- Vertex dots on front face ---
		for fv in front:
			draw_circle(fv, 3.5, Color(color.r, color.g, color.b, 0.12 * pulse * letter_ease))
			draw_circle(fv, 2.0, Color(color.r, color.g, color.b, 0.6 * pulse * letter_ease))
			draw_circle(fv, 0.8, Color(1.0, 1.0, 1.0, 0.5 * pulse * letter_ease))

	# --- Horizontal scan line ---
	var scan_y := base_y + y_offset + fmod(_time * 35.0, cell_h + 60.0) - 30.0
	if ease_val > 0.5:
		draw_line(Vector2(start_x - 30, scan_y), Vector2(start_x + total_w + 30, scan_y), Color(1.0, 1.0, 1.0, 0.05 * pulse), 1.0)

	# --- Corner brackets ---
	var ba := 0.2 * pulse * ease_val
	var bk := 18.0
	var pad := 22.0
	var tl := Vector2(start_x - pad, base_y + y_offset - pad)
	var br := Vector2(start_x + total_w + pad, base_y + y_offset + cell_h + pad + 5)
	var bc := Color(0.3, 0.8, 1.0, ba)
	draw_line(tl, Vector2(tl.x + bk, tl.y), bc, 1.5)
	draw_line(tl, Vector2(tl.x, tl.y + bk), bc, 1.5)
	draw_line(Vector2(br.x, tl.y), Vector2(br.x - bk, tl.y), bc, 1.5)
	draw_line(Vector2(br.x, tl.y), Vector2(br.x, tl.y + bk), bc, 1.5)
	draw_line(Vector2(tl.x, br.y), Vector2(tl.x + bk, br.y), bc, 1.5)
	draw_line(Vector2(tl.x, br.y), Vector2(tl.x, br.y - bk), bc, 1.5)
	draw_line(br, Vector2(br.x - bk, br.y), bc, 1.5)
	draw_line(br, Vector2(br.x, br.y - bk), bc, 1.5)

func _draw_poly_outline(verts: Array[Vector2], color: Color, width: float) -> void:
	if verts.size() < 2:
		return
	for i in range(verts.size()):
		var next := (i + 1) % verts.size()
		draw_line(verts[i], verts[next], color, width)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:  # Quick Board — jump to Act 1 gameplay
			_debug_start_run()
			SceneManager.change_scene(GameConfig.GAMEPLAY_SCENE_PATH)
		KEY_F2:  # Quick Shop — 100 coins, jump to shop
			_debug_start_run()
			RunState.coins = 100
			SceneManager.go_to_shop()
		KEY_F3:  # Quick Event — jump to event screen
			_debug_start_run()
			SceneManager.go_to_event()
		KEY_F4:  # Quick Boss — boss board, jump to gameplay
			_debug_start_run()
			RunState.current_board_index = 4
			SceneManager.change_scene(GameConfig.GAMEPLAY_SCENE_PATH)
		KEY_F5:  # Quick Late Game — Act 3 Board 2 (has moving pegs)
			_debug_start_run()
			RunState.current_act = 3
			RunState.current_board_index = 2
			SceneManager.change_scene(GameConfig.GAMEPLAY_SCENE_PATH)
		KEY_F6:  # Quick Route Map — jump to route map
			_debug_start_run()
			SceneManager.go_to_route_map()

func _debug_start_run() -> void:
	CharacterManager.select_character("orbie")
	RunState.start_new_run()

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
