extends StaticBody2D

signal peg_hit(peg: StaticBody2D)

@export var peg_type: String = "blue"
@export var special_type: String = ""
@export var power_up_type: String = ""

var _hit := false
var _color: Color
var _pulse := 0.0
var _hit_flash := 0.0
var _special_pulse := 0.0
var _armor_hits := 0
var _bolt_rng_offset := 0.0
var _anticipation := 0.0
var _move_origin := Vector2.ZERO
var _move_time := 0.0
var _moving := false

var _glow_sprite: ColorRect
var _glow_material: ShaderMaterial

@onready var collision := $CollisionShape2D

func _ready() -> void:
	_color = GameConfig.PEG_NEON_COLORS.get(peg_type, Color.WHITE)
	_pulse = randf() * TAU
	_bolt_rng_offset = randf() * 100.0
	if special_type == "armored":
		_armor_hits = 2
	_setup_collision()
	if has_node("Sprite"):
		$Sprite.visible = false
	_setup_glow()
	if special_type == "moving":
		_moving = true
		_move_origin = position
		_move_time = randf() * TAU  # Random phase so they don't all sync

func _setup_glow() -> void:
	var shader := load("res://shaders/peg_glow.gdshader")
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = shader
	_glow_material.set_shader_parameter("glow_color", Color(_color.r, _color.g, _color.b, 1.0))
	_glow_material.set_shader_parameter("intensity", 0.5)
	_glow_material.set_shader_parameter("falloff", 2.5)
	_glow_sprite = ColorRect.new()
	var glow_size := 100.0
	_glow_sprite.size = Vector2(glow_size, glow_size)
	_glow_sprite.position = Vector2(-glow_size / 2.0, -glow_size / 2.0)
	_glow_sprite.color = Color.WHITE
	_glow_sprite.material = _glow_material
	_glow_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_sprite.z_index = -1
	add_child(_glow_sprite)

func _physics_process(delta: float) -> void:
	if _moving and not _hit:
		_move_time += delta * 2.0  # Controls speed of oscillation
		var offset := sin(_move_time) * GameConfig.MOVING_PEG_RANGE
		position.x = _move_origin.x + offset
		# Set constant_linear_velocity so ball bounces correctly off the moving surface
		constant_linear_velocity = Vector2(cos(_move_time) * 2.0 * GameConfig.MOVING_PEG_RANGE, 0)
	elif _moving and _hit:
		constant_linear_velocity = Vector2.ZERO

func set_anticipation(val: float) -> void:
	_anticipation = val

func flash_celebrate() -> void:
	_hit_flash = 1.0

func _process(delta: float) -> void:
	_pulse += delta * 2.5
	_special_pulse += delta
	if _hit_flash > 0:
		_hit_flash = maxf(0, _hit_flash - delta * 3.0)
	if _anticipation > 0:
		_anticipation = maxf(0, _anticipation - delta * 5.0)
	_update_glow_shader()
	queue_redraw()

func _update_glow_shader() -> void:
	if not _glow_material:
		return
	var pulse_val := sin(_pulse) * 0.5 + 0.5
	_glow_material.set_shader_parameter("glow_color", Color(_color.r, _color.g, _color.b, 1.0))
	_glow_material.set_shader_parameter("pulse", pulse_val)
	_glow_material.set_shader_parameter("hit_flash", _hit_flash)
	_glow_material.set_shader_parameter("anticipation", _anticipation)
	# Boost intensity when hit
	var base_intensity := 0.7 if _hit else 0.5
	_glow_material.set_shader_parameter("intensity", base_intensity)

