extends Button

@export var neon_color := Color(0.3, 0.85, 1.0)
@export var glow_width := 3.0

var _hover := false
var _pulse := 0.0

func _ready() -> void:
	flat = true
	mouse_entered.connect(func(): _hover = true)
	mouse_exited.connect(func(): _hover = false)
	# Make text transparent so we draw our own
	add_theme_color_override("font_color", neon_color)
	add_theme_color_override("font_hover_color", Color(1, 1, 1))
	add_theme_color_override("font_pressed_color", neon_color.lightened(0.3))
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _process(delta: float) -> void:
	_pulse += delta * 3.0
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var c := neon_color
	var pulse := sin(_pulse) * 0.15 + 0.85
	var alpha := 0.7 * pulse if not _hover else 1.0

	# Glow
	var glow_rect := rect.grow(glow_width)
	draw_rect(glow_rect, Color(c.r, c.g, c.b, 0.05 * pulse), true)

	# Wireframe border
	var points := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
		rect.position,
	])
	draw_polyline(points, Color(c.r, c.g, c.b, alpha), 1.5)

	# Corner dots
	for p in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		draw_circle(p, 2.0, Color(c.r, c.g, c.b, alpha))
