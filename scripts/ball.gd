extends RigidBody2D

signal ball_lost

var _speed_ratio := 0.0
var _impact_flash := 0.0
var _impact_normal := Vector2.ZERO
var _mote_timer := 0
var score_multiplier := 1.0
var is_clone := false
var phantom_active := false
var overload_pending := false
var piercing_remaining := 0

var _glow_sprite: ColorRect
var _glow_material: ShaderMaterial
var _glow_shader: Shader

# Afterimage trail
var _trail_positions: Array[Vector2] = []
var _trail_velocities: Array[float] = []
const TRAIL_MAX := 12
const TRAIL_MIN_DIST := 3.0

# Impact scale pop
var _impact_scale := 1.0
var _impact_scale_vel := 0.0

# Outer glow ring for high speed
var _outer_glow_sprite: ColorRect
var _outer_glow_material: ShaderMaterial

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 10
	gravity_scale = 1.0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = GameConfig.BALL_BOUNCE
	physics_material_override.friction = GameConfig.BALL_FRICTION
	body_entered.connect(_on_body_entered)
	_setup_glow()

func _setup_glow() -> void:
	_glow_shader = load("res://shaders/neon_glow.gdshader")

	# Inner glow
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = _glow_shader
	var c := GameConfig.BALL_COLOR
	_glow_material.set_shader_parameter("glow_color", Color(c.r, c.g, c.b, 1.0))
	_glow_material.set_shader_parameter("intensity", 0.7)
	_glow_material.set_shader_parameter("falloff", 2.0)
	_glow_sprite = ColorRect.new()
	var glow_size := 80.0
	_glow_sprite.size = Vector2(glow_size, glow_size)
	_glow_sprite.position = Vector2(-glow_size / 2.0, -glow_size / 2.0)
	_glow_sprite.color = Color.WHITE
	_glow_sprite.material = _glow_material
	_glow_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_sprite.z_index = -1
	add_child(_glow_sprite)

	# Outer glow ring (visible at high speed)
	_outer_glow_material = ShaderMaterial.new()
	_outer_glow_material.shader = _glow_shader
	_outer_glow_material.set_shader_parameter("glow_color", Color(c.r, c.g, c.b, 1.0))
	_outer_glow_material.set_shader_parameter("intensity", 0.0)
	_outer_glow_material.set_shader_parameter("falloff", 3.0)
	_outer_glow_sprite = ColorRect.new()
	var outer_size := 120.0
	_outer_glow_sprite.size = Vector2(outer_size, outer_size)
	_outer_glow_sprite.position = Vector2(-outer_size / 2.0, -outer_size / 2.0)
	_outer_glow_sprite.color = Color.WHITE
	_outer_glow_sprite.material = _outer_glow_material
	_outer_glow_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outer_glow_sprite.z_index = -2
	add_child(_outer_glow_sprite)

