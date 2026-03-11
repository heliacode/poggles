extends CanvasLayer

@onready var panel := $Panel

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()

func toggle_pause() -> void:
	visible = !visible
	get_tree().paused = visible

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	visible = false
	SceneManager.go_to_gameplay(SceneManager.current_level)

func _on_level_select_pressed() -> void:
	get_tree().paused = false
	visible = false
	SceneManager.go_to_level_select()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	visible = false
	SceneManager.go_to_main_menu()
