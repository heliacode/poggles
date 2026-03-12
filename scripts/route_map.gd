extends Node2D

var _pulse := 0.0
var _node_rects: Array = []  # Array of {rect: Rect2, row: int, col: int}
var _hover_index := -1
var _entrance_time := 0.0

# Scrolling
var _scroll_y := 0.0
var _target_scroll_y := 0.0
var _scroll_speed := 8.0

# Layout constants
const ROW_HEIGHT := 120.0
const NODE_WIDTH := 140.0
const NODE_HEIGHT := 50.0
const NODE_SPACING := 40.0
const MAP_TOP_MARGIN := 160.0
const MAP_BOTTOM_MARGIN := 200.0
const HEADER_HEIGHT := 140.0

@onready var background := $Background

func _ready() -> void:
	_build_node_rects()
	# Scroll to current position
	_target_scroll_y = _get_scroll_for_current_row()
	_scroll_y = _target_scroll_y

func _process(delta: float) -> void:
	_pulse += delta * 2.5
	_entrance_time += delta
	# Smooth scroll
	_scroll_y = lerpf(_scroll_y, _target_scroll_y, delta * _scroll_speed)
	_update_hover()
	queue_redraw()

func _build_node_rects() -> void:
	_node_rects.clear()
	var map := RunState.route_map
	var vp := GameConfig.VIEWPORT_SIZE

	for row_idx in range(map.size()):
		var row: Array = map[row_idx]
		var total_width := float(row.size()) * NODE_WIDTH + float(row.size() - 1) * NODE_SPACING
		var start_x := (vp.x - total_width) / 2.0

		for col_idx in range(row.size()):
			# Add horizontal jitter based on seed for organic feel
			var jitter_x := sin(float(row_idx * 7 + col_idx * 13 + RunState.run_seed)) * 20.0
			var jitter_y := cos(float(row_idx * 11 + col_idx * 5 + RunState.run_seed)) * 10.0
			var x := start_x + float(col_idx) * (NODE_WIDTH + NODE_SPACING) + jitter_x
			var y := MAP_TOP_MARGIN + float(row_idx) * ROW_HEIGHT + jitter_y
			var rect := Rect2(x, y, NODE_WIDTH, NODE_HEIGHT)
			_node_rects.append({"rect": rect, "row": row_idx, "col": col_idx})

func _get_scroll_for_current_row() -> float:
	var vp := GameConfig.VIEWPORT_SIZE
	var target_y := MAP_TOP_MARGIN + float(RunState.route_position) * ROW_HEIGHT
	# Center current row vertically, accounting for header
	return maxf(0.0, target_y - vp.y * 0.4)

func _get_total_map_height() -> float:
	return MAP_TOP_MARGIN + float(RunState.route_map.size()) * ROW_HEIGHT + MAP_BOTTOM_MARGIN

func _update_hover() -> void:
	var mouse := get_global_mouse_position()
	_hover_index = -1
	for i in range(_node_rects.size()):
		var info: Dictionary = _node_rects[i]
		var rect: Rect2 = info["rect"]
		var scrolled_rect := Rect2(rect.position - Vector2(0, _scroll_y), rect.size)
		if info["row"] == RunState.route_position and scrolled_rect.has_point(mouse):
			_hover_index = i
			break

