extends Node2D

## Slay the Spire-style route map.
## Full map visible and scrollable. Player position is crystal clear.
## Visited path is bright, reachable next nodes glow, everything else is dim.

var _pulse := 0.0
var _node_rects: Array = []  # Array of {rect: Rect2, row: int, col: int, type: int}
var _hover_index := -1
var _entrance_time := 0.0

# Scrolling
var _scroll_y := 0.0
var _target_scroll_y := 0.0
var _scroll_speed := 8.0
var _dragging := false
var _drag_start_y := 0.0
var _drag_scroll_start := 0.0

# Layout constants
const ROW_HEIGHT := 120.0
const NODE_SPACING := 50.0
const MAP_TOP_MARGIN := 160.0
const MAP_BOTTOM_MARGIN := 200.0
const HEADER_HEIGHT := 140.0

# Per-type node sizes
var NODE_SIZES := {
	0: Vector2(110, 44),  # BOARD
	1: Vector2(120, 50),  # ELITE
	2: Vector2(100, 44),  # SHOP
	3: Vector2(100, 44),  # REST
	4: Vector2(100, 44),  # EVENT
	5: Vector2(150, 58),  # BOSS
}

# Colors
const VISITED_PATH_COLOR := Color(0.3, 1.0, 0.5)
const CURRENT_NODE_COLOR := Color(1.0, 1.0, 1.0)
const REACHABLE_GLOW := Color(0.3, 0.85, 1.0)
const DIM_ALPHA := 0.08
const UNREACHABLE_ALPHA := 0.15

@onready var background := $Background

func _ready() -> void:
	_build_node_rects()
	_target_scroll_y = _get_scroll_for_current_row()
	_scroll_y = _target_scroll_y

func _process(delta: float) -> void:
	_pulse += delta * 2.5
	_entrance_time += delta
	_scroll_y = lerpf(_scroll_y, _target_scroll_y, delta * _scroll_speed)
	_update_hover()
	queue_redraw()

func _build_node_rects() -> void:
	_node_rects.clear()
	var map := RunState.route_map
	var vp := GameConfig.VIEWPORT_SIZE
	var last_row := map.size() - 1

	for row_idx in range(map.size()):
		var row: Array = map[row_idx]
		var visual_row := last_row - row_idx
		var total_width := 0.0
		for col_idx in range(row.size()):
			var node_data: Dictionary = row[col_idx]
			var node_type: int = node_data.get("type", 0)
			var size: Vector2 = NODE_SIZES.get(node_type, Vector2(110, 44))
			total_width += size.x
		total_width += float(maxi(0, row.size() - 1)) * NODE_SPACING
		var start_x := (vp.x - total_width) / 2.0

		var cursor_x := start_x
		for col_idx in range(row.size()):
			var node_data: Dictionary = row[col_idx]
			var node_type: int = node_data.get("type", 0)
			var size: Vector2 = NODE_SIZES.get(node_type, Vector2(110, 44))
			var jitter_x := sin(float(row_idx * 7 + col_idx * 13 + RunState.run_seed)) * 15.0
			var jitter_y := cos(float(row_idx * 11 + col_idx * 5 + RunState.run_seed)) * 8.0
			var x := cursor_x + jitter_x
			var y := MAP_TOP_MARGIN + float(visual_row) * ROW_HEIGHT + jitter_y
			var rect := Rect2(x, y, size.x, size.y)
			_node_rects.append({"rect": rect, "row": row_idx, "col": col_idx, "type": node_type})
			cursor_x += size.x + NODE_SPACING

func _get_scroll_for_current_row() -> float:
	var vp := GameConfig.VIEWPORT_SIZE
	var last_row := RunState.route_map.size() - 1
	var visual_row := last_row - RunState.route_position
	var target_y := MAP_TOP_MARGIN + float(visual_row) * ROW_HEIGHT
	return maxf(0.0, target_y - vp.y * 0.5)

func _get_total_map_height() -> float:
	return MAP_TOP_MARGIN + float(RunState.route_map.size()) * ROW_HEIGHT + MAP_BOTTOM_MARGIN

func _get_max_scroll() -> float:
	return maxf(0, _get_total_map_height() - GameConfig.VIEWPORT_SIZE.y)

