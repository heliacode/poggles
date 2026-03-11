extends Node2D

signal ball_fired(pos: Vector2, direction: Vector2, power: float)

@onready var barrel := $Barrel
@onready var spawn_point := $Barrel/SpawnPoint
@onready var aim_line := $AimLine

var can_shoot := true
var _recoil := 0.0
var _pulse := 0.0
var _aim_particles: Array[Dictionary] = []  # {t: float, speed: float}
var _aim_spawn_timer := 0.0

func _ready() -> void:
	aim_line.visible = false
	if barrel.has_node("BarrelSprite"):
		barrel.get_node("BarrelSprite").visible = false

func _process(delta: float) -> void:
	_aim_at_mouse()
	# Controller aim
	var aim_x := Input.get_axis("aim_left", "aim_right")
	if absf(aim_x) > 0.1:
		var current_angle := barrel.rotation
		current_angle += aim_x * delta * 2.0
		current_angle = clampf(current_angle, PI - deg_to_rad(80.0), PI + deg_to_rad(80.0))
		barrel.rotation = current_angle
	# Controller fire
	if can_shoot and Input.is_action_just_pressed("fire"):
		_shoot()
	_pulse += delta * 3.0
	if _recoil > 0:
		_recoil = maxf(0, _recoil - delta * 8.0)

	# Update aim particles (energy dots flowing along aim line)
	if can_shoot:
		_aim_spawn_timer += delta
		if _aim_spawn_timer >= 0.12 and _aim_particles.size() < 8:
			_aim_spawn_timer = 0.0
			_aim_particles.append({"t": 1.0, "speed": randf_range(0.5, 1.5)})
		var i := _aim_particles.size() - 1
		while i >= 0:
			_aim_particles[i]["t"] -= delta * _aim_particles[i]["speed"]
			if _aim_particles[i]["t"] <= 0:
				_aim_particles.remove_at(i)
			i -= 1
	else:
		_aim_particles.clear()

	queue_redraw()

func _draw() -> void:
	var dir := _get_launch_direction()
	var perp := Vector2(-dir.y, dir.x)
	var pulse := sin(_pulse) * 0.15 + 0.85
	var c := GameConfig.CANNON_COLOR

	for i in range(3):
		var r := GameConfig.CANNON_BASE_RADIUS + 6.0 - float(i) * 2.0
		draw_circle(Vector2.ZERO, r, Color(c.r, c.g, c.b, 0.06 * pulse))

	draw_arc(Vector2.ZERO, GameConfig.CANNON_BASE_RADIUS, 0, TAU, 48, Color(c.r, c.g, c.b, 0.7 * pulse), 1.5, true)
	draw_arc(Vector2.ZERO, GameConfig.CANNON_BASE_RADIUS - 4, 0, TAU, 32, Color(c.r, c.g, c.b, 0.3 * pulse), 1.0, true)

	var recoil_offset := dir * _recoil * -8.0
	var tip := dir * GameConfig.CANNON_BARREL_LENGTH + recoil_offset
	var half_w := GameConfig.CANNON_BARREL_WIDTH / 2.0

	var p1 := recoil_offset + perp * (half_w + 3)
	var p2 := tip + perp * (half_w + 2)
	var p3 := tip - perp * (half_w + 2)
	var p4 := recoil_offset - perp * (half_w + 3)
	draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), Color(c.r, c.g, c.b, 0.05))

	var b1 := recoil_offset + perp * half_w
	var b2 := tip + perp * half_w
	var b3 := tip - perp * half_w
	var b4 := recoil_offset - perp * half_w
	draw_line(b1, b2, Color(c.r, c.g, c.b, 0.8), 1.5)
	draw_line(b3, b4, Color(c.r, c.g, c.b, 0.8), 1.5)
	draw_line(b2, b3, Color(c.r, c.g, c.b, 0.9), 1.5)
	draw_line(b4, b1, Color(c.r, c.g, c.b, 0.5), 1.0)

	var start: Vector2 = spawn_point.global_position - global_position + recoil_offset
	var spacing := 14.0
	var dot_len := 4.0
	var aim_length := 18.0 * spacing
	for i in range(18):
		var t := float(i) / 18.0
		var alpha := (1.0 - t) * 0.4
		var offset := float(i) * spacing
		var a := start + dir * offset
		var b := start + dir * (offset + dot_len)
		draw_line(a, b, Color(c.r, c.g, c.b, alpha), 1.0)

	# Aim charge particles flowing toward barrel
	for particle in _aim_particles:
		var pt: float = particle["t"]
		var pos := start + dir * (pt * aim_length)
		var pa := (1.0 - pt) * 0.6  # Brighter near barrel
		draw_circle(pos, 2.0, Color(c.r, c.g, c.b, pa * 0.4))
		draw_circle(pos, 1.0, Color(1, 1, 1, pa * 0.8))

func _aim_at_mouse() -> void:
	var mouse_pos := get_global_mouse_position()
	var direction := (mouse_pos - global_position)
	if direction.y < 10:
		direction.y = 10
	var angle := direction.angle() + PI / 2.0
	angle = clampf(angle, PI - deg_to_rad(80.0), PI + deg_to_rad(80.0))
	barrel.rotation = angle

func _get_launch_direction() -> Vector2:
	return Vector2.from_angle(barrel.rotation - PI / 2.0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if can_shoot:
			_shoot()

func set_aim_angle(angle_rad: float) -> void:
	barrel.rotation = angle_rad + PI / 2.0

func force_fire() -> void:
	if can_shoot:
		_shoot()

func _shoot() -> void:
	can_shoot = false
	_recoil = 1.0
	var dir := _get_launch_direction()
	ball_fired.emit(spawn_point.global_position, dir, GameConfig.CANNON_LAUNCH_POWER)
