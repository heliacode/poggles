class_name BoardGenerator
extends RefCounted

## Procedurally generates LevelData from difficulty parameters.

const PLAY_AREA := Rect2(100, 140, 1080, 480)  # x, y, width, height
const TEMPLATES := ["grid", "scatter", "clusters"]

static func generate(params: Dictionary) -> LevelData:
	var rng := RandomNumberGenerator.new()
	rng.seed = params.get("seed", randi())

	var total: int = params.get("total_pegs", 24)
	var orange_count: int = params.get("orange_count", 8)
	var green_count: int = params.get("green_count", 2)
	var purple_count: int = params.get("purple_count", 1)
	var min_spacing: float = params.get("min_spacing", GameConfig.PEG_RADIUS * 3.0)

	# Clamp orange so it doesn't exceed total - green - purple
	var special_count := green_count + purple_count
	orange_count = mini(orange_count, total - special_count)
	var blue_count := total - orange_count - special_count

	# Pick template
	var template: String = TEMPLATES[rng.randi() % TEMPLATES.size()]

	# Generate positions
	var positions := _generate_positions(template, total, min_spacing, rng)

	# Assign types with spread
	var types := _assign_types(positions, orange_count, blue_count, green_count, purple_count, rng)

	# Assign special types based on act progression
	var act: int = params.get("act", 1)
	var is_boss: bool = params.get("is_boss", false)
	var specials := _assign_specials(types, act, is_boss, rng)

	# Assign power-ups to green pegs
	var power_ups := _assign_power_ups(types, act, rng)

	# Build LevelData
	var data := LevelData.new()
	data.level_name = _board_name(rng)
	data.level_number = params.get("seed", 0)
	data.peg_positions = positions
	data.peg_types = types
	data.peg_specials = specials
	data.peg_power_ups = power_ups
	data.starting_balls = 0  # Not used in roguelite mode
	return data

# --- Position Generation ---

static func _generate_positions(template: String, count: int, min_spacing: float, rng: RandomNumberGenerator) -> Array[Vector2]:
	match template:
		"grid": return _template_grid(count, min_spacing, rng)
		"scatter": return _template_scatter(count, min_spacing, rng)
		"clusters": return _template_clusters(count, min_spacing, rng)
	return _template_scatter(count, min_spacing, rng)

static func _template_grid(count: int, min_spacing: float, rng: RandomNumberGenerator) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var spacing := maxf(min_spacing, 80.0)

	# Calculate grid dimensions
	var cols := floori(PLAY_AREA.size.x / spacing)
	var rows := floori(PLAY_AREA.size.y / spacing)
	var total_cells := cols * rows

	# Pick random cells
	var cells: Array[int] = []
	for i in range(total_cells):
		cells.append(i)

	# Shuffle and pick
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp

	var to_place := mini(count, cells.size())
	for i in range(to_place):
		var cell := cells[i]
		var col := cell % cols
		var row := cell / cols
		var x := PLAY_AREA.position.x + float(col) * spacing + spacing * 0.5
		var y := PLAY_AREA.position.y + float(row) * spacing + spacing * 0.5
		# Add jitter
		x += rng.randf_range(-spacing * 0.2, spacing * 0.2)
		y += rng.randf_range(-spacing * 0.2, spacing * 0.2)
		positions.append(Vector2(x, y))

	return positions

static func _template_scatter(count: int, min_spacing: float, rng: RandomNumberGenerator) -> Array[Vector2]:
	## Poisson-disc-like sampling
	var positions: Array[Vector2] = []
	var max_attempts := 100

	for _i in range(count):
		var placed := false
		for _attempt in range(max_attempts):
			var x := rng.randf_range(PLAY_AREA.position.x, PLAY_AREA.end.x)
			var y := rng.randf_range(PLAY_AREA.position.y, PLAY_AREA.end.y)
			var candidate := Vector2(x, y)

			var too_close := false
			for existing in positions:
				if candidate.distance_to(existing) < min_spacing:
					too_close = true
					break

			if not too_close:
				positions.append(candidate)
				placed = true
				break

		if not placed:
			# Relax spacing and force place
			var x := rng.randf_range(PLAY_AREA.position.x, PLAY_AREA.end.x)
			var y := rng.randf_range(PLAY_AREA.position.y, PLAY_AREA.end.y)
			positions.append(Vector2(x, y))

	return positions

static func _template_clusters(count: int, min_spacing: float, rng: RandomNumberGenerator) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var cluster_count := rng.randi_range(3, 6)
	var pegs_per_cluster := count / cluster_count
	var remainder := count % cluster_count

	# Generate cluster centers
	var centers: Array[Vector2] = []
	var center_min_dist := 150.0
	for _c in range(cluster_count):
		for _attempt in range(50):
			var cx := rng.randf_range(PLAY_AREA.position.x + 80, PLAY_AREA.end.x - 80)
			var cy := rng.randf_range(PLAY_AREA.position.y + 60, PLAY_AREA.end.y - 60)
			var center := Vector2(cx, cy)
			var ok := true
			for existing in centers:
				if center.distance_to(existing) < center_min_dist:
					ok = false
					break
			if ok:
				centers.append(center)
				break

	if centers.is_empty():
		return _template_scatter(count, min_spacing, rng)

	# Scatter pegs around each cluster center
	var cluster_radius := 80.0
	for ci in range(centers.size()):
		var n := pegs_per_cluster + (1 if ci < remainder else 0)
		var center := centers[ci]
		for _p in range(n):
			for _attempt in range(50):
				var angle := rng.randf() * TAU
				var dist := rng.randf_range(min_spacing * 0.5, cluster_radius)
				var pos := center + Vector2.from_angle(angle) * dist
				# Clamp to play area
				pos.x = clampf(pos.x, PLAY_AREA.position.x, PLAY_AREA.end.x)
				pos.y = clampf(pos.y, PLAY_AREA.position.y, PLAY_AREA.end.y)

				var too_close := false
				for existing in positions:
					if pos.distance_to(existing) < min_spacing:
						too_close = true
						break
				if not too_close:
					positions.append(pos)
					break

	# If we didn't place enough, fill with scatter
	while positions.size() < count:
		var x := rng.randf_range(PLAY_AREA.position.x, PLAY_AREA.end.x)
		var y := rng.randf_range(PLAY_AREA.position.y, PLAY_AREA.end.y)
		positions.append(Vector2(x, y))

	return positions