# === NODE STATE HELPERS ===

func _is_visited(row: int, col: int) -> bool:
	## Was this node on the player's chosen path?
	if row >= RunState.route_path.size():
		return false
	return RunState.route_path[row] == col

func _is_on_visited_path_connection(from_row: int, from_col: int, to_row: int, to_col: int) -> bool:
	## Is this connection part of the visited path?
	if from_row >= RunState.route_path.size() or to_row >= RunState.route_path.size():
		return false
	return RunState.route_path[from_row] == from_col and RunState.route_path[to_row] == to_col

func _is_reachable(row: int, col: int) -> bool:
	## Can the player reach this node from their current position?
	if row != RunState.route_position:
		return false
	# First row: all reachable
	if row == 0:
		return true
	# Must be connected from the last visited node
	if RunState.route_path.is_empty():
		return true
	var prev_row_idx := row - 1
	var prev_col := RunState.route_path[prev_row_idx] if prev_row_idx < RunState.route_path.size() else -1
	if prev_col < 0:
		return true
	var prev_row: Array = RunState.route_map[prev_row_idx]
	if prev_col >= prev_row.size():
		return true
	var prev_node: Dictionary = prev_row[prev_col]
	var conns: Array = prev_node.get("connections", [])
	return col in conns

func _update_hover() -> void:
	var mouse := get_global_mouse_position()
	_hover_index = -1
	for i in range(_node_rects.size()):
		var info: Dictionary = _node_rects[i]
		var rect: Rect2 = info["rect"]
		var scrolled_rect := Rect2(rect.position - Vector2(0, _scroll_y), rect.size)
		if info["row"] == RunState.route_position and scrolled_rect.has_point(mouse):
			if _is_reachable(info["row"], info["col"]):
				_hover_index = i
				break

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_target_scroll_y = maxf(0, _target_scroll_y - 80.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_target_scroll_y = minf(_get_max_scroll(), _target_scroll_y + 80.0)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if clicking a node first
				var clicked := _try_click_node(event.position)
				if not clicked:
					_dragging = true
					_drag_start_y = event.position.y
					_drag_scroll_start = _target_scroll_y
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var dy: float = _drag_start_y - event.position.y
		_target_scroll_y = clampf(_drag_scroll_start + dy, 0.0, _get_max_scroll())

func _try_click_node(click_pos: Vector2) -> bool:
	for i in range(_node_rects.size()):
		var info: Dictionary = _node_rects[i]
		var rect: Rect2 = info["rect"]
		var scrolled_rect := Rect2(rect.position - Vector2(0, _scroll_y), rect.size)
		if scrolled_rect.has_point(click_pos) and _is_reachable(info["row"], info["col"]):
			var chosen: Dictionary = RunState.advance_route(info["col"])
			if chosen.is_empty():
				return false
			_target_scroll_y = _get_scroll_for_current_row()
			_handle_node(chosen)
			return true
	return false

func _handle_node(node: Dictionary) -> void:
	var type: int = node.get("type", RunState.NodeType.BOARD)
	match type:
		RunState.NodeType.BOARD, RunState.NodeType.ELITE, RunState.NodeType.BOSS:
			SceneManager.change_scene(GameConfig.GAMEPLAY_SCENE_PATH)
		RunState.NodeType.SHOP:
			SceneManager.go_to_shop()
		RunState.NodeType.REST:
			RunState.add_balls(2)
			_build_node_rects()
		RunState.NodeType.EVENT:
			SceneManager.go_to_event()

# ========== DRAWING ==========

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := GameConfig.VIEWPORT_SIZE
	var center_x := vp.x / 2.0
	var pulse := sin(_pulse) * 0.15 + 0.85
	var map := RunState.route_map

	# === HEADER (fixed, not scrolled) ===
	draw_rect(Rect2(0, 0, vp.x, HEADER_HEIGHT), Color(0.01, 0.01, 0.03, 0.95))

	var act_label := RunState.get_act_label()
	var title := "ACT %d: %s" % [RunState.current_act, act_label.to_upper()]
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	draw_string(font, Vector2(center_x - title_size.x / 2.0, 40), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.3, 0.85, 1.0, pulse))

	var progress := "Board %d / %d" % [RunState.get_current_board_number(), RunState.get_total_boards()]
	var prog_size := font.get_string_size(progress, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	draw_string(font, Vector2(center_x - prog_size.x / 2.0, 65), progress, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.7, 1.0, 0.6))

	var stats := "Balls: %d  |  Coins: %d  |  Score: %d" % [RunState.balls_remaining, RunState.coins, RunState.score]
	var stats_size := font.get_string_size(stats, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(font, Vector2(center_x - stats_size.x / 2.0, 90), stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.8, 1.0, 0.7))

	var instr := "Choose your path  (scroll to explore)"
	var instr_size := font.get_string_size(instr, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(font, Vector2(center_x - instr_size.x / 2.0, 118), instr, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 0.6, 0.8, 0.5 * pulse))

	# Header separator
	draw_line(Vector2(80, HEADER_HEIGHT), Vector2(vp.x - 80, HEADER_HEIGHT), Color(0.3, 0.6, 0.9, 0.15 * pulse), 1.0)

	# === CONNECTION LINES ===
	_draw_connections(map, vp, pulse)

	# === NODES ===
	_draw_nodes(map, vp, pulse, font)

	# === "START" label at bottom ===
	if map.size() > 0:
		var start_vis_row := map.size() - 1
		var start_y := MAP_TOP_MARGIN + float(start_vis_row) * ROW_HEIGHT + 55.0 - _scroll_y
		if start_y > HEADER_HEIGHT and start_y < vp.y + 20:
			var start_text := "START"
			var start_size := font.get_string_size(start_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
			draw_string(font, Vector2(center_x - start_size.x / 2.0, start_y), start_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.7, 0.5, 0.4))

	# === BOSS label at top ===
	if map.size() > 0:
		var boss_y := MAP_TOP_MARGIN - 20.0 - _scroll_y
		if boss_y > HEADER_HEIGHT - 20 and boss_y < vp.y:
			var danger_alpha := 0.2 * pulse
			draw_line(Vector2(100, boss_y), Vector2(vp.x - 100, boss_y), Color(1.0, 0.2, 0.2, danger_alpha), 1.0)

	# === SCROLL INDICATOR ===
	var total_height := _get_total_map_height()
	if total_height > vp.y:
		var track_top := HEADER_HEIGHT + 10.0
		var track_height := vp.y - HEADER_HEIGHT - 20.0
		var visible_ratio := vp.y / total_height
		var thumb_height := maxf(20.0, track_height * visible_ratio)
		var thumb_y := track_top + (_scroll_y / maxf(1.0, total_height - vp.y)) * (track_height - thumb_height)
		# Track
		draw_line(Vector2(vp.x - 8, track_top), Vector2(vp.x - 8, track_top + track_height), Color(0.2, 0.4, 0.6, 0.1), 1.0)
		# Thumb
		draw_line(Vector2(vp.x - 8, thumb_y), Vector2(vp.x - 8, thumb_y + thumb_height), Color(0.3, 0.6, 0.9, 0.4), 3.0)

