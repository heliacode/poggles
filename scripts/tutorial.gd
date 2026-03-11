extends Node

## Manages first-run tutorial prompts overlaid on the gameplay scene.

signal tutorial_step_completed(step: int)

var _current_step := 0
var _active := false
var _prompts := [
	"Click to aim and fire the ball!",
	"Hit the ORANGE pegs to clear them!",
	"Catch the ball in the BUCKET for a free ball!",
	"Clear ALL orange pegs to win the board!",
	"Good luck, VERTEX. Rebuild the Lattice.",
]
var _prompt_conditions := [
	"fire",    # Shown at start, completed on first fire
	"hit",     # Shown after first fire, completed on first orange hit
	"catch",   # Shown after first hit, completed on catch or next fire
	"clear",   # Shown after catch, completed on board clear
	"done",    # Shown briefly, auto-completes
]
var _label: Label
var _bg: ColorRect
var _fade_tween: Tween

func start_tutorial(parent: Node) -> void:
	if SaveData.has_completed_tutorial():
		return
	_active = true
	_current_step = 0

	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.4)
	_bg.custom_minimum_size = Vector2(600, 60)
	_bg.size = Vector2(600, 60)
	_bg.position = Vector2(340, 620)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = Vector2(600, 60)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bg.add_child(_label)

	# Add to a CanvasLayer so it's on top
	var canvas := CanvasLayer.new()
	canvas.layer = 50
	canvas.name = "TutorialLayer"
	parent.add_child(canvas)
	canvas.add_child(_bg)

	_show_step()

func is_active() -> bool:
	return _active

func on_event(event_type: String) -> void:
	if not _active:
		return
	if _current_step >= _prompt_conditions.size():
		return
	var condition: String = _prompt_conditions[_current_step]
	if condition == event_type or condition == "done":
		advance()

func advance() -> void:
	_current_step += 1
	tutorial_step_completed.emit(_current_step)
	if _current_step >= _prompts.size():
		_complete()
	else:
		_show_step()
		if _prompt_conditions[_current_step] == "done":
			# Auto-advance after delay
			var parent := _bg.get_parent()
			if parent:
				var timer := parent.get_tree().create_timer(2.0)
				timer.timeout.connect(advance)

func _show_step() -> void:
	if _label and _current_step < _prompts.size():
		_label.text = _prompts[_current_step]
		_bg.modulate.a = 0.0
		if _fade_tween:
			_fade_tween.kill()
		_fade_tween = _bg.create_tween()
		_fade_tween.tween_property(_bg, "modulate:a", 1.0, 0.3)

func _complete() -> void:
	_active = false
	SaveData.set_tutorial_completed()
	if _bg:
		var tween := _bg.create_tween()
		tween.tween_property(_bg, "modulate:a", 0.0, 0.5)
		tween.tween_callback(_bg.queue_free)
