extends RigidBody2D

signal ball_lost

var _trail: Array[Vector2] = []
var _speed_ratio := 0.0
var _impact_flash := 0.0
var _impact_normal := Vector2.ZERO
var _mote_timer := 0
var score_multiplier := 1.0
var is_clone := false
var phantom_active := false
var overload_pending := false

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 10
	gravity_scale = 1.0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = GameConfig.BALL_BOUNCE
	physics_material_override.friction = GameConfig.BALL_FRICTION
	body_entered.connect(_on_body_entered)

func _draw() -> void:
	var c := GameConfig.BALL_COLOR
	var visible_count := int(lerpf(8.0, 20.0, _speed_ratio))

	# Trail with speed-reactive rendering
	var trail_start := maxi(0, _trail.size() - visible_count)
	var draw_count := _trail.size() - trail_start
	for i in range(trail_start + 1, _trail.size()):
		var local_i := i - trail_start
		var t := float(local_i) / float(draw_count)
		var alpha := pow(t, 1.5) * 0.7
		var width := t * lerpf(4.0, 2.0, _speed_ratio)
		var glow_width := width + lerpf(6.0, 2.0, _speed_ratio)
		var glow_alpha := alpha * lerpf(0.2, 0.5, _speed_ratio)
		var p1: Vector2 = _trail[i - 1] - global_position
		var p2: Vector2 = _trail[i] - global_position
		# Subtle color cooling on tail
		var trail_col := c.lerp(Color(0.85, 0.95, 1.0), (1.0 - t) * 0.2)
		draw_line(p1, p2, Color(trail_col.r, trail_col.g, trail_col.b, glow_alpha), glow_width)
		draw_line(p1, p2, Color(trail_col.r, trail_col.g, trail_col.b, alpha), width)

	# Impact flash arc
	if _impact_flash > 0:
		var impact_angle := _impact_normal.angle()
		draw_arc(Vector2.ZERO, GameConfig.BALL_RADIUS + 2, impact_angle - 0.8, impact_angle + 0.8, 8, Color(1, 1, 1, _impact_flash * 0.7), 2.0, true)

	# Outer glow
	for i in range(4):
		var r := GameConfig.BALL_RADIUS + 8.0 - float(i) * 2.0
		draw_circle(Vector2.ZERO, r, Color(c.r, c.g, c.b, 0.08))

	# Multiplier gold tint
	if score_multiplier > 1.0:
		var gold := Color(1.0, 0.85, 0.0)
		draw_circle(Vector2.ZERO, GameConfig.BALL_RADIUS + 4, Color(gold.r, gold.g, gold.b, 0.06))

	# Fever mode glow
	if FeverManager.is_fever_active:
		var fever_gold := Color(1.0, 0.85, 0.0)
		# Extra outer glow rings in gold
		for fi in range(3):
			var fr := GameConfig.BALL_RADIUS + 10.0 + float(fi) * 4.0
			draw_circle(Vector2.ZERO, fr, Color(fever_gold.r, fever_gold.g, fever_gold.b, 0.12 - float(fi) * 0.03))
		# Override trail color to gold in the trail section above is handled by c, so tint the core
		draw_circle(Vector2.ZERO, GameConfig.BALL_RADIUS + 2, Color(fever_gold.r, fever_gold.g, fever_gold.b, 0.15))

	# Phantom pass visual
	if phantom_active:
		var phantom_col := Color(0.5, 0.8, 1.0, 0.3)
		draw_arc(Vector2.ZERO, GameConfig.BALL_RADIUS + 6, 0, TAU, 32, phantom_col, 1.5, true)
		draw_circle(Vector2.ZERO, GameConfig.BALL_RADIUS + 3, Color(0.5, 0.8, 1.0, 0.08))

	# Speed ring at high velocity
	if _speed_ratio > 0.8:
		var excess := clampf((_speed_ratio - 0.8) / 0.2, 0, 1)
		var travel_angle := linear_velocity.angle()
		draw_arc(Vector2.from_angle(travel_angle) * 3, GameConfig.BALL_RADIUS + 4, travel_angle - 0.4, travel_angle + 0.4, 6, Color(c.r, c.g, c.b, 0.15 * excess), 1.0, true)

	# Wireframe ring
	draw_arc(Vector2.ZERO, GameConfig.BALL_RADIUS, 0, TAU, 32, Color(c.r, c.g, c.b, 0.9), 1.5, true)
	draw_circle(Vector2.ZERO, 3.0, Color(c.r, c.g, c.b, 0.7))
	draw_circle(Vector2.ZERO, 1.5, Color(1, 1, 1, 0.9))

