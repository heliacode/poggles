class_name RelicData
extends Resource

@export var id: String = ""
@export var relic_name: String = ""
@export var description: String = ""
@export var rarity: String = "common"  # common, uncommon, rare, legendary
@export var hooks: Array[String] = []  # Which game events this relic responds to

func get_rarity_color() -> Color:
	match rarity:
		"common": return Color(0.5, 0.7, 1.0)
		"uncommon": return Color(0.3, 1.0, 0.5)
		"rare": return Color(0.8, 0.3, 1.0)
		"legendary": return Color(1.0, 0.85, 0.0)
	return Color.WHITE