func _draw() -> void:
	var pulse := sin(_pulse) * 0.3 + 0.7
	var base := _color

	# Main wireframe shape — colorblind mode uses distinct shapes per type
	var ring_alpha := 0.8 + pulse * 0.2
	if _hit:
		ring_alpha = 1.0

	if SaveData.get_colorblind_mode():
		_draw_colorblind_shape(base, ring_alpha, pulse)
	else:
		draw_arc(Vector2.ZERO, GameConfig.PEG_RADIUS, 0, TAU, 48, Color(base.r, base.g, base.b, ring_alpha), 2.0, true)
		draw_arc(Vector2.ZERO, GameConfig.PEG_RADIUS * 0.6, 0, TAU, 32, Color(base.r, base.g, base.b, ring_alpha * 0.4), 1.0, true)

	var dot_size := 2.5 + pulse * 0.5
	draw_circle(Vector2.ZERO, dot_size, Color(base.r, base.g, base.b, ring_alpha))
	draw_circle(Vector2.ZERO, 1.5, Color(1, 1, 1, ring_alpha * 0.7))

	# Special type overlays
	if not _hit:
		_draw_special(ring_alpha, pulse)

	# Power-up label on green pegs
	if power_up_type != "" and not _hit:
		var label: String = power_up_type.substr(0, 1).to_upper()
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(-4, -GameConfig.PEG_RADIUS - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.1, 1.0, 0.3, 0.7))

func _draw_colorblind_shape(base: Color, ring_alpha: float, pulse: float) -> void:
	var r := GameConfig.PEG_RADIUS
	var c := Color(base.r, base.g, base.b, ring_alpha)
	var c_inner := Color(base.r, base.g, base.b, ring_alpha * 0.4)
	match peg_type:
		"blue":
			# Circle (default) — same as normal
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, c, 2.0, true)
			draw_arc(Vector2.ZERO, r * 0.6, 0, TAU, 32, c_inner, 1.0, true)
		"orange":
			# Diamond shape
			var pts := PackedVector2Array([
				Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0), Vector2(0, -r)
			])
			draw_polyline(pts, c, 2.0)
			var inner := r * 0.5
			var ipts := PackedVector2Array([
				Vector2(0, -inner), Vector2(inner, 0), Vector2(0, inner), Vector2(-inner, 0), Vector2(0, -inner)
			])
			draw_polyline(ipts, c_inner, 1.0)
		"green":
			# Triangle
			var pts := PackedVector2Array([
				Vector2(0, -r), Vector2(r * 0.866, r * 0.5), Vector2(-r * 0.866, r * 0.5), Vector2(0, -r)
			])
			draw_polyline(pts, c, 2.0)
			var inner := r * 0.5
			var ipts := PackedVector2Array([
				Vector2(0, -inner), Vector2(inner * 0.866, inner * 0.5), Vector2(-inner * 0.866, inner * 0.5), Vector2(0, -inner)
			])
			draw_polyline(ipts, c_inner, 1.0)
		"purple":
			# Star shape (5-pointed)
			var outer_pts := PackedVector2Array()
			for i in range(5):
				var angle := TAU * float(i) / 5.0 - PI / 2.0
				outer_pts.append(Vector2.from_angle(angle) * r)
				var inner_angle := angle + TAU / 10.0
				outer_pts.append(Vector2.from_angle(inner_angle) * (r * 0.4))
			outer_pts.append(outer_pts[0])
			draw_polyline(outer_pts, c, 2.0)
		_:
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, c, 2.0, true)

func _draw_special(ring_alpha: float, pulse: float) -> void:
	match special_type:
		"bomb": _draw_bomb(ring_alpha, pulse)
		"armored": _draw_armored(ring_alpha)
		"multiplier": _draw_multiplier(ring_alpha, pulse)
		"chain": _draw_chain(ring_alpha)
		"gravity": _draw_gravity(ring_alpha)
		"moving": _draw_moving(ring_alpha, pulse)

