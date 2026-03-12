extends AnimatableBody2D

signal ball_caught

var direction := 1.0
var _pulse := 0.0
var _trail: Array[Vector2] = []
const _TRAIL_MAX := 15
var _width_mult := 1.0

@onready var collision := $CollisionShape2D
@onready var catch_area := $CatchArea

func _ready() -> void:
	add_to_group("bucket")
	_width_mult = CharacterManager.get_bucket_width_multiplier() if RunState.is_run_active else 1.0
	_setup_collision()
	_setup_catch_area()
	if has_node("BucketSprite"):
		$BucketSprite.visible = false

func _process(delta: float) -> void:
	_pulse += delta * 3.0
	_trail.append(global_position)
	if _trail.size() > _TRAIL_MAX:
		_trail.remove_at(0)
	queue_redraw()

func _draw() -> void:
	var c := GameConfig.BUCKET_COLOR
	var pulse := sin(_pulse) * 0.15 + 0.85
	var hw := GameConfig.BUCKET_WIDTH * _width_mult / 2.0
	var hh := GameConfig.BUCKET_HEIGHT / 2.0

	# Glow trail
	if _trail.size() >= 2:
		for i in range(_trail.size() - 1):
			var t := float(i) / float(_trail.size() - 1)
			var from := _trail[i] - global_position
			var to := _trail[i + 1] - global_position
			draw_line(from, to, Color(c.r, c.g, c.b, t * 0.4 * pulse), lerpf(1.0, 2.0, t))

	for i in range(3):
		var r := hw * 0.6 - float(i) * 5.0
		draw_circle(Vector2(0, -4), r, Color(c.r, c.g, c.b, 0.04 * pulse))

	draw_line(Vector2(-hw, -hh), Vector2(hw, -hh), Color(c.r, c.g, c.b, 0.7 * pulse), 1.5)
	draw_line(Vector2(-hw, hh), Vector2(hw, hh), Color(c.r, c.g, c.b, 0.5 * pulse), 1.0)
	draw_line(Vector2(-hw, -hh), Vector2(-hw, hh), Color(c.r, c.g, c.b, 0.6 * pulse), 1.0)
	draw_line(Vector2(hw, -hh), Vector2(hw, hh), Color(c.r, c.g, c.b, 0.6 * pulse), 1.0)

	draw_line(Vector2(-hw - 4, -GameConfig.BUCKET_WALL_HEIGHT), Vector2(-hw - 4, hh), Color(c.r, c.g, c.b, 0.8), 2.0)
	draw_line(Vector2(-hw - 4, -GameConfig.BUCKET_WALL_HEIGHT), Vector2(-hw, -GameConfig.BUCKET_WALL_HEIGHT), Color(c.r, c.g, c.b, 0.6), 1.5)

	draw_line(Vector2(hw + 4, -GameConfig.BUCKET_WALL_HEIGHT), Vector2(hw + 4, hh), Color(c.r, c.g, c.b, 0.8), 2.0)
	draw_line(Vector2(hw + 4, -GameConfig.BUCKET_WALL_HEIGHT), Vector2(hw, -GameConfig.BUCKET_WALL_HEIGHT), Color(c.r, c.g, c.b, 0.6), 1.5)

	for corner in [Vector2(-hw - 4, -GameConfig.BUCKET_WALL_HEIGHT), Vector2(hw + 4, -GameConfig.BUCKET_WALL_HEIGHT)]:
		draw_circle(corner, 2.0, Color(c.r, c.g, c.b, 0.9))

func _setup_collision() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(GameConfig.BUCKET_WIDTH * _width_mult, GameConfig.BUCKET_HEIGHT)
	collision.shape = shape

func _setup_catch_area() -> void:
	var area_shape := RectangleShape2D.new()
	area_shape.size = Vector2((GameConfig.BUCKET_WIDTH - 10) * _width_mult, 30)
	var area_collision: CollisionShape2D = catch_area.get_child(0)
	area_collision.shape = area_shape
	area_collision.position = Vector2(0, -20)
	catch_area.body_entered.connect(_on_catch_area_body_entered)

func _physics_process(delta: float) -> void:
	position.x += GameConfig.BUCKET_SPEED * direction * delta
	if position.x >= GameConfig.BUCKET_RIGHT_BOUND:
		direction = -1.0
	elif position.x <= GameConfig.BUCKET_LEFT_BOUND:
		direction = 1.0

func _on_catch_area_body_entered(body: Node) -> void:
	if body.has_signal("ball_lost"):
		ball_caught.emit()
