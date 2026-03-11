extends Control

signal level_selected(level_number: int)

var level_number := 1
var level_name := "Level"
var stars := 0
var is_locked := false
var _hover := false
var _pulse := 0.0

func setup(num: int, lname: String, star_count: int, locked: bool) -> void:
	level_number = num
	level_name = lname
	stars = star_count
	is_locked = locked
	custom_minimum_size = Vector2(200, 140)

func _ready() -> void:
	mouse_entered.connect(func(): _hover = true)
	mouse_exited.connect(func(): _hover = false)

func _process(delta: float) -> void:
	_pulse += delta * 2.5
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_locked:
			level_selected.emit(level_number)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var c := Color(0.3, 0.85, 1.0) if not is_locked else Color(0.3, 0.3, 0.4)
	var pulse := sin(_pulse) * 0.15 + 0.85
	var alpha := (0.8 if _hover else 0.5) * pulse

	# Background glow
	draw_rect(rect, Color(c.r, c.g, c.b, 0.03 * pulse), true)

	# Border
	var points := PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y), rect.position,
	])
	draw_polyline(points, Color(c.r, c.g, c.b, alpha), 1.5)

	var font := ThemeDB.fallback_font
	var center_x := size.x / 2.0

	# Level number
	var num_text := "%d" % level_number
	var num_size := font.get_string_size(num_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
	draw_string(font, Vector2(center_x - num_size.x / 2.0, 40), num_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(c.r, c.g, c.b, alpha))

	# Level name
	var name_size := font.get_string_size(level_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(font, Vector2(center_x - name_size.x / 2.0, 65), level_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(c.r, c.g, c.b, alpha * 0.7))

	# Stars
	if not is_locked:
		var star_text := ""
		for i in range(3):
			star_text += "*" if i < stars else "-"
		var star_size := font.get_string_size(star_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
		var star_color := Color(1.0, 0.85, 0.3, alpha) if stars > 0 else Color(0.4, 0.4, 0.5, alpha * 0.5)
		draw_string(font, Vector2(center_x - star_size.x / 2.0, 95), star_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, star_color)

	# Lock icon
	if is_locked:
		var lock_size := font.get_string_size("LOCKED", HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		draw_string(font, Vector2(center_x - lock_size.x / 2.0, 95), "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.3, 0.3, 0.6))