func _draw_connections(map: Array, vp: Vector2, pulse: float) -> void:
	for i in range(_node_rects.size()):
		var info: Dictionary = _node_rects[i]
		var row: int = info["row"]
		var col: int = info["col"]
		if row >= map.size():
			continue
		var row_data: Array = map[row]
		if col >= row_data.size():
			continue
		var node_data: Dictionary = row_data[col]
		var connections: Array = node_data.get("connections", [])
		var rect: Rect2 = info["rect"]
		var top_center := Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y) - Vector2(0, _scroll_y)

		if top_center.y < HEADER_HEIGHT - 100 or top_center.y > vp.y + 100:
			continue

		for target_col in connections:
			for j in range(_node_rects.size()):
				var other: Dictionary = _node_rects[j]
				if other["row"] == row + 1 and other["col"] == target_col:
					var other_rect: Rect2 = other["rect"]
					var bot_center := Vector2(other_rect.position.x + other_rect.size.x / 2.0, other_rect.end.y) - Vector2(0, _scroll_y)

					# Determine connection state
					var is_visited_conn := _is_on_visited_path_connection(row, col, row + 1, target_col)
					var is_from_current := row == RunState.route_position and _is_reachable(row + 1, target_col)
					var is_from_last_visited := false
					if RunState.route_path.size() > 0 and row == RunState.route_position - 1:
						var last_col := RunState.route_path[RunState.route_path.size() - 1]
						if col == last_col:
							is_from_last_visited = true

					var line_color := Color(0.3, 0.5, 0.7)
					var line_alpha := DIM_ALPHA
					var line_width := 1.0

					if is_visited_conn:
						# Bright green trail for visited path
						line_color = VISITED_PATH_COLOR
						line_alpha = 0.6
						line_width = 2.5
					elif is_from_last_visited:
						# Bright cyan for reachable connections from current position
						line_color = REACHABLE_GLOW
						line_alpha = 0.5 * pulse
						line_width = 2.0
					elif row < RunState.route_position:
						# Past but not visited — very dim
						line_alpha = 0.03
					else:
						# Future — dim
						line_alpha = DIM_ALPHA

					var c := Color(line_color.r, line_color.g, line_color.b, line_alpha)
					_draw_bezier_path(top_center, bot_center, c, line_width)

					# Glow on visited path
					if is_visited_conn:
						_draw_bezier_path(top_center, bot_center, Color(line_color.r, line_color.g, line_color.b, line_alpha * 0.15), line_width + 6.0)

					# Glow + traveling dot on reachable connections
					if is_from_last_visited:
						_draw_bezier_path(top_center, bot_center, Color(line_color.r, line_color.g, line_color.b, line_alpha * 0.15), line_width + 4.0)
						var dot_t := fmod(_pulse * 0.3, 1.0)
						var dot_pos := _bezier_point(top_center, bot_center, dot_t)
						draw_circle(dot_pos, 3.5, Color(line_color.r, line_color.g, line_color.b, 0.6 * pulse))

					break