func _draw_bomb(ring_alpha: float, pulse: float) -> void:
	var bc: Color = GameConfig.SPECIAL_PEG_COLORS["bomb"]
	# Rotating starburst
	for i in range(6):
		var angle := _special_pulse * 0.5 + TAU * float(i) / 6.0
		var tip := Vector2.from_angle(angle) * 8.0
		draw_line(Vector2.ZERO, tip, Color(bc.r, bc.g, bc.b, 0.7), 1.5)
	# Dashed danger ring
	for i in range(6):
		var start_a := TAU * float(i) / 6.0 + _special_pulse * 0.3
		draw_arc(Vector2.ZERO, GameConfig.PEG_RADIUS + 6, start_a, start_a + TAU / 12.0, 6, Color(bc.r, bc.g, bc.b, 0.35 + pulse * 0.15), 1.0, true)
	# Pulsing red glow
	for i in range(3):
		var r := 20.0 + float(i) * 4.0
		draw_circle(Vector2.ZERO, r, Color(bc.r, bc.g, bc.b, 0.04 * (sin(_special_pulse * 2.0) * 0.5 + 0.5)))

func _draw_armored(ring_alpha: float) -> void:
	var ac: Color = GameConfig.SPECIAL_PEG_COLORS["armored"]
	# Armor rings based on remaining hits
	for layer in range(_armor_hits):
		var r := GameConfig.PEG_RADIUS + 3.0 + float(layer) * 3.0
		var a := 0.8 - float(layer) * 0.3
		draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(ac.r, ac.g, ac.b, a), 2.0 - float(layer) * 0.5, true)
	# Corner diamonds on outer ring
	if _armor_hits > 0:
		for i in range(4):
			var angle := TAU * float(i) / 4.0 + _special_pulse * 0.2
			var center := Vector2.from_angle(angle) * (GameConfig.PEG_RADIUS + 3.0)
			var s := 2.5
			var pts := PackedVector2Array([
				center + Vector2(0, -s), center + Vector2(s, 0),
				center + Vector2(0, s), center + Vector2(-s, 0),
			])
			draw_colored_polygon(pts, Color(ac.r, ac.g, ac.b, 0.5))

func _draw_multiplier(ring_alpha: float, pulse: float) -> void:
	var gc: Color = GameConfig.SPECIAL_PEG_COLORS["multiplier"]
	# Orbiting dots
	for i in range(4):
		var angle := _special_pulse * TAU / 3.0 + TAU * float(i) / 4.0
		var pos := Vector2.from_angle(angle) * (GameConfig.PEG_RADIUS + 4)
		draw_circle(pos, 1.5, Color(gc.r, gc.g, gc.b, 0.7))
	# x2 text
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-6, 5), "x2", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(gc.r, gc.g, gc.b, 0.9))
	# Gold glow
	for i in range(3):
		draw_circle(Vector2.ZERO, 18.0 + float(i) * 4.0, Color(gc.r, gc.g, gc.b, 0.03))

func _draw_chain(ring_alpha: float) -> void:
	var cc: Color = GameConfig.SPECIAL_PEG_COLORS["chain"]
	# Electric bolt pattern (3 jagged lines)
	var t := _special_pulse * 2.0
	var refresh := int(t) % 100  # Changes every ~0.5s
	for arm in range(3):
		var base_angle := TAU * float(arm) / 3.0
		var prev := Vector2.ZERO
		for seg in range(4):
			var r := 4.0 + float(seg) * 3.0
			var jitter := sin(float(refresh + arm * 37 + seg * 13) * 7.3) * 3.0
			var angle := base_angle + jitter * 0.05
			var next := Vector2.from_angle(angle) * r + Vector2.from_angle(angle + PI / 2) * jitter
			draw_line(prev, next, Color(cc.r, cc.g, cc.b, 0.5), 1.0)
			prev = next
	# Bright center dot
	draw_circle(Vector2.ZERO, 1.5, Color(0.5, 1.0, 1.0, 0.8))