func _input(event: InputEvent) -> void:
	# Mouse wheel scrolling
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_target_scroll_y = maxf(0, _target_scroll_y - 60.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var max_scroll := maxf(0, _get_total_map_height() - GameConfig.VIEWPORT_SIZE.y)
			_target_scroll_y = minf(max_scroll, _target_scroll_y + 60.0)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_click(event.position)

func _handle_click(click_pos: Vector2) -> void:
	var clicked_index := -1
	for i in range(_node_rects.size()):
		var info: Dictionary = _node_rects[i]
		var rect: Rect2 = info["rect"]
		var scrolled_rect := Rect2(rect.position - Vector2(0, _scroll_y), rect.size)
		if info["row"] == RunState.route_position and scrolled_rect.has_point(click_pos):
			clicked_index = i
			break
	if clicked_index < 0:
		clicked_index = _hover_index
	if clicked_index >= 0:
		# Check if this node is reachable via connections
		var info: Dictionary = _node_rects[clicked_index]
		if _is_node_reachable(info["row"], info["col"]):
			var chosen := RunState.advance_route(info["col"])
			if chosen.is_empty():
				return
			# Scroll to new position
			_target_scroll_y = _get_scroll_for_current_row()
			_handle_node(chosen)

func _is_node_reachable(row: int, col: int) -> bool:
	if row != RunState.route_position:
		return false
	# First row is always reachable
	if row == 0:
		return true
	# Check parent connections
	var prev_row: Array = RunState.route_map[row - 1]
	for prev_col in range(prev_row.size()):
		var prev_node: Dictionary = prev_row[prev_col]
		var conns: Array = prev_node.get("connections", [])
		if col in conns:
			return true
	return true  # Fallback: allow all for current row

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

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := GameConfig.VIEWPORT_SIZE
	var center_x := vp.x / 2.0
	var pulse := sin(_pulse) * 0.15 + 0.85
	var map := RunState.route_map

	# === HEADER (fixed, not scrolled) ===
	# Dark header background
	draw_rect(Rect2(0, 0, vp.x, HEADER_HEIGHT), Color(0.01, 0.01, 0.03, 0.95))

	# Title
	var act_label := RunState.get_act_label()
	var title := "ACT %d: %s" % [RunState.current_act, act_label.to_upper()]
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	draw_string(font, Vector2(center_x - title_size.x / 2.0, 40), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.3, 0.85, 1.0, pulse))

	# Board progress
	var progress := "Board %d / %d" % [RunState.get_current_board_number(), RunState.get_total_boards()]
	var prog_size := font.get_string_size(progress, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	draw_string(font, Vector2(center_x - prog_size.x / 2.0, 65), progress, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.7, 1.0, 0.6))

	# Stats bar
	var stats := "Balls: %d  |  Coins: %d  |  Score: %d" % [RunState.balls_remaining, RunState.coins, RunState.score]
	var stats_size := font.get_string_size(stats, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(font, Vector2(center_x - stats_size.x / 2.0, 90), stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.8, 1.0, 0.7))

	# Instruction
	var instr := "Choose your path"
	var instr_size := font.get_string_size(instr, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	draw_string(font, Vector2(center_x - instr_size.x / 2.0, 120), instr, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.6, 0.8, 0.5 * pulse))

	# === MAP CONTENT (scrolled) ===

	# Draw connection lines between connected nodes
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
		var bot_center := Vector2(rect.position.x + rect.size.x / 2.0, rect.end.y) - Vector2(0, _scroll_y)

		# Skip if off screen
		if bot_center.y < HEADER_HEIGHT - 50 or bot_center.y > vp.y + 50:
			continue

		for target_col in connections:
			# Find the target node rect
			for j in range(_node_rects.size()):
				var other: Dictionary = _node_rects[j]
				if other["row"] == row + 1 and other["col"] == target_col:
					var other_rect: Rect2 = other["rect"]
					var top_center := Vector2(other_rect.position.x + other_rect.size.x / 2.0, other_rect.position.y) - Vector2(0, _scroll_y)

					# Color based on whether path is past/current/future
					var line_alpha := 0.08
					var line_color := Color(0.3, 0.6, 0.9)
					if row < RunState.route_position:
						line_alpha = 0.04
					elif row == RunState.route_position:
						line_alpha = 0.25
						line_color = Color(0.3, 0.85, 1.0)

					# Draw curved path (bezier-like with 2 line segments)
					var mid := (bot_center + top_center) / 2.0
					var ctrl1 := Vector2(bot_center.x, mid.y)
					var ctrl2 := Vector2(top_center.x, mid.y)
					_draw_path_line(bot_center, ctrl1, Color(line_color.r, line_color.g, line_color.b, line_alpha), pulse)
					_draw_path_line(ctrl1, ctrl2, Color(line_color.r, line_color.g, line_color.b, line_alpha * 0.8), pulse)
					_draw_path_line(ctrl2, top_center, Color(line_color.r, line_color.g, line_color.b, line_alpha), pulse)
					break

	# Draw nodes
	for i in range(_node_rects.size()):
		var info: Dictionary = _node_rects[i]
		var rect: Rect2 = info["rect"]
		var row: int = info["row"]
		var col: int = info["col"]
		var is_current_row := row == RunState.route_position
		var is_past := row < RunState.route_position
		var is_hovered := i == _hover_index

		# Apply scroll
		var draw_rect_pos := rect.position - Vector2(0, _scroll_y)

		# Skip if off screen
		if draw_rect_pos.y + rect.size.y < HEADER_HEIGHT - 20 or draw_rect_pos.y > vp.y + 20:
			continue

		# Entrance animation: stagger per row
		var row_entrance := clampf((_entrance_time - float(row) * 0.06) / 0.3, 0.0, 1.0)
		if row_entrance <= 0.0:
			continue
		var slide_y := (1.0 - row_entrance) * 20.0
		var draw_rect_adj := Rect2(draw_rect_pos + Vector2(0, slide_y), rect.size)

		# Fade if behind header
		var header_fade := clampf((draw_rect_adj.position.y - HEADER_HEIGHT) / 30.0, 0.0, 1.0)
		if header_fade <= 0.0:
			continue

		# Get node data
		var row_data: Array = map[row] if row < map.size() else []
		var node_data: Dictionary = row_data[col] if col < row_data.size() else {}
		var label: String = node_data.get("label", "???")
		var node_type: int = node_data.get("type", 0)

		# Color based on type
		var c := _node_color(node_type)
		var alpha := 0.25
		if is_current_row:
			alpha = 0.85 if is_hovered else 0.65
		elif is_past:
			alpha = 0.12
		else:
			# Future rows fade with distance
			var dist := float(row - RunState.route_position)
			alpha = maxf(0.1, 0.4 - dist * 0.03)
		alpha *= row_entrance * header_fade

		# Background glow for current row
		if is_current_row:
			var breathe := sin(_pulse) * 2.0
			draw_rect(draw_rect_adj.grow(4 + breathe), Color(c.r, c.g, c.b, 0.06 * pulse), true)

		# Node icon (small shape indicating type)
		var icon_pos := Vector2(draw_rect_adj.position.x + 16, draw_rect_adj.position.y + draw_rect_adj.size.y / 2.0)
		_draw_node_icon(icon_pos, node_type, c, alpha * pulse, is_current_row)

		# Border
		var border_grow := sin(_pulse) * 1.5 if is_current_row else 0.0
		var border_rect := draw_rect_adj.grow(border_grow)
		var border_points := PackedVector2Array([
			border_rect.position, Vector2(border_rect.end.x, border_rect.position.y),
			border_rect.end, Vector2(border_rect.position.x, border_rect.end.y), border_rect.position,
		])
		var line_width := 1.5 if is_current_row else 1.0
		draw_polyline(border_points, Color(c.r, c.g, c.b, alpha * pulse), line_width)

		# Label
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		var label_pos := Vector2(
			draw_rect_adj.position.x + 32 + (draw_rect_adj.size.x - 32 - label_size.x) / 2.0,
			draw_rect_adj.position.y + draw_rect_adj.size.y / 2.0 + 5.0
		)
		draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(c.r, c.g, c.b, alpha * pulse))

		# Hover highlight
		if is_hovered:
			draw_rect(draw_rect_adj.grow(1), Color(c.r, c.g, c.b, 0.1), true)

	# Scroll indicator (subtle dots on right edge)
	var total_height := _get_total_map_height()
	if total_height > vp.y:
		var track_top := HEADER_HEIGHT + 10.0
		var track_height := vp.y - HEADER_HEIGHT - 20.0
		var thumb_y := track_top + (_scroll_y / maxf(1.0, total_height - vp.y)) * track_height
		draw_circle(Vector2(vp.x - 8, thumb_y), 3.0, Color(0.3, 0.6, 0.9, 0.3))
		# Track line
		draw_line(Vector2(vp.x - 8, track_top), Vector2(vp.x - 8, track_top + track_height), Color(0.2, 0.4, 0.6, 0.1), 1.0)