func _draw_nodes(map: Array, vp: Vector2, pulse: float, font: Font) -> void:
	for i in range(_node_rects.size()):
		var info: Dictionary = _node_rects[i]
		var rect: Rect2 = info["rect"]
		var row: int = info["row"]
		var col: int = info["col"]
		var node_type: int = info["type"]
		var is_current_row := row == RunState.route_position
		var is_past := row < RunState.route_position
		var is_hovered := i == _hover_index
		var is_visited := _is_visited(row, col)
		var is_reachable := is_current_row and _is_reachable(row, col)

		var draw_pos := rect.position - Vector2(0, _scroll_y)
		if draw_pos.y + rect.size.y < HEADER_HEIGHT - 20 or draw_pos.y > vp.y + 20:
			continue

		# Entrance animation
		var visual_row := RunState.route_map.size() - 1 - row
		var row_entrance := clampf((_entrance_time - float(RunState.route_map.size() - 1 - visual_row) * 0.04) / 0.3, 0.0, 1.0)
		if row_entrance <= 0.0:
			continue
		var slide_y := (1.0 - row_entrance) * 20.0
		var draw_rect_adj := Rect2(draw_pos + Vector2(0, slide_y), rect.size)

		# Fade behind header
		var header_fade := clampf((draw_rect_adj.position.y - HEADER_HEIGHT) / 30.0, 0.0, 1.0)
		if header_fade <= 0.0:
			continue

		# Get node data
		var row_data: Array = map[row] if row < map.size() else []
		var node_data: Dictionary = row_data[col] if col < row_data.size() else {}
		var label: String = node_data.get("label", "???")

		# Determine visual state
		var c := _node_color(node_type)
		var alpha := UNREACHABLE_ALPHA

		if is_visited:
			# Visited: bright with green tint, filled
			c = c.lerp(VISITED_PATH_COLOR, 0.3)
			alpha = 0.7
		elif is_reachable:
			# Reachable: full brightness, glowing
			alpha = 0.85 if is_hovered else 0.65
		elif is_past and not is_visited:
			# Past but not visited: very dim
			alpha = 0.05
		else:
			# Future: dim but visible
			alpha = UNREACHABLE_ALPHA

		alpha *= row_entrance * header_fade

		# === GLOW for reachable nodes ===
		if is_reachable:
			_draw_node_glow(draw_rect_adj, c, pulse, node_type)

		# === VISITED checkmark glow ===
		if is_visited:
			# Subtle green glow behind visited nodes
			for gi in range(3):
				var expand := float(gi + 1) * 2.0
				var ga := 0.04 * (1.0 - float(gi) * 0.3)
				draw_rect(draw_rect_adj.grow(expand), Color(VISITED_PATH_COLOR.r, VISITED_PATH_COLOR.g, VISITED_PATH_COLOR.b, ga), true)

		# === Draw node shape ===
		_draw_node_shape(draw_rect_adj, node_type, c, alpha * pulse, is_reachable, is_hovered)

		# === Fill for visited nodes ===
		if is_visited:
			draw_rect(draw_rect_adj.grow(-2), Color(c.r, c.g, c.b, 0.06), true)

		# === Hover highlight ===
		if is_hovered:
			draw_rect(draw_rect_adj.grow(2), Color(c.r, c.g, c.b, 0.12), true)

		# === Icon ===
		var icon_pos := Vector2(draw_rect_adj.position.x + 18, draw_rect_adj.get_center().y)
		if is_visited:
			# Checkmark for visited
			var ck := icon_pos
			draw_line(ck + Vector2(-4, 0), ck + Vector2(-1, 4), Color(VISITED_PATH_COLOR.r, VISITED_PATH_COLOR.g, VISITED_PATH_COLOR.b, 0.8), 2.0)
			draw_line(ck + Vector2(-1, 4), ck + Vector2(5, -4), Color(VISITED_PATH_COLOR.r, VISITED_PATH_COLOR.g, VISITED_PATH_COLOR.b, 0.8), 2.0)
		else:
			_draw_node_icon(icon_pos, node_type, c, alpha * pulse, is_reachable)

		# === Label ===
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		var label_pos := Vector2(
			draw_rect_adj.position.x + 34 + (draw_rect_adj.size.x - 34 - label_size.x) / 2.0,
			draw_rect_adj.get_center().y + 5.0
		)
		var label_color := Color(c.r, c.g, c.b, alpha * pulse)
		if is_visited:
			label_color = Color(VISITED_PATH_COLOR.r, VISITED_PATH_COLOR.g, VISITED_PATH_COLOR.b, 0.5)
		draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_color)

		# === "YOU ARE HERE" pulsing indicator ===
		if is_reachable:
			var center := draw_rect_adj.get_center()
			# Pulsing diamond marker to the left
			var marker_x := draw_rect_adj.position.x - 24.0
			var marker_y := center.y
			var m_size := 5.0 + sin(_pulse * 2.0) * 1.5
			var m_alpha := 0.7 * pulse
			var mc := Color(REACHABLE_GLOW.r, REACHABLE_GLOW.g, REACHABLE_GLOW.b, m_alpha)
			var m_pts := PackedVector2Array([
				Vector2(marker_x + m_size, marker_y),
				Vector2(marker_x, marker_y - m_size),
				Vector2(marker_x - m_size, marker_y),
				Vector2(marker_x, marker_y + m_size),
				Vector2(marker_x + m_size, marker_y),
			])
			draw_polyline(m_pts, mc, 2.0)
			draw_colored_polygon(PackedVector2Array([m_pts[0], m_pts[1], m_pts[2], m_pts[3]]), Color(mc.r, mc.g, mc.b, 0.15))

