extends CanvasLayer

@onready var panel := $Panel
@onready var abandon_btn := $Panel/VBox/AbandonBtn

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Only show "Abandon Run" during roguelite runs
	if abandon_btn:
		abandon_btn.visible = RunState.is_run_active

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

func _on_settings_pressed() -> void:
	get_tree().paused = false
	visible = false
	SceneManager.go_to_settings()

func _on_abandon_pressed() -> void:
	get_tree().paused = false
	visible = false
	if RunState.is_run_active:
		RunState.end_run(false)
	SceneManager.go_to_run_results()

func _on_level_select_pressed() -> void:
	get_tree().paused = false
	visible = false
	SceneManager.go_to_level_select()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	visible = false
	SceneManager.go_to_main_menu()