func _draw() -> void:
	var c := GameConfig.BALL_COLOR
	var is_fever := FeverManager.is_fever_active
	var trail_color := Color(1.0, 0.85, 0.0) if is_fever else c

	# --- Trailing afterimages ---
	var trail_count := _trail_positions.size()
	if trail_count > 1:
		for i in range(trail_count):
			var t := 1.0 - float(i) / float(trail_count)
			var local_pos := _trail_positions[i] - global_position
			var speed_at := _trail_velocities[i] if i < _trail_velocities.size() else 0.0
			var speed_factor := clampf(speed_at / GameConfig.BALL_MAX_SPEED, 0, 1)

			# Scale radius and alpha with position in trail and speed
			var alpha := t * 0.35 * (0.3 + 0.7 * speed_factor)
			var radius := GameConfig.BALL_RADIUS * t * (0.5 + 0.5 * speed_factor)

			if radius > 0.5 and alpha > 0.01:
				# Outer ghost ring
				draw_arc(local_pos, radius, 0, TAU, 16,
					Color(trail_color.r, trail_color.g, trail_color.b, alpha * 0.6), 1.0, true)
				# Inner ghost core
				draw_circle(local_pos, radius * 0.4,
					Color(trail_color.r, trail_color.g, trail_color.b, alpha * 0.3))

	# --- Speed lines radiating backward at high speed ---
	if _speed_ratio > 0.5:
		var excess := clampf((_speed_ratio - 0.5) / 0.5, 0, 1)
		var travel_dir := linear_velocity.normalized()
		var line_count := int(3 + excess * 5)  # 3-8 lines
		for i in range(line_count):
			var spread := randf_range(-0.6, 0.6)
			var line_dir := (-travel_dir).rotated(spread)
			var line_start := line_dir * (GameConfig.BALL_RADIUS + 2.0)
			var line_len := randf_range(6.0, 16.0) * excess
			var line_end := line_start + line_dir * line_len
			var line_alpha := randf_range(0.1, 0.3) * excess
			draw_line(line_start, line_end,
				Color(c.r, c.g, c.b, line_alpha), 1.0, true)

	# --- Impact flash arc (bigger) ---
	if _impact_flash > 0:
		var impact_angle := _impact_normal.angle()
		# Primary flash arc — wider and brighter
		draw_arc(Vector2.ZERO, GameConfig.BALL_RADIUS + 3, impact_angle - 1.2, impact_angle + 1.2,
			12, Color(1, 1, 1, _impact_flash * 0.85), 2.5, true)
		# Secondary outer flash ring
		draw_arc(Vector2.ZERO, GameConfig.BALL_RADIUS + 6, impact_angle - 0.6, impact_angle + 0.6,
			8, Color(c.r, c.g, c.b, _impact_flash * 0.4), 1.5, true)
		# Flash bloom circle
		if _impact_flash > 0.5:
			var bloom_alpha := (_impact_flash - 0.5) * 0.6
			draw_circle(Vector2.ZERO, GameConfig.BALL_RADIUS + 4,
				Color(1, 1, 1, bloom_alpha * 0.15))

	# Phantom pass visual
	if phantom_active:
		var phantom_col := Color(0.5, 0.8, 1.0, 0.3)
		draw_arc(Vector2.ZERO, GameConfig.BALL_RADIUS + 6, 0, TAU, 32, phantom_col, 1.5, true)

	# Speed ring at high velocity
	if _speed_ratio > 0.8:
		var excess := clampf((_speed_ratio - 0.8) / 0.2, 0, 1)
		var travel_angle := linear_velocity.angle()
		draw_arc(Vector2.from_angle(travel_angle) * 3, GameConfig.BALL_RADIUS + 4,
			travel_angle - 0.4, travel_angle + 0.4, 6,
			Color(c.r, c.g, c.b, 0.15 * excess), 1.0, true)

	# --- Fever mode: golden inner ring ---
	if is_fever:
		var fever_pulse := 0.7 + sin(Time.get_ticks_msec() * 0.008) * 0.3
		draw_arc(Vector2.ZERO, GameConfig.BALL_RADIUS + 1, 0, TAU, 32,
			Color(1.0, 0.85, 0.0, 0.5 * fever_pulse), 1.0, true)
		draw_arc(Vector2.ZERO, GameConfig.BALL_RADIUS + 3, 0, TAU, 24,
			Color(1.0, 0.7, 0.0, 0.2 * fever_pulse), 0.8, true)

	# Wireframe ring — scale with impact pop
	var ring_scale := _impact_scale
	draw_arc(Vector2.ZERO, GameConfig.BALL_RADIUS * ring_scale, 0, TAU, 32,
		Color(c.r, c.g, c.b, 0.9), 1.5, true)
	draw_circle(Vector2.ZERO, 3.0 * ring_scale, Color(c.r, c.g, c.b, 0.7))
	draw_circle(Vector2.ZERO, 1.5 * ring_scale, Color(1, 1, 1, 0.9))

func launch(velocity_vec: Vector2) -> void:
	linear_velocity = velocity_vec
	_trail_positions.clear()
	_trail_velocities.clear()

func _physics_process(delta: float) -> void:
	if linear_velocity.length() > GameConfig.BALL_MAX_SPEED:
		linear_velocity = linear_velocity.normalized() * GameConfig.BALL_MAX_SPEED
	if global_position.y > GameConfig.BALL_CLEANUP_Y:
		ball_lost.emit()
		return

	_speed_ratio = clampf(linear_velocity.length() / GameConfig.BALL_MAX_SPEED, 0, 1)

	# --- Update trail ---
	_update_trail()

	# --- Impact scale pop spring physics ---
	if _impact_scale != 1.0 or _impact_scale_vel != 0.0:
		var spring_force := (1.0 - _impact_scale) * 180.0  # Spring stiffness
		var damping := _impact_scale_vel * 12.0  # Damping
		_impact_scale_vel += (spring_force - damping) * delta
		_impact_scale += _impact_scale_vel * delta
		if absf(_impact_scale - 1.0) < 0.005 and absf(_impact_scale_vel) < 0.01:
			_impact_scale = 1.0
			_impact_scale_vel = 0.0

	# Impact flash decay
	if _impact_flash > 0:
		_impact_flash = maxf(0, _impact_flash - delta * 8.0)

	# Update glow shader
	_update_glow()

	# Spawn ambient drift motes — more at high speed
	_mote_timer += 1
	var spawn_interval := 3 if _speed_ratio < 0.5 else (2 if _speed_ratio < 0.8 else 1)
	if _speed_ratio > 0.15 and _mote_timer >= spawn_interval:
		_mote_timer = 0
		var mote_count := 0
		for child in get_children():
			if child is _BallMote:
				mote_count += 1
		var mote_cap := 30 if _speed_ratio < 0.8 else 50
		if mote_count < mote_cap:
			_spawn_mote()
			# Double motes at very high speed
			if _speed_ratio > 0.85 and mote_count < mote_cap - 1:
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

	queue_redraw()

