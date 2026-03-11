extends Node2D

var _pulse := 0.0
var _node_rects: Array = []  # Array of {rect: Rect2, row: int, col: int}
var _hover_index := -1

@onready var background := $Background

func _ready() -> void:
	_build_node_rects()

func _process(delta: float) -> void:
	_pulse += delta * 2.5
	_update_hover()
	queue_redraw()

func _build_node_rects() -> void:
	_node_rects.clear()
	var map := RunState.route_map
	var vp := GameConfig.VIEWPORT_SIZE
	var start_y := 200.0
	var row_height := 100.0
	var node_width := 160.0
	var node_height := 60.0

	for row_idx in range(map.size()):
		var row: Array = map[row_idx]
		var total_width := float(row.size()) * node_width + float(row.size() - 1) * 30.0
		var start_x := (vp.x - total_width) / 2.0

		for col_idx in range(row.size()):
			var x := start_x + float(col_idx) * (node_width + 30.0)
			var y := start_y + float(row_idx) * row_height
			var rect := Rect2(x, y, node_width, node_height)
			_node_rects.append({"rect": rect, "row": row_idx, "col": col_idx})

func _update_hover() -> void:
	var mouse := get_global_mouse_position()
	_hover_index = -1
	for i in range(_node_rects.size()):
		var info: Dictionary = _node_rects[i]
		if info["row"] == RunState.route_position and info["rect"].has_point(mouse):
			_hover_index = i
			break

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check click position directly (supports MCP simulated clicks)
		var click_pos: Vector2 = event.position
		var clicked_index := -1
		for i in range(_node_rects.size()):
			var info: Dictionary = _node_rects[i]
			if info["row"] == RunState.route_position and info["rect"].has_point(click_pos):
				clicked_index = i
				break
		if clicked_index < 0:
			clicked_index = _hover_index
		if clicked_index >= 0:
			var info: Dictionary = _node_rects[clicked_index]
			var chosen := RunState.advance_route(info["col"])
			if chosen.is_empty():
				return
			_handle_node(chosen)

func _handle_node(node: Dictionary) -> void:
	var type: int = node.get("type", RunState.NodeType.BOARD)
	match type:
		RunState.NodeType.BOARD, RunState.NodeType.ELITE, RunState.NodeType.BOSS:
			SceneManager.change_scene(GameConfig.GAMEPLAY_SCENE_PATH)
		RunState.NodeType.SHOP:
			# TODO: shop scene, for now give some balls and advance
			RunState.add_balls(1)
			RunState.add_coins(10)
			_build_node_rects()
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

	# Title
	var act_label := RunState.get_act_label()
	var title := "ACT %d: %s" % [RunState.current_act, act_label.to_upper()]
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	draw_string(font, Vector2(center_x - title_size.x / 2.0, 50), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.3, 0.85, 1.0, pulse))

	# Board progress
	var progress := "Board %d / %d" % [RunState.get_current_board_number(), RunState.get_total_boards()]
	var prog_size := font.get_string_size(progress, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	draw_string(font, Vector2(center_x - prog_size.x / 2.0, 80), progress, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.7, 1.0, 0.6))

	# Stats bar
	var stats := "Balls: %d  |  Coins: %d  |  Score: %d" % [RunState.balls_remaining, RunState.coins, RunState.score]
	var stats_size := font.get_string_size(stats, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(font, Vector2(center_x - stats_size.x / 2.0, 110), stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.8, 1.0, 0.7))

	# Instruction
	var instr := "Choose your path"
	var instr_size := font.get_string_size(instr, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	draw_string(font, Vector2(center_x - instr_size.x / 2.0, 160), instr, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.6, 0.8, 0.5 * pulse))

	# Draw connection lines between rows
	for i in range(_node_rects.size()):
		var info: Dictionary = _node_rects[i]
		var row: int = info["row"]
		if row == 0:
			continue
		var rect: Rect2 = info["rect"]
		var top_center := Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y)

		# Connect to all nodes in previous row
		for j in range(_node_rects.size()):
			var other: Dictionary = _node_rects[j]
			if other["row"] == row - 1:
				var other_rect: Rect2 = other["rect"]
				var bot_center := Vector2(other_rect.position.x + other_rect.size.x / 2.0, other_rect.end.y)
				var line_alpha := 0.15
				if other["row"] < RunState.route_position:
					line_alpha = 0.05  # Already passed
				draw_line(bot_center, top_center, Color(0.3, 0.6, 0.9, line_alpha), 1.0)

	# Draw nodes
	for i in range(_node_rects.size()):
		var info: Dictionary = _node_rects[i]
		var rect: Rect2 = info["rect"]
		var row: int = info["row"]
		var col: int = info["col"]
		var is_current_row := row == RunState.route_position
		var is_past := row < RunState.route_position
		var is_hovered := i == _hover_index

		# Get node data
		var row_data: Array = map[row] if row < map.size() else []
		var node_data: Dictionary = row_data[col] if col < row_data.size() else {}
		var label: String = node_data.get("label", "???")
		var node_type: int = node_data.get("type", 0)

		# Color based on type
		var c := _node_color(node_type)
		var alpha := 0.3
		if is_current_row:
			alpha = 0.8 if is_hovered else 0.6
		elif is_past:
			alpha = 0.15

		# Background glow
		if is_current_row:
			draw_rect(rect.grow(3), Color(c.r, c.g, c.b, 0.04 * pulse), true)

		# Border
		var border_points := PackedVector2Array([
			rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y), rect.position,
		])
		draw_polyline(border_points, Color(c.r, c.g, c.b, alpha * pulse), 1.5 if is_current_row else 1.0)

		# Label
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		var label_pos := Vector2(
			rect.position.x + (rect.size.x - label_size.x) / 2.0,
			rect.position.y + rect.size.y / 2.0 + 5.0
		)
		draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(c.r, c.g, c.b, alpha * pulse))

		# Hover highlight
		if is_hovered:
			draw_rect(rect.grow(1), Color(c.r, c.g, c.b, 0.08), true)

func _node_color(type: int) -> Color:
	match type:
		RunState.NodeType.BOARD: return Color(0.3, 0.85, 1.0)
		RunState.NodeType.ELITE: return Color(1.0, 0.4, 0.1)
		RunState.NodeType.SHOP: return Color(1.0, 0.85, 0.3)
		RunState.NodeType.REST: return Color(0.3, 1.0, 0.5)
		RunState.NodeType.EVENT: return Color(0.8, 0.3, 1.0)
		RunState.NodeType.BOSS: return Color(1.0, 0.2, 0.2)
	return Color(0.5, 0.5, 0.5)