func launch(velocity_vec: Vector2) -> void:
	linear_velocity = velocity_vec

func _physics_process(delta: float) -> void:
	if linear_velocity.length() > GameConfig.BALL_MAX_SPEED:
		linear_velocity = linear_velocity.normalized() * GameConfig.BALL_MAX_SPEED
	if global_position.y > GameConfig.BALL_CLEANUP_Y:
		ball_lost.emit()
		return

	_speed_ratio = clampf(linear_velocity.length() / GameConfig.BALL_MAX_SPEED, 0, 1)

	# Impact flash decay
	if _impact_flash > 0:
		_impact_flash = maxf(0, _impact_flash - delta * 8.0)

	# Spawn ambient drift motes
	_mote_timer += 1
	var spawn_interval := 3 if _speed_ratio < 0.8 else 2
	if _speed_ratio > 0.15 and _mote_timer >= spawn_interval:
		_mote_timer = 0
		var mote_count := 0
		for child in get_children():
			if child is _BallMote:
				mote_count += 1
		if mote_count < 30:
			_spawn_mote()

	# Anticipation glow on nearby pegs
	var pegs_node = get_parent().get_node_or_null("Pegs")
	if pegs_node:
		for peg in pegs_node.get_children():
			if peg.has_method("set_anticipation") and peg.has_method("is_hit") and not peg.is_hit():
				var dist := global_position.distance_to(peg.global_position)
				if dist < 80.0:
					var intensity := 1.0 - dist / 80.0
					peg.set_anticipation(intensity)

	# Phantom pass: detect nearby pegs via overlap
	if phantom_active:
		var phantom_pegs = get_parent().get_node_or_null("Pegs")
		if phantom_pegs:
			for peg in phantom_pegs.get_children():
				if peg.has_method("hit") and peg.has_method("is_hit") and not peg.is_hit():
					if global_position.distance_to(peg.global_position) < GameConfig.PEG_RADIUS + GameConfig.BALL_RADIUS + 2:
						peg.hit()

	_trail.append(global_position)
	if _trail.size() > GameConfig.BALL_TRAIL_LENGTH:
		_trail.remove_at(0)
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body.has_method("hit"):
		# Impact flash
		_impact_normal = (global_position - body.global_position).normalized()
		_impact_flash = 1.0
		# Spawn impact motes
		for i in range(3):
			_spawn_mote_at(_impact_normal, true)
		body.hit()

func _spawn_mote() -> void:
	var mote := _BallMote.new()
	var perp := Vector2(-linear_velocity.y, linear_velocity.x).normalized()
	var side := 1.0 if randf() > 0.5 else -1.0
	mote._vel = perp * side * randf_range(15, 40) - linear_velocity.normalized() * randf_range(5, 15)
	mote.position = Vector2(randf_range(-3, 3), randf_range(-3, 3))
	mote._lifetime = randf_range(0.3, 0.5)
	add_child(mote)

func _spawn_mote_at(dir: Vector2, is_impact: bool) -> void:
	var mote := _BallMote.new()
	mote._vel = dir * randf_range(60, 100) + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	mote.position = Vector2.ZERO
	mote._lifetime = randf_range(0.15, 0.25) if is_impact else randf_range(0.3, 0.5)
	add_child(mote)


class _BallMote extends Node2D:
	var _vel := Vector2.ZERO
	var _lifetime := 0.4
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _lifetime:
			queue_free()
			return
		position += _vel * delta
		_vel *= 0.94
		_vel.y += 20.0 * delta  # Slight gravity drift
		queue_redraw()

	func _draw() -> void:
		var t := 1.0 - _age / _lifetime
		draw_circle(Vector2.ZERO, 1.5 * t, Color(0.6, 0.9, 1.0, t * 0.4))
		draw_circle(Vector2.ZERO, 0.5 * t, Color(1, 1, 1, t * 0.6))
