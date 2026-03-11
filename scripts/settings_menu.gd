extends Node2D

var _pulse := 0.0

@onready var background := $Background
@onready var master_slider := $UI/VBoxContainer/MasterSlider
@onready var sfx_slider := $UI/VBoxContainer/SFXSlider
@onready var music_slider := $UI/VBoxContainer/MusicSlider

func _ready() -> void:
	master_slider.value = SaveData.get_master_volume() * 100.0
	sfx_slider.value = SaveData.get_sfx_volume() * 100.0
	music_slider.value = SaveData.get_music_volume() * 100.0

func _process(delta: float) -> void:
	_pulse += delta * 2.0
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := GameConfig.VIEWPORT_SIZE
	var center_x := vp.x / 2.0
	var pulse := sin(_pulse) * 0.15 + 0.85

	var title := "SETTINGS"
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 36)
	draw_string(font, Vector2(center_x - title_size.x / 2.0, 60), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0.3, 0.85, 1.0, pulse))

func _on_master_changed(value: float) -> void:
	var vol := value / 100.0
	SaveData.set_master_volume(vol)
	AudioManager.set_master_volume(vol)

func _on_sfx_changed(value: float) -> void:
	var vol := value / 100.0
	SaveData.set_sfx_volume(vol)
	AudioManager.set_sfx_volume(vol)

func _on_music_changed(value: float) -> void:
	var vol := value / 100.0
	SaveData.set_music_volume(vol)
	AudioManager.set_music_volume(vol)

func _on_back_pressed() -> void:
	SceneManager.go_to_main_menu()
