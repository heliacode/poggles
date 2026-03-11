extends CanvasLayer

@onready var score_label := $ScoreLabel
@onready var balls_label := $BallsLabel
@onready var orange_label := $OrangeLabel
@onready var run_info_label := $RunInfoLabel

var _fever_meter := 0.0
var _fever_pulse := 0.0
var _fever_bar: Control

func _ready() -> void:
	if run_info_label:
		run_info_label.visible = false
	# Center pivot for scale animations
	for label in [score_label, balls_label, orange_label]:
		if label:
			label.pivot_offset = label.size / 2.0
	# Create fever meter bar as a Control child
	_fever_bar = Control.new()
	_fever_bar.name = "FeverBar"
	_fever_bar.custom_minimum_size = Vector2(1280, 12)
	_fever_bar.position = Vector2(0, 50)
	_fever_bar.size = Vector2(1280, 12)
	add_child(_fever_bar)
	_fever_bar.draw.connect(_draw_fever_bar)
	FeverManager.meter_changed.connect(_on_fever_meter_changed)

func _process(delta: float) -> void:
	if _fever_meter >= 1.0:
		_fever_pulse += delta * 4.0
		_fever_bar.queue_redraw()

func _on_fever_meter_changed(value: float) -> void:
	_fever_meter = value
	_fever_bar.queue_redraw()

func _draw_fever_bar() -> void:
	if _fever_meter <= 0.0:
		return
	var bar_width := 400.0
	var bar_height := 8.0
	var bar_x := (1280.0 - bar_width) / 2.0
	var bar_y := 2.0
	# Background
	_fever_bar.draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_width + 2, bar_height + 2), Color(0.15, 0.15, 0.2, 0.6))
	# Fill
	var fill_width := bar_width * _fever_meter
	var fill_color: Color
	if _fever_meter >= 1.0:
		# Pulsing gold
		var pulse_alpha := 0.8 + sin(_fever_pulse) * 0.2
		fill_color = Color(1.0, 0.85, 0.0, pulse_alpha)
	elif _fever_meter >= 0.75:
		fill_color = Color(1.0, 0.85, 0.0, 0.9)  # Gold
	elif _fever_meter >= 0.5:
		fill_color = Color(0.7, 0.3, 1.0, 0.9)  # Purple
	else:
		fill_color = Color(0.2, 0.6, 1.0, 0.9)  # Blue
	_fever_bar.draw_rect(Rect2(bar_x, bar_y, fill_width, bar_height), fill_color)
	# Border
	_fever_bar.draw_rect(Rect2(bar_x, bar_y, bar_width, bar_height), Color(0.5, 0.5, 0.6, 0.4), false, 1.0)
	# Label
	var font: Font = ThemeDB.fallback_font
	var label_text := "FEVER!" if _fever_meter >= 1.0 else "FEVER"
	_fever_bar.draw_string(font, Vector2(bar_x + bar_width + 8, bar_y + bar_height - 1), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, fill_color)

func _pop_label(label: Control) -> void:
	if not label:
		return
	label.pivot_offset = label.size / 2.0
	var tw := create_tween()
	label.scale = Vector2(1.2, 1.2)
	tw.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func update_score(value: int) -> void:
	score_label.text = "Score: %d" % value
	_pop_label(score_label)

func update_balls(value: int) -> void:
	balls_label.text = "Balls: %d" % value
	_pop_label(balls_label)

func update_orange(remaining: int, total: int) -> void:
	orange_label.text = "Orange: %d / %d" % [remaining, total]
	_pop_label(orange_label)

func update_run_info(act: int, board: int, coins: int) -> void:
	if run_info_label:
		run_info_label.visible = true
		run_info_label.text = "Act %d  |  Board %d  |  Coins: %d" % [act, board, coins]
	queue_redraw()

func _draw() -> void:
	# Draw active relics as small icons at bottom of screen
	var relics := RelicManager.active_relics
	if relics.is_empty():
		return
	var icon_size := 20.0
	var spacing := 6.0
	var start_x := 20.0
	var y := 680.0
	for i in range(relics.size()):
		var relic := relics[i]
		var x := start_x + float(i) * (icon_size + spacing)
		var c := relic.get_rarity_color()
		# Small circle icon
		var center := Vector2(x + icon_size / 2.0, y + icon_size / 2.0)
		draw_arc(center, icon_size / 2.0, 0, TAU, 16, Color(c.r, c.g, c.b, 0.6), 1.5, true)
		draw_circle(center, 3.0, Color(c.r, c.g, c.b, 0.5))
		# First letter of relic name
		var font := ThemeDB.fallback_font
		var letter := relic.relic_name.substr(0, 1)
		draw_string(font, Vector2(center.x - 3, center.y + 4), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(c.r, c.g, c.b, 0.8))