func _draw_gravity(ring_alpha: float) -> void:
	var vc: Color = GameConfig.SPECIAL_PEG_COLORS["gravity"]
	# Swirling spiral arms
	for arm in range(2):
		var arm_offset := PI * float(arm)
		for seg in range(6):
			var r := 4.0 + float(seg) * 2.0
			var angle_start := arm_offset + _special_pulse * 1.5 + float(seg) * 0.3
			draw_arc(Vector2.ZERO, r, angle_start, angle_start + TAU / 6.0, 6, Color(vc.r, vc.g, vc.b, 0.6 - float(seg) * 0.08), 1.0, true)
	# Dashed outer ring
	for i in range(12):
		var a := TAU * float(i) / 12.0 + _special_pulse * 0.5
		if i % 2 == 0:
			draw_arc(Vector2.ZERO, GameConfig.PEG_RADIUS + 8, a, a + TAU / 24.0, 4, Color(vc.r, vc.g, vc.b, 0.2 + sin(_pulse) * 0.1), 1.0, true)

func _draw_moving(ring_alpha: float, pulse: float) -> void:
	var mc: Color = GameConfig.SPECIAL_PEG_COLORS["moving"]
	# Offset to account for current movement (draw path relative to origin, not moving peg)
	var cur_offset := position.x - _move_origin.x if _moving else 0.0
	# Ghost path line showing patrol range (stays fixed in world space)
	var path_alpha := 0.15 + sin(_pulse) * 0.05
	draw_line(Vector2(-GameConfig.MOVING_PEG_RANGE - cur_offset, 0), Vector2(GameConfig.MOVING_PEG_RANGE - cur_offset, 0), Color(mc.r, mc.g, mc.b, path_alpha), 1.0)
	# Small endpoint dots
	draw_circle(Vector2(-GameConfig.MOVING_PEG_RANGE - cur_offset, 0), 2.0, Color(mc.r, mc.g, mc.b, path_alpha * 0.7))
	draw_circle(Vector2(GameConfig.MOVING_PEG_RANGE - cur_offset, 0), 2.0, Color(mc.r, mc.g, mc.b, path_alpha * 0.7))
	# Direction arrow (shows current movement direction)
	var dir_x := cos(_move_time) * 8.0
	var arrow_tip := Vector2(dir_x, 0)
	var arrow_back_l := Vector2(dir_x - sign(dir_x) * 4.0, -3.0)
	var arrow_back_r := Vector2(dir_x - sign(dir_x) * 4.0, 3.0)
	draw_line(arrow_tip, arrow_back_l, Color(mc.r, mc.g, mc.b, 0.5), 1.5)
	draw_line(arrow_tip, arrow_back_r, Color(mc.r, mc.g, mc.b, 0.5), 1.5)
	# Motion trail lines
	for i in range(3):
		var trail_offset := -sign(cos(_move_time)) * (float(i + 1) * 5.0)
		var trail_alpha := 0.2 - float(i) * 0.06
		draw_line(Vector2(trail_offset, -GameConfig.PEG_RADIUS * 0.5), Vector2(trail_offset, GameConfig.PEG_RADIUS * 0.5), Color(mc.r, mc.g, mc.b, trail_alpha), 1.0)

func _setup_collision() -> void:
	var shape := CircleShape2D.new()
	shape.radius = GameConfig.PEG_RADIUS
	collision.shape = shape

func get_peg_type() -> String:
	return peg_type

func get_special_type() -> String:
	return special_type

func is_hit() -> bool:
	return _hit

func hit() -> void:
	if _hit:
		return

	# Armored: absorb hits
	if special_type == "armored" and _armor_hits > 0:
		_armor_hits -= 1
		_hit_flash = 0.6
		_spawn_armor_shards()
		AudioManager.play_sfx("armor_crack")
		return

	_hit = true
	if _moving:
		_moving = false
		constant_linear_velocity = Vector2.ZERO
	_hit_flash = 1.0
	_color = GameConfig.PEG_HIT_COLORS.get(peg_type, Color.WHITE)

	match special_type:
		"bomb": _spawn_bomb_particles()
		"chain": _spawn_chain_particles()
		"gravity": _spawn_gravity_particles()
		"multiplier": _spawn_multiplier_particles()
		"moving": _spawn_moving_particles()
		_: _spawn_hit_particles()

	peg_hit.emit(self)

