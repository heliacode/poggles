class_name LevelData
extends Resource

@export var level_name: String = "Level"
@export var level_number: int = 1
@export var peg_positions: Array[Vector2] = []
@export var peg_types: Array[String] = []
@export var peg_specials: Array[String] = []
@export var peg_power_ups: Array[String] = []
@export var starting_balls: int = 10

func get_peg_count() -> int:
	return peg_positions.size()

func get_orange_count() -> int:
	var count := 0
	for t in peg_types:
		if t == "orange":
			count += 1
	return count

func get_max_possible_score() -> int:
	var total := 0
	for t in peg_types:
		total += GameConfig.PEG_SCORES.get(t, 0)
	return total