# ========== NODE SHAPES ==========

func _draw_node_shape(rect: Rect2, type: int, color: Color, alpha: float, is_current: bool, is_hovered: bool) -> void:
	var c := Color(color.r, color.g, color.b, alpha)
	var center := rect.get_center()
	var hw := rect.size.x / 2.0
	var hh := rect.size.y / 2.0
	var border_width := 2.0 if is_current else 1.0
	if is_hovered:
		border_width += 1.0

	match type:
		RunState.NodeType.BOARD:
			var chamfer := 8.0
			var pts := PackedVector2Array([
				Vector2(rect.position.x + chamfer, rect.position.y),
				Vector2(rect.end.x - chamfer, rect.position.y),
				Vector2(rect.end.x, rect.position.y + chamfer),
				Vector2(rect.end.x, rect.end.y - chamfer),
				Vector2(rect.end.x - chamfer, rect.end.y),
				Vector2(rect.position.x + chamfer, rect.end.y),
				Vector2(rect.position.x, rect.end.y - chamfer),
				Vector2(rect.position.x, rect.position.y + chamfer),
				Vector2(rect.position.x + chamfer, rect.position.y),
			])
			draw_polyline(pts, c, border_width)
			if is_current:
				draw_polygon(pts, [Color(c.r, c.g, c.b, 0.06)])

		RunState.NodeType.ELITE:
			var pts := PackedVector2Array()
			for vi in range(7):
				var angle := TAU * float(vi % 6) / 6.0 - PI / 6.0
				pts.append(center + Vector2(cos(angle) * hw, sin(angle) * hh))
			draw_polyline(pts, c, border_width)
			if is_current:
				draw_polygon(pts, [Color(c.r, c.g, c.b, 0.06)])

		RunState.NodeType.SHOP:
			var pts := PackedVector2Array([
				Vector2(center.x, center.y - hh),
				Vector2(center.x + hw, center.y),
				Vector2(center.x, center.y + hh),
				Vector2(center.x - hw, center.y),
				Vector2(center.x, center.y - hh),
			])
			draw_polyline(pts, c, border_width)
			var inner := 3.0
			var inner_pts := PackedVector2Array([
				Vector2(center.x, center.y - hh + inner),
				Vector2(center.x + hw - inner * 1.5, center.y),
				Vector2(center.x, center.y + hh - inner),
				Vector2(center.x - hw + inner * 1.5, center.y),
				Vector2(center.x, center.y - hh + inner),
			])
			draw_polyline(inner_pts, Color(c.r, c.g, c.b, alpha * 0.4), 1.0)

		RunState.NodeType.REST:
			var pts := PackedVector2Array()
			var cap_r := hh
			for vi in range(8):
				var angle := PI / 2.0 + PI * float(vi) / 7.0
				pts.append(Vector2(rect.position.x + cap_r + cos(angle) * cap_r, center.y + sin(angle) * cap_r))
			for vi in range(8):
				var angle := -PI / 2.0 + PI * float(vi) / 7.0
				pts.append(Vector2(rect.end.x - cap_r + cos(angle) * cap_r, center.y + sin(angle) * cap_r))
			pts.append(pts[0])
			draw_polyline(pts, c, border_width)
			if is_current:
				draw_polygon(pts, [Color(c.r, c.g, c.b, 0.04)])

		RunState.NodeType.EVENT:
			var pts := PackedVector2Array()
			for vi in range(9):
				var angle := TAU * float(vi % 8) / 8.0 - PI / 8.0
				pts.append(center + Vector2(cos(angle) * hw, sin(angle) * hh))
			draw_polyline(pts, c, border_width)
			for vi in range(8):
				if vi % 2 == 0:
					var a1 := TAU * float(vi) / 8.0 - PI / 8.0
					var a2 := TAU * float(vi + 1) / 8.0 - PI / 8.0
					var s := 0.8
					var p1 := center + Vector2(cos(a1) * hw * s, sin(a1) * hh * s)
					var p2 := center + Vector2(cos(a2) * hw * s, sin(a2) * hh * s)
					draw_line(p1, p2, Color(c.r, c.g, c.b, alpha * 0.3), 1.0)

		RunState.NodeType.BOSS:
			var pts := PackedVector2Array()
			for vi in range(9):
				var angle := TAU * float(vi % 8) / 8.0 - PI / 8.0
				var r := hw if vi % 2 == 0 else hw * 0.7
				var rh := hh if vi % 2 == 0 else hh * 0.7
				pts.append(center + Vector2(cos(angle) * r, sin(angle) * rh))
			draw_polyline(pts, c, border_width + 1.0)
			var fill_alpha := alpha * 0.08 * (sin(_pulse) * 0.5 + 0.5)
			draw_polygon(pts, [Color(c.r, c.g, c.b, fill_alpha)])
			for ri in range(8):
				var angle := _pulse * 0.5 + TAU * float(ri) / 8.0
				var p := center + Vector2(cos(angle) * (hw + 10), sin(angle) * (hh + 10))
				draw_circle(p, 1.5, Color(c.r, c.g, c.b, alpha * 0.3))

		_:
			draw_rect(rect, c, false, border_width)

