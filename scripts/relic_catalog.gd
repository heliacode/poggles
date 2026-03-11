class_name RelicCatalog
extends RefCounted

static func get_all_relics() -> Array[RelicData]:
	return [
		# Common (10)
		_relic("lucky_penny", "Lucky Penny", "+1 coin per blue peg hit", "common", ["on_peg_hit"]),
		_relic("iron_ball", "Iron Ball", "+15% score from blue pegs", "common", ["on_peg_hit"]),
		_relic("sharp_aim", "Sharp Aim", "Aim line extended by 50%", "common", ["on_ball_fired"]),
		_relic("thick_skin", "Thick Skin", "+1 starting ball per board", "common", ["on_board_start"]),
		_relic("fever_frenzy", "Fever Frenzy", "Fever meter fills 30% faster", "common", ["on_peg_hit"]),
		_relic("coin_magnet", "Coin Magnet", "+2 coins per board clear", "common", ["on_board_clear"]),
		_relic("steady_hand", "Steady Hand", "First shot each board scores 2x", "common", ["on_ball_fired"]),
		_relic("bounce_pad", "Bounce Pad", "Bucket is 30% wider", "common", ["on_board_start"]),
		_relic("pocket_change", "Pocket Change", "+5 coins at start of each board", "common", ["on_board_start"]),
		_relic("second_wind", "Second Wind", "25% chance to not lose a ball on miss", "common", ["on_ball_lost"]),

		# Uncommon (10)
		_relic("magnet_core", "Magnet Core", "Ball curves slightly toward nearest orange peg", "uncommon", ["on_ball_fired"]),
		_relic("echo_peg", "Echo Peg", "10% chance hit peg respawns as blue", "uncommon", ["on_peg_hit"]),
		_relic("bouncy_walls", "Bouncy Walls", "Wall bounces give ball speed boost", "uncommon", ["on_ball_fired"]),
		_relic("chain_reaction", "Chain Reaction", "Chain effects hit +1 additional target", "uncommon", ["on_peg_hit"]),
		_relic("golden_bucket", "Golden Bucket", "Bucket catch gives +50 score", "uncommon", ["on_ball_caught"]),
		_relic("bomb_squad", "Bomb Squad", "Bomb peg radius +50%", "uncommon", ["on_peg_hit"]),
		_relic("fever_echo", "Fever Echo", "Fever mode lasts 1 extra ball", "uncommon", ["on_fever"]),
		_relic("orange_hunter", "Orange Hunter", "+25 score per orange peg cleared", "uncommon", ["on_peg_hit"]),
		_relic("combo_king", "Combo King", "Combos of 5+ give +1 coin per hit", "uncommon", ["on_peg_hit"]),
		_relic("peg_sight", "Peg Sight", "Orange pegs glow brighter", "uncommon", ["on_board_start"]),

		# Rare (7)
		_relic("glass_cannon", "Glass Cannon", "+50% all scores, -2 starting balls", "rare", ["on_board_start", "on_peg_hit"]),
		_relic("phantom_drift", "Phantom Drift", "Phantom pass lasts 1s longer", "rare", ["on_peg_hit"]),
		_relic("gravity_lens", "Gravity Lens", "Gravity wells pull 50% stronger", "rare", ["on_peg_hit"]),
		_relic("prism_master", "Prism Master", "Prism split creates 3 balls instead of 2", "rare", ["on_peg_hit"]),
		_relic("stardust_magnet", "Stardust Magnet", "+25% stardust earned this run", "rare", ["on_run_end"]),
		_relic("combo_breaker", "Combo Breaker", "Every 10th hit triggers a mini-bomb", "rare", ["on_peg_hit"]),
		_relic("neon_shield", "Neon Shield", "First ball lost each board is refunded", "rare", ["on_ball_lost"]),

		# Legendary (3)
		_relic("void_heart", "Void Heart", "Fever mode scores 5x instead of 3x", "legendary", ["on_peg_hit"]),
		_relic("infinite_echo", "Infinite Echo", "20% chance to not consume a ball", "legendary", ["on_ball_fired"]),
		_relic("lattice_key", "Lattice Key", "+1 ball refund on board clear, +30% coin gain", "legendary", ["on_board_clear"]),
	]

static func get_relics_by_rarity(rarity: String) -> Array[RelicData]:
	var result: Array[RelicData] = []
	for r in get_all_relics():
		if r.rarity == rarity:
			result.append(r)
	return result

static func get_relic_by_id(id: String) -> RelicData:
	for r in get_all_relics():
		if r.id == id:
			return r
	return null

static func get_random_relics(count: int, exclude_ids: Array = [], rng: RandomNumberGenerator = null) -> Array[RelicData]:
	if not rng:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var pool: Array[RelicData] = []
	for r in get_all_relics():
		if r.id not in exclude_ids:
			pool.append(r)
	# Shuffle
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var result: Array[RelicData] = []
	for i in range(mini(count, pool.size())):
		result.append(pool[i])
	return result

static func get_weighted_random_relics(count: int, exclude_ids: Array = [], guaranteed_rare_plus: bool = false, rng: RandomNumberGenerator = null) -> Array[RelicData]:
	if not rng:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var result: Array[RelicData] = []
	var used_ids: Array = exclude_ids.duplicate()

	for i in range(count):
		var target_rarity: String
		if i == 0 and guaranteed_rare_plus:
			target_rarity = "rare" if rng.randf() < 0.7 else "legendary"
		else:
			var roll := rng.randf()
			if roll < 0.45:
				target_rarity = "common"
			elif roll < 0.80:
				target_rarity = "uncommon"
			elif roll < 0.95:
				target_rarity = "rare"
			else:
				target_rarity = "legendary"

		var pool: Array[RelicData] = []
		for r in get_all_relics():
			if r.rarity == target_rarity and r.id not in used_ids:
				pool.append(r)
		if pool.is_empty():
			# Fallback to any rarity
			for r in get_all_relics():
				if r.id not in used_ids:
					pool.append(r)
		if pool.is_empty():
			break
		var picked := pool[rng.randi_range(0, pool.size() - 1)]
		result.append(picked)
		used_ids.append(picked.id)

	return result

static func _relic(id: String, relic_name: String, desc: String, rarity: String, hooks: Array) -> RelicData:
	var r := RelicData.new()
	r.id = id
	r.relic_name = relic_name
	r.description = desc
	r.rarity = rarity
	var typed_hooks: Array[String] = []
	for h in hooks:
		typed_hooks.append(h)
	r.hooks = typed_hooks
	return r
