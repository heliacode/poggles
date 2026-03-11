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
	queue_redraw()

func _draw() -> void:
	var pulse := sin(_pulse) * 0.3 + 0.7
	var base := _color

	# Outer glow layers
	for i in range(5):
		var r := GameConfig.PEG_RADIUS + 12.0 - float(i) * 2.0
		var a := (0.06 + pulse * 0.03) * (1.0 - float(i) * 0.15)
		if _hit:
			a *= 1.8
		draw_circle(Vector2.ZERO, r, Color(base.r, base.g, base.b, a))

	# Anticipation glow (ball approaching)
	if _anticipation > 0:
		draw_circle(Vector2.ZERO, GameConfig.PEG_RADIUS + 16.0, Color(base.r, base.g, base.b, 0.15 * _anticipation))

	# Hit flash
	if _hit_flash > 0:
		draw_circle(Vector2.ZERO, GameConfig.PEG_RADIUS + 8.0 * _hit_flash, Color(1, 1, 1, _hit_flash * 0.4))

	# Main wireframe ring
	var ring_alpha := 0.8 + pulse * 0.2
	if _hit:
		ring_alpha = 1.0
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

func _draw_special(ring_alpha: float, pulse: float) -> void:
	match special_type:
		"bomb": _draw_bomb(ring_alpha, pulse)
		"armored": _draw_armored(ring_alpha)
		"multiplier": _draw_multiplier(ring_alpha, pulse)
		"chain": _draw_chain(ring_alpha)
		"gravity": _draw_gravity(ring_alpha)

func _draw_bomb(ring_alpha: float, pulse: float) -> void:
	var bc := GameConfig.SPECIAL_PEG_COLORS["bomb"]
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
	var ac := GameConfig.SPECIAL_PEG_COLORS["armored"]
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
	var gc := GameConfig.SPECIAL_PEG_COLORS["multiplier"]
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
	var cc := GameConfig.SPECIAL_PEG_COLORS["chain"]
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
	var vc := GameConfig.SPECIAL_PEG_COLORS["gravity"]
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
		return

	_hit = true
	_hit_flash = 1.0
	_color = GameConfig.PEG_HIT_COLORS.get(peg_type, Color.WHITE)

	match special_type:
		"bomb": _spawn_bomb_particles()
		"chain": _spawn_chain_particles()
		"gravity": _spawn_gravity_particles()
		"multiplier": _spawn_multiplier_particles()
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
	var bc := GameConfig.SPECIAL_PEG_COLORS["bomb"]
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
	var cc := GameConfig.SPECIAL_PEG_COLORS["chain"]
	for i in range(8):
		var spark := _NeonSpark.new()
		spark._color = cc
		spark._angle = TAU * float(i) / 8.0 + randf() * 0.3
		spark._speed = randf_range(60, 120)
		spark._lifetime = 0.3
		add_child(spark)

func _spawn_gravity_particles() -> void:
	var vc := GameConfig.SPECIAL_PEG_COLORS["gravity"]
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
	var gc := GameConfig.SPECIAL_PEG_COLORS["multiplier"]
	for i in range(8):
		var spark := _NeonSpark.new()
		spark._color = gc
		spark._angle = TAU * float(i) / 8.0 + 0.5  # Spiral offset
		spark._speed = randf_range(80, 140)
		spark._lifetime = 0.4
		add_child(spark)
	_spawn_hit_particles()

func _spawn_armor_shards() -> void:
	var ac := GameConfig.SPECIAL_PEG_COLORS["armored"]
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