func _draw_node_glow(rect: Rect2, color: Color, pulse_val: float, _type: int) -> void:
	var breathe := sin(_pulse) * 2.0
	for gi in range(4):
		var expand := float(gi + 1) * 3.0 + breathe
		var alpha := (0.12 - float(gi) * 0.025) * pulse_val
		var glow_rect := rect.grow(expand)
		draw_rect(glow_rect, Color(color.r, color.g, color.b, maxf(0.0, alpha)), true)

func _draw_node_icon(pos: Vector2, type: int, color: Color, alpha: float, _is_current: bool) -> void:
	var c := Color(color.r, color.g, color.b, alpha)
	var s := 7.0
	match type:
		RunState.NodeType.BOARD:
			draw_arc(pos, s, 0, TAU, 12, c, 1.5, true)
			draw_circle(pos, 2.0, Color(c.r, c.g, c.b, alpha * 0.5))
		RunState.NodeType.ELITE:
			draw_line(pos + Vector2(-s, -s), pos + Vector2(s, s), c, 1.5)
			draw_line(pos + Vector2(s, -s), pos + Vector2(-s, s), c, 1.5)
			draw_circle(pos, 2.5, c)
		RunState.NodeType.SHOP:
			var pts := PackedVector2Array([
				pos + Vector2(0, -s), pos + Vector2(s, 0),
				pos + Vector2(0, s), pos + Vector2(-s, 0), pos + Vector2(0, -s)
			])
			draw_polyline(pts, c, 1.5)
		RunState.NodeType.REST:
			var pts := PackedVector2Array([
				pos + Vector2(0, -s), pos + Vector2(s * 0.7, s * 0.6),
				pos + Vector2(-s * 0.7, s * 0.6), pos + Vector2(0, -s)
			])
			draw_polyline(pts, c, 1.5)
		RunState.NodeType.EVENT:
			draw_arc(pos + Vector2(0, -2), s * 0.7, -PI * 0.8, PI * 0.3, 8, c, 1.5, true)
			draw_circle(pos + Vector2(0, s * 0.6), 1.5, c)
		RunState.NodeType.BOSS:
			for bi in range(5):
				var angle := TAU * float(bi) / 5.0 - PI / 2.0
				var tip := pos + Vector2.from_angle(angle) * s
				draw_line(pos, tip, c, 2.0)

