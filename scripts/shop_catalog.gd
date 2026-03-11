class_name ShopCatalog
extends RefCounted

static func generate_shop_items(rng: RandomNumberGenerator, exclude_relic_ids: Array = []) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var pool: Array[Dictionary] = _get_item_pool()

	# Add 1-2 relics to shop
	var relics := RelicCatalog.get_random_relics(2, exclude_relic_ids, rng)
	for relic in relics:
		var cost := _relic_cost(relic.rarity)
		pool.append({"type": "relic", "relic": relic, "name": relic.relic_name, "description": relic.description, "cost": cost, "rarity_color": relic.get_rarity_color()})

	# Shuffle pool
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

	# Pick 4 items
	for i in range(mini(4, pool.size())):
		items.append(pool[i])

	return items

static func _relic_cost(rarity: String) -> int:
	match rarity:
		"common": return 25
		"uncommon": return 45
		"rare": return 65
		"legendary": return 85
	return 30

static func _get_item_pool() -> Array[Dictionary]:
	var cyan := Color(0.3, 0.85, 1.0)
	var green := Color(0.3, 1.0, 0.5)
	var gold := Color(1.0, 0.85, 0.3)
	return [
		{"type": "balls", "amount": 1, "name": "+1 Ball", "description": "Gain 1 extra ball", "cost": 15, "rarity_color": cyan},
		{"type": "balls", "amount": 3, "name": "+3 Balls", "description": "Gain 3 extra balls", "cost": 40, "rarity_color": cyan},
		{"type": "balls", "amount": 5, "name": "+5 Balls", "description": "Gain 5 extra balls", "cost": 60, "rarity_color": green},
		{"type": "heal", "amount": 2, "name": "Quick Rest", "description": "Gain 2 balls", "cost": 20, "rarity_color": green},
		{"type": "score_bonus", "amount": 500, "name": "Score Infusion", "description": "+500 score", "cost": 30, "rarity_color": gold},
		{"type": "permanent_coin", "amount": 1, "name": "Coin Enhancer", "description": "+1 coin per peg (permanent)", "cost": 50, "rarity_color": gold},
		{"type": "permanent_orange", "amount": 10, "name": "Orange Amplifier", "description": "+10 score per orange (permanent)", "cost": 45, "rarity_color": gold},
	]