func _update_trail() -> void:
	var speed := linear_velocity.length()
	# Only record trail when moving
	if speed < 10.0:
		# Fade out trail when slow
		if _trail_positions.size() > 0:
			_trail_positions.remove_at(0)
			_trail_velocities.remove_at(0)
		return

	# Dynamic trail length based on speed — more positions at higher speed
	var desired_len := int(lerp(4.0, float(TRAIL_MAX), _speed_ratio))

	# Add current position if far enough from last recorded
	if _trail_positions.size() == 0 or global_position.distance_to(_trail_positions[_trail_positions.size() - 1]) > TRAIL_MIN_DIST:
		_trail_positions.append(global_position)
		_trail_velocities.append(speed)

	# Trim to desired length
	while _trail_positions.size() > desired_len:
		_trail_positions.remove_at(0)
		_trail_velocities.remove_at(0)

func _update_glow() -> void:
	if not _glow_material:
		return
	var c := GameConfig.BALL_COLOR
	var glow_intensity := 0.7 + _speed_ratio * 0.8  # Increased from 0.5
	var glow_color := Color(c.r, c.g, c.b, 1.0)

	# Fever mode: golden glow
	if FeverManager.is_fever_active:
		glow_color = Color(1.0, 0.85, 0.0, 1.0)
		glow_intensity += 0.6  # Increased from 0.4

	# Multiplier: warm tint
	if score_multiplier > 1.0:
		glow_color = glow_color.lerp(Color(1.0, 0.85, 0.0, 1.0), 0.3)
		glow_intensity += 0.2

	# Impact flash boost — bigger boost
	if _impact_flash > 0:
		glow_color = glow_color.lerp(Color.WHITE, _impact_flash * 0.7)
		glow_intensity += _impact_flash * 1.5

	_glow_material.set_shader_parameter("glow_color", glow_color)
	_glow_material.set_shader_parameter("intensity", glow_intensity)
	_glow_material.set_shader_parameter("pulse", _speed_ratio * 0.5)

	# Outer glow ring — fade in at high speed
	if _outer_glow_material:
		var outer_intensity := 0.0
		if _speed_ratio > 0.5:
			outer_intensity = clampf((_speed_ratio - 0.5) / 0.5, 0, 1) * 0.5
		if FeverManager.is_fever_active:
			outer_intensity += 0.3
		if _impact_flash > 0:
			outer_intensity += _impact_flash * 0.4
		_outer_glow_material.set_shader_parameter("glow_color", glow_color)
		_outer_glow_material.set_shader_parameter("intensity", outer_intensity)

func _on_body_entered(body: Node) -> void:
	if body.has_method("hit"):
		# Impact flash
		_impact_normal = (global_position - body.global_position).normalized()
		_impact_flash = 1.0

		# Impact scale pop — spring to 1.3x then back
		_impact_scale = 1.3
		_impact_scale_vel = 0.0

		# Spawn impact motes — 6-8 for over-response
		var impact_mote_count := randi_range(6, 8)
		for i in range(impact_mote_count):
			var scatter_dir := _impact_normal.rotated(randf_range(-0.8, 0.8))
			_spawn_mote_at(scatter_dir, true)

		body.hit()
		# Piercing: temporarily disable collision with this peg
		if piercing_remaining > 0 and body is StaticBody2D:
			piercing_remaining -= 1
			body.set_collision_layer_value(1, false)
			# Re-enable after a short delay
			get_tree().create_timer(0.3).timeout.connect(func():
				if is_instance_valid(body):
					body.set_collision_layer_value(1, true)
			)

func _spawn_mote() -> void:
	var mote := _BallMote.new()
	var perp := Vector2(-linear_velocity.y, linear_velocity.x).normalized()
	var side := 1.0 if randf() > 0.5 else -1.0
	mote._vel = perp * side * randf_range(15, 40) - linear_velocity.normalized() * randf_range(5, 15)
	mote.position = Vector2(randf_range(-3, 3), randf_range(-3, 3))
	mote._lifetime = randf_range(0.3, 0.5)
	mote._is_fever = FeverManager.is_fever_active
	add_child(mote)

func _spawn_mote_at(dir: Vector2, is_impact: bool) -> void:
	var mote := _BallMote.new()
	mote._vel = dir * randf_range(60, 120) + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	mote.position = Vector2.ZERO
	mote._lifetime = randf_range(0.18, 0.35) if is_impact else randf_range(0.3, 0.5)
	mote._is_impact = is_impact
	mote._is_fever = FeverManager.is_fever_active
	add_child(mote)


class _BallMote extends Node2D:
	var _vel := Vector2.ZERO
	var _lifetime := 0.4
	var _age := 0.0
	var _is_impact := false
	var _is_fever := false

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
		var base_color := Color(1.0, 0.85, 0.0) if _is_fever else Color(0.6, 0.9, 1.0)
		var size_mult := 1.8 if _is_impact else 1.0
		# Outer glow
		draw_circle(Vector2.ZERO, 1.5 * t * size_mult,
			Color(base_color.r, base_color.g, base_color.b, t * 0.4))
		# Hot core
		draw_circle(Vector2.ZERO, 0.5 * t * size_mult,
			Color(1, 1, 1, t * 0.6))