func _draw_path_line(from: Vector2, to: Vector2, color: Color, pulse: float) -> void:
	# Draw a dashed path line
	var dir := (to - from)
	var length := dir.length()
	if length < 1.0:
		return
	var step := 8.0
	var steps := int(length / step)
	for s in range(steps):
		if s % 2 == 1:
			continue
		var t1 := float(s) / float(steps)
		var t2 := float(s + 1) / float(steps)
		var p1 := from + dir * t1
		var p2 := from + dir * t2
		draw_line(p1, p2, color, 1.0)

func _draw_node_icon(pos: Vector2, type: int, color: Color, alpha: float, is_current: bool) -> void:
	var c := Color(color.r, color.g, color.b, alpha)
	var s := 6.0
	match type:
		RunState.NodeType.BOARD:
			# Circle
			draw_arc(pos, s, 0, TAU, 12, c, 1.5, true)
		RunState.NodeType.ELITE:
			# Skull-like: circle with x
			draw_arc(pos, s, 0, TAU, 12, c, 1.5, true)
			draw_line(pos + Vector2(-3, -3), pos + Vector2(3, 3), c, 1.0)
			draw_line(pos + Vector2(3, -3), pos + Vector2(-3, 3), c, 1.0)
		RunState.NodeType.SHOP:
			# Diamond
			var pts := PackedVector2Array([
				pos + Vector2(0, -s), pos + Vector2(s, 0),
				pos + Vector2(0, s), pos + Vector2(-s, 0), pos + Vector2(0, -s)
			])
			draw_polyline(pts, c, 1.5)
		RunState.NodeType.REST:
			# Campfire-like: triangle
			var pts := PackedVector2Array([
				pos + Vector2(0, -s), pos + Vector2(s * 0.866, s * 0.5),
				pos + Vector2(-s * 0.866, s * 0.5), pos + Vector2(0, -s)
			])
			draw_polyline(pts, c, 1.5)
		RunState.NodeType.EVENT:
			# Question mark circle
			draw_arc(pos, s, 0, TAU, 12, c, 1.5, true)
			var font := ThemeDB.fallback_font
			draw_string(font, pos + Vector2(-3, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, c)
		RunState.NodeType.BOSS:
			# Star shape
			for i in range(5):
				var angle := TAU * float(i) / 5.0 - PI / 2.0
				var tip := pos + Vector2.from_angle(angle) * s
				draw_line(pos, tip, c, 1.5)
			draw_arc(pos, s, 0, TAU, 12, c, 1.0, true)

func _node_color(type: int) -> Color:
	match type:
		RunState.NodeType.BOARD: return Color(0.3, 0.85, 1.0)
		RunState.NodeType.ELITE: return Color(1.0, 0.4, 0.1)
		RunState.NodeType.SHOP: return Color(1.0, 0.85, 0.3)
		RunState.NodeType.REST: return Color(0.3, 1.0, 0.5)
		RunState.NodeType.EVENT: return Color(0.8, 0.3, 1.0)
		RunState.NodeType.BOSS: return Color(1.0, 0.2, 0.2)
	return Color(0.5, 0.5, 0.5)