# --- Type Assignment ---

static func _assign_types(positions: Array[Vector2], orange: int, blue: int, green: int, purple: int, rng: RandomNumberGenerator) -> Array[String]:
	var count := positions.size()
	var types: Array[String] = []
	types.resize(count)
	for i in range(count):
		types[i] = "blue"

	# Spread orange pegs across the board using spatial grid
	var indices: Array[int] = []
	for i in range(count):
		indices.append(i)

	# Sort by position hash for spatial distribution
	indices.sort_custom(func(a, b): return positions[a].y * 2000 + positions[a].x < positions[b].y * 2000 + positions[b].x)

	# Distribute orange evenly across sorted indices
	var orange_placed := 0
	if orange > 0 and count > 0:
		var step := float(count) / float(orange)
		for i in range(orange):
			var idx := clampi(roundi(float(i) * step + rng.randf_range(-step * 0.3, step * 0.3)), 0, count - 1)
			# Find nearest unassigned-as-orange
			var best := -1
			var best_dist := INF
			for j in range(count):
				if types[indices[j]] == "blue":
					var d := absf(float(j) - float(idx))
					if d < best_dist:
						best_dist = d
						best = j
			if best >= 0:
				types[indices[best]] = "orange"
				orange_placed += 1

	# Place green pegs (spread apart)
	var available: Array[int] = []
	for i in range(count):
		if types[i] == "blue":
			available.append(i)

	for _g in range(green):
		if available.is_empty():
			break
		# Pick from middle-ish of available
		var pick := available[rng.randi_range(available.size() / 4, available.size() * 3 / 4) if available.size() > 4 else rng.randi_range(0, available.size() - 1)]
		types[pick] = "green"
		available.erase(pick)

	# Place purple (1, random from remaining blue)
	for _p in range(purple):
		if available.is_empty():
			break
		var pick := available[rng.randi_range(0, available.size() - 1)]
		types[pick] = "purple"
		available.erase(pick)

	return types

# --- Board Naming ---

static func _assign_specials(types: Array[String], act: int, is_boss: bool, rng: RandomNumberGenerator) -> Array[String]:
	var count := types.size()
	var specials: Array[String] = []
	specials.resize(count)
	for i in range(count):
		specials[i] = ""

	# Determine how many of each special to place based on act
	var bomb_count := 0
	var armored_count := 0
	var multiplier_count := 0
	var chain_count := 0
	var gravity_count := 0

	match act:
		1:
			bomb_count = 1
			multiplier_count = 1
		2:
			bomb_count = 2
			armored_count = 2
			multiplier_count = 1
			chain_count = 1
		3:
			bomb_count = 2
			armored_count = 3
			multiplier_count = 1
			chain_count = 2
			gravity_count = 1

	if is_boss:
		bomb_count += 1
		armored_count += 2
		gravity_count += 1

	# Collect indices of blue pegs (specials go on blue pegs only, not orange/green/purple)
	var blue_indices: Array[int] = []
	for i in range(count):
		if types[i] == "blue":
			blue_indices.append(i)

	# Shuffle blue indices
	for i in range(blue_indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := blue_indices[i]
		blue_indices[i] = blue_indices[j]
		blue_indices[j] = tmp

	# Assign specials from the shuffled pool
	var pool_idx := 0
	var assignments: Array[Dictionary] = []
	assignments.append({"type": "bomb", "count": bomb_count})
	assignments.append({"type": "armored", "count": armored_count})
	assignments.append({"type": "multiplier", "count": multiplier_count})
	assignments.append({"type": "chain", "count": chain_count})
	assignments.append({"type": "gravity", "count": gravity_count})

	for assignment in assignments:
		var stype: String = assignment["type"]
		var scount: int = assignment["count"]
		for _s in range(scount):
			if pool_idx >= blue_indices.size():
				break
			specials[blue_indices[pool_idx]] = stype
			pool_idx += 1

	return specials

static func _assign_power_ups(types: Array[String], act: int, rng: RandomNumberGenerator) -> Array[String]:
	var count := types.size()
	var power_ups: Array[String] = []
	power_ups.resize(count)
	for i in range(count):
		power_ups[i] = ""

	var available: Array[String] = []
	match act:
		1: available = ["prism_split", "phantom_pass", "overdrive"]
		2: available = ["prism_split", "overload", "overdrive", "phantom_pass"]
		3: available = ["overload", "overdrive", "phantom_pass", "prism_split"]

	for i in range(count):
		if types[i] == "green" and not available.is_empty():
			power_ups[i] = available[rng.randi() % available.size()]

	return power_ups

static func _board_name(rng: RandomNumberGenerator) -> String:
	var adjectives := ["Neon", "Dark", "Glowing", "Twisted", "Deep", "Shifting", "Silent", "Bright", "Hollow", "Fractured"]
	var nouns := ["Grid", "Void", "Cluster", "Lattice", "Maze", "Field", "Chamber", "Nexus", "Ring", "Rift"]
	return "%s %s" % [adjectives[rng.randi() % adjectives.size()], nouns[rng.randi() % nouns.size()]]
