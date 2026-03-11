extends CanvasLayer

@onready var score_label := $ScoreLabel
@onready var balls_label := $BallsLabel
@onready var orange_label := $OrangeLabel
@onready var run_info_label := $RunInfoLabel

func _ready() -> void:
	if run_info_label:
		run_info_label.visible = false

func update_score(value: int) -> void:
	score_label.text = "Score: %d" % value

func update_balls(value: int) -> void:
	balls_label.text = "Balls: %d" % value

func update_orange(remaining: int, total: int) -> void:
	orange_label.text = "Orange: %d / %d" % [remaining, total]

func update_run_info(act: int, board: int, coins: int) -> void:
	if run_info_label:
		run_info_label.visible = true
		run_info_label.text = "Act %d  |  Board %d  |  Coins: %d" % [act, board, coins]