# ========== BEZIER CURVES ==========

func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3

func _bezier_point(from: Vector2, to: Vector2, t: float) -> Vector2:
	var dist_y := absf(to.y - from.y)
	var ctrl_offset := dist_y * 0.45
	var ctrl1 := Vector2(from.x, from.y - ctrl_offset)
	var ctrl2 := Vector2(to.x, to.y + ctrl_offset)
	return _cubic_bezier(from, ctrl1, ctrl2, to, t)

func _draw_bezier_path(from: Vector2, to: Vector2, color: Color, width: float, segments: int = 20) -> void:
	var dist_y := absf(to.y - from.y)
	var ctrl_offset := dist_y * 0.45
	var ctrl1 := Vector2(from.x, from.y - ctrl_offset)
	var ctrl2 := Vector2(to.x, to.y + ctrl_offset)

	var points := PackedVector2Array()
	for si in range(segments + 1):
		var t := float(si) / float(segments)
		points.append(_cubic_bezier(from, ctrl1, ctrl2, to, t))

	draw_polyline(points, color, width, true)

# ========== COLORS ==========

func _node_color(type: int) -> Color:
	match type:
		RunState.NodeType.BOARD: return Color(0.3, 0.85, 1.0)
		RunState.NodeType.ELITE: return Color(1.0, 0.4, 0.1)
		RunState.NodeType.SHOP: return Color(1.0, 0.85, 0.3)
		RunState.NodeType.REST: return Color(0.3, 1.0, 0.5)
		RunState.NodeType.EVENT: return Color(0.8, 0.3, 1.0)
		RunState.NodeType.BOSS: return Color(1.0, 0.2, 0.2)
	return Color(0.5, 0.5, 0.5)