func _spawn_hit_particles() -> void:
	for i in range(8):
		var spark := _NeonSpark.new()
		spark._color = _color
		spark._angle = TAU * float(i) / 8.0 + randf() * 0.3
		spark._speed = randf_range(80, 160)
		add_child(spark)

func _spawn_bomb_particles() -> void:
	var bc: Color = GameConfig.SPECIAL_PEG_COLORS["bomb"]
	for i in range(24):
		var spark := _NeonSpark.new()
		spark._color = bc.lerp(_color, 0.3)
		spark._angle = TAU * float(i) / 24.0 + randf() * 0.2
		spark._speed = randf_range(150, 300)
		spark._lifetime = 0.6
		add_child(spark)
	# Expanding ring
	var ring := _ExpandRing.new()
	ring._color = bc
	ring._max_radius = GameConfig.BOMB_RADIUS
	ring.global_position = global_position
	get_parent().add_child(ring)

func _spawn_chain_particles() -> void:
	var cc: Color = GameConfig.SPECIAL_PEG_COLORS["chain"]
	for i in range(8):
		var spark := _NeonSpark.new()
		spark._color = cc
		spark._angle = TAU * float(i) / 8.0 + randf() * 0.3
		spark._speed = randf_range(60, 120)
		spark._lifetime = 0.3
		add_child(spark)

func _spawn_gravity_particles() -> void:
	var vc: Color = GameConfig.SPECIAL_PEG_COLORS["gravity"]
	# Inward-converging sparks
	for i in range(12):
		var spark := _NeonSpark.new()
		spark._color = vc
		spark._angle = TAU * float(i) / 12.0
		spark._speed = randf_range(-80, -40)  # Negative = inward
		spark._lifetime = 0.4
		spark.position = Vector2.from_angle(TAU * float(i) / 12.0) * randf_range(30, 50)
		add_child(spark)
	# Expanding radius indicator
	var ring := _ExpandRing.new()
	ring._color = vc
	ring._max_radius = GameConfig.GRAVITY_WELL_RADIUS
	ring._duration = 0.5
	ring.global_position = global_position
	get_parent().add_child(ring)

func _spawn_multiplier_particles() -> void:
	var gc: Color = GameConfig.SPECIAL_PEG_COLORS["multiplier"]
	for i in range(8):
		var spark := _NeonSpark.new()
		spark._color = gc
		spark._angle = TAU * float(i) / 8.0 + 0.5  # Spiral offset
		spark._speed = randf_range(80, 140)
		spark._lifetime = 0.4
		add_child(spark)
	_spawn_hit_particles()

func _spawn_moving_particles() -> void:
	var mc: Color = GameConfig.SPECIAL_PEG_COLORS["moving"]
	# Satisfying "pinned" effect - sparks fly in the direction of movement
	for i in range(10):
		var spark := _NeonSpark.new()
		spark._color = mc
		spark._angle = randf_range(-0.5, 0.5)  # Mostly forward
		spark._speed = randf_range(100, 200)
		spark._lifetime = 0.4
		add_child(spark)
	_spawn_hit_particles()

func _spawn_armor_shards() -> void:
	var ac: Color = GameConfig.SPECIAL_PEG_COLORS["armored"]
	for i in range(6):
		var shard := _ArmorShard.new()
		shard._color = ac
		shard._angle = TAU * float(i) / 6.0 + randf() * 0.5
		shard._speed = randf_range(80, 140)
		shard.position = Vector2.from_angle(shard._angle) * (GameConfig.PEG_RADIUS + 3)
		get_parent().add_child(shard)
		shard.global_position = global_position + Vector2.from_angle(shard._angle) * (GameConfig.PEG_RADIUS + 3)

func remove_peg() -> void:
	for i in range(16):
		var spark := _NeonSpark.new()
		spark._color = _color
		spark._angle = TAU * float(i) / 16.0
		spark._speed = randf_range(100, 200)
		spark._lifetime = 0.8
		get_parent().add_child(spark)
		spark.global_position = global_position

	# Spawn expand rings at peg position
	for i in range(randi_range(2, 3)):
		var ring := _ExpandRing.new()
		ring._color = _color
		ring._max_radius = randf_range(30.0, 50.0)
		ring._duration = 0.3
		ring.global_position = global_position
		get_parent().add_child(ring)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "rotation", TAU * 2.0, 0.3).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


