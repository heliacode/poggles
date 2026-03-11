extends Node

signal power_up_activated(type: String)

enum Type { NONE, PRISM_SPLIT, OVERDRIVE, PHANTOM_PASS, OVERLOAD }

var active_power_up: String = ""
var _overdrive_active := false

func activate(type: String, ball: Node) -> void:
	active_power_up = type
	power_up_activated.emit(type)
	match type:
		"prism_split": _activate_prism_split(ball)
		"overdrive": _activate_overdrive()
		"phantom_pass": _activate_phantom_pass(ball)
		"overload": _activate_overload(ball)

func reset() -> void:
	active_power_up = ""
	_overdrive_active = false
	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0

func _activate_prism_split(ball: Node) -> void:
	var game: Node = ball.get_parent()
	if not game:
		return
	var ball_scene: PackedScene = load(GameConfig.BALL_SCENE_PATH)
	for angle_offset in [-15.0, 15.0]:
		var clone: RigidBody2D = ball_scene.instantiate()
		clone.position = ball.position
		clone.is_clone = true
		var rotated_vel: Vector2 = ball.linear_velocity.rotated(deg_to_rad(angle_offset))
		game.add_child(clone)
		clone.launch(rotated_vel)
		clone.ball_lost.connect(func() -> void: clone.queue_free())

func _activate_overdrive() -> void:
	_overdrive_active = true
	Engine.time_scale = 0.25
	# Use a real-time timer (process_always=true, ignore_time_scale=true)
	get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		_overdrive_active = false
	)

func _activate_phantom_pass(ball: Node) -> void:
	ball.set_collision_layer_value(1, false)
	ball.set_collision_mask_value(1, false)
	ball.phantom_active = true
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(ball):
			ball.set_collision_layer_value(1, true)
			ball.set_collision_mask_value(1, true)
			ball.phantom_active = false
	)

func _activate_overload(ball: Node) -> void:
	ball.overload_pending = true
