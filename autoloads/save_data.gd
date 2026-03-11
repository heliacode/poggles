extends Node

const SAVE_PATH := "user://poggles_save.cfg"

var _config := ConfigFile.new()

func _ready() -> void:
	load_data()

func load_data() -> void:
	var err := _config.load(SAVE_PATH)
	if err != OK:
		_config = ConfigFile.new()

func save() -> void:
	_config.save(SAVE_PATH)

# Level progress
func get_level_score(level: int) -> int:
	return _config.get_value("levels", "level_%d_score" % level, 0)

func set_level_score(level: int, score: int) -> void:
	var current := get_level_score(level)
	if score > current:
		_config.set_value("levels", "level_%d_score" % level, score)
		save()

func get_level_stars(level: int) -> int:
	return _config.get_value("levels", "level_%d_stars" % level, 0)

func set_level_stars(level: int, stars: int) -> void:
	var current := get_level_stars(level)
	if stars > current:
		_config.set_value("levels", "level_%d_stars" % level, stars)
		save()

func is_level_completed(level: int) -> bool:
	return _config.get_value("levels", "level_%d_completed" % level, false)

func set_level_completed(level: int) -> void:
	_config.set_value("levels", "level_%d_completed" % level, true)
	save()

func get_highest_unlocked_level() -> int:
	for i in range(GameConfig.TOTAL_LEVELS, 0, -1):
		if is_level_completed(i):
			return mini(i + 1, GameConfig.TOTAL_LEVELS)
	return 1

# Settings
func get_master_volume() -> float:
	return _config.get_value("settings", "master_volume", 1.0)

func set_master_volume(vol: float) -> void:
	_config.set_value("settings", "master_volume", vol)
	save()

func get_sfx_volume() -> float:
	return _config.get_value("settings", "sfx_volume", 1.0)

func set_sfx_volume(vol: float) -> void:
	_config.set_value("settings", "sfx_volume", vol)
	save()

func get_music_volume() -> float:
	return _config.get_value("settings", "music_volume", 1.0)

func set_music_volume(vol: float) -> void:
	_config.set_value("settings", "music_volume", vol)
	save()

# Stardust (meta-currency)
func get_stardust() -> int:
	return _config.get_value("meta", "stardust", 0)

func add_stardust(amount: int) -> void:
	var current := get_stardust()
	_config.set_value("meta", "stardust", current + amount)
	save()

# Run stats
func get_runs_completed() -> int:
	return _config.get_value("stats", "runs_completed", 0)

func get_best_run_score() -> int:
	return _config.get_value("stats", "best_run_score", 0)

# Unlocks
func is_unlocked(unlock_id: String) -> bool:
	return _config.get_value("unlocks", unlock_id, false)

func unlock(unlock_id: String) -> void:
	_config.set_value("unlocks", unlock_id, true)
	save()

func get_unlocked_list() -> Array:
	var result: Array = []
	if not _config.has_section("unlocks"):
		return result
	for key in _config.get_section_keys("unlocks"):
		if _config.get_value("unlocks", key, false):
			result.append(key)
	return result

# Ascension
func get_ascension_level() -> int:
	return _config.get_value("meta", "ascension", 0)

func set_ascension_level(level: int) -> void:
	_config.set_value("meta", "ascension", level)
	save()

# Tutorial
func has_completed_tutorial() -> bool:
	return _config.get_value("meta", "tutorial_done", false)

func set_tutorial_completed() -> void:
	_config.set_value("meta", "tutorial_done", true)
	save()

# First run flag
func is_first_run() -> bool:
	return get_runs_completed() == 0

# Settings: fullscreen
func get_fullscreen() -> bool:
	return _config.get_value("settings", "fullscreen", false)

func set_fullscreen(val: bool) -> void:
	_config.set_value("settings", "fullscreen", val)
	save()

# Settings: screen shake
func get_screen_shake() -> bool:
	return _config.get_value("settings", "screen_shake", true)

func set_screen_shake(val: bool) -> void:
	_config.set_value("settings", "screen_shake", val)
	save()

# Settings: colorblind mode
func get_colorblind_mode() -> bool:
	return _config.get_value("settings", "colorblind", false)

func set_colorblind_mode(val: bool) -> void:
	_config.set_value("settings", "colorblind", val)
	save()

func add_run_stats(boards_cleared: int, score: int, pegs_hit: int, won: bool) -> void:
	var runs := get_runs_completed()
	_config.set_value("stats", "runs_completed", runs + 1)
	if won:
		var wins: int = _config.get_value("stats", "runs_won", 0)
		_config.set_value("stats", "runs_won", wins + 1)
	var best := get_best_run_score()
	if score > best:
		_config.set_value("stats", "best_run_score", score)
	var total_pegs: int = _config.get_value("stats", "total_pegs_hit", 0)
	_config.set_value("stats", "total_pegs_hit", total_pegs + pegs_hit)
	save()