class _NeonSpark extends Node2D:
	var _color := Color.CYAN
	var _angle := 0.0
	var _speed := 100.0
	var _lifetime := 0.5
	var _age := 0.0
	var _vel := Vector2.ZERO

	func _ready() -> void:
		_vel = Vector2.from_angle(_angle) * _speed

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _lifetime:
			queue_free()
			return
		position += _vel * delta
		_vel *= 0.96
		queue_redraw()

	func _draw() -> void:
		var t := 1.0 - _age / _lifetime
		var len := _vel.length() * 0.04 * t
		var dir := _vel.normalized()
		draw_circle(Vector2.ZERO, 3.0 * t, Color(_color.r, _color.g, _color.b, t * 0.3))
		draw_line(-dir * len, dir * len, Color(_color.r, _color.g, _color.b, t), 1.5)
		draw_circle(Vector2.ZERO, 1.0 * t, Color(1, 1, 1, t * 0.8))


class _ExpandRing extends Node2D:
	var _color := Color.RED
	var _max_radius := 120.0
	var _duration := 0.4
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := _age / _duration
		var radius := _max_radius * t
		var alpha := (1.0 - t) * 0.6
		var width := lerpf(3.0, 1.0, t)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(_color.r, _color.g, _color.b, alpha), width, true)
		# Inner bright flash
		if t < 0.3:
			var flash_alpha := (0.3 - t) / 0.3 * 0.5
			draw_circle(Vector2.ZERO, 20.0 * (1.0 - t), Color(1, 1, 1, flash_alpha))


class _ArmorShard extends Node2D:
	var _color := Color.GRAY
	var _angle := 0.0
	var _speed := 100.0
	var _lifetime := 0.4
	var _age := 0.0
	var _vel := Vector2.ZERO
	var _rotation_speed := 0.0

	func _ready() -> void:
		_vel = Vector2.from_angle(_angle) * _speed
		_rotation_speed = randf_range(5, 10) * (1.0 if randf() > 0.5 else -1.0)

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _lifetime:
			queue_free()
			return
		position += _vel * delta
		_vel *= 0.92
		rotation += _rotation_speed * delta
		queue_redraw()

	func _draw() -> void:
		var t := 1.0 - _age / _lifetime
		var s := 3.0 * t
		var pts := PackedVector2Array([
			Vector2(0, -s), Vector2(s * 0.7, s * 0.5), Vector2(-s * 0.7, s * 0.5)
		])
		draw_colored_polygon(pts, Color(_color.r, _color.g, _color.b, t * 0.7))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(_color.r, _color.g, _color.b, t), 1.0)


class _ChainBolt extends Node2D:
	var _start := Vector2.ZERO
	var _end := Vector2.ZERO
	var _color := Color(0.0, 1.0, 1.0)
	var _lifetime := 0.3
	var _age := 0.0
	var _path: PackedVector2Array = PackedVector2Array()

	func _ready() -> void:
		_generate_path()

	func _generate_path() -> void:
		_path.clear()
		_path.append(_start)
		var segments := 5
		var dir := (_end - _start)
		for i in range(1, segments):
			var t := float(i) / float(segments)
			var point := _start + dir * t
			var perp := Vector2(-dir.y, dir.x).normalized()
			point += perp * randf_range(-6, 6)
			_path.append(point)
		_path.append(_end)

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _lifetime:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := 1.0 - _age / _lifetime
		if _path.size() < 2:
			return
		draw_polyline(_path, Color(_color.r, _color.g, _color.b, t * 0.9), 2.0)
		# Glow
		draw_polyline(_path, Color(_color.r, _color.g, _color.b, t * 0.2), 5.0)
