extends Node2D

var _pulse := 0.0

@onready var background := $Background
@onready var grid := $UI/GridContainer

func _ready() -> void:
	_build_level_cards()

func _process(delta: float) -> void:
	_pulse += delta * 2.0
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := GameConfig.VIEWPORT_SIZE
	var center_x := vp.x / 2.0
	var pulse := sin(_pulse) * 0.15 + 0.85

	var title := "SELECT LEVEL"
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 36)
	draw_string(font, Vector2(center_x - title_size.x / 2.0, 60), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0.3, 0.85, 1.0, pulse))

func _build_level_cards() -> void:
	var highest_unlocked := SaveData.get_highest_unlocked_level()
	var card_script := load("res://scripts/level_card.gd")

	for i in range(1, GameConfig.TOTAL_LEVELS + 1):
		var level_data := LevelLoader.load_level(i)
		var card := Control.new()
		card.set_script(card_script)
		var lname := level_data.level_name if level_data else "Level %d" % i
		var stars := SaveData.get_level_stars(i)
		var locked := i > highest_unlocked
		card.setup(i, lname, stars, locked)
		card.level_selected.connect(_on_level_selected)
		grid.add_child(card)

func _on_level_selected(level_number: int) -> void:
	SceneManager.go_to_gameplay(level_number)

func _on_back_pressed() -> void:
	SceneManager.go_to_main_menu()
