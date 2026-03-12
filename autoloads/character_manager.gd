extends Node

## Manages playable characters ("Vertices") — catalog, selection, passives, and power execution.

signal power_activated(character_id: String, power_name: String)
signal character_selected(character_id: String)

const CHARACTERS := {
	"orbie": {
		"name": "Orbie",
		"shape": "circle",
		"color": Color(0.3, 0.9, 1.0),
		"power_name": "Multiball",
		"power_desc": "2 extra balls spawn",
		"passive_name": "Wide Catch",
		"passive_desc": "Bucket 15% wider",
		"unlock_cost": 0,
	},
	"trixx": {
		"name": "Trixx",
		"shape": "triangle",
		"color": Color(1.0, 0.3, 0.2),
		"power_name": "Piercing Shot",
		"power_desc": "Ball passes through 3 pegs",
		"passive_name": "Combo Striker",
		"passive_desc": "+25% score on combo 3+",
		"unlock_cost": 500,
	},
	"kubos": {
		"name": "Kubos",
		"shape": "square",
		"color": Color(0.2, 0.7, 1.0),
		"power_name": "Fortress",
		"power_desc": "Bucket expands 2x for 5s",
		"passive_name": "Resilient",
		"passive_desc": "+1 starting ball per board",
		"unlock_cost": 750,
	},
	"hexxa": {
		"name": "Hexxa",
		"shape": "hexagon",
		"color": Color(0.6, 0.2, 1.0),
		"power_name": "Chain Lightning",
		"power_desc": "Hits 3 nearest pegs",
		"passive_name": "Green Thumb",
		"passive_desc": "+1 green peg per board",
		"unlock_cost": 1000,
	},
	"nova": {
		"name": "Nova",
		"shape": "star",
		"color": Color(1.0, 0.85, 0.0),
		"power_name": "Supernova",
		"power_desc": "2x bomb radius explosion",
		"passive_name": "Glass Cannon",
		"passive_desc": "Score x1.5, but -2 balls",
		"unlock_cost": 1500,
	},
}

const CHARACTER_ORDER := ["orbie", "trixx", "kubos", "hexxa", "nova"]

var selected_character := "orbie"

func _ready() -> void:
	selected_character = SaveData.get_selected_character()

func select_character(id: String) -> void:
	if id in CHARACTERS:
		selected_character = id
		SaveData.set_selected_character(id)
		character_selected.emit(id)

func get_selected() -> Dictionary:
	return CHARACTERS.get(selected_character, CHARACTERS["orbie"])

func get_character(id: String) -> Dictionary:
	return CHARACTERS.get(id, {})

func is_unlocked(id: String) -> bool:
	if id == "orbie":
		return true
	return SaveData.is_unlocked("character_" + id)

func unlock_character(id: String) -> bool:
	var data: Dictionary = CHARACTERS.get(id, {})
	if data.is_empty():
		return false
	var cost: int = data["unlock_cost"]
	if SaveData.get_stardust() < cost:
		return false
	SaveData.add_stardust(-cost)
	SaveData.unlock("character_" + id)
	return true

# --- Passive Queries ---

func get_bucket_width_multiplier() -> float:
	if selected_character == "orbie":
		return 1.15
	return 1.0

func get_extra_starting_balls() -> int:
	if selected_character == "kubos":
		return 1
	if selected_character == "nova":
		return -2
	return 0

func get_extra_green_pegs() -> int:
	if selected_character == "hexxa":
		return 1
	return 0

func get_combo_score_multiplier(combo_count: int) -> float:
	if selected_character == "trixx" and combo_count >= 3:
		return 1.25
	return 1.0

func get_score_multiplier() -> float:
	if selected_character == "nova":
		return 1.5
	return 1.0

# --- Power Execution ---

func activate_power(ball: RigidBody2D, peg: Node) -> void:
	match selected_character:
		"orbie": _power_multiball(ball, peg)
		"trixx": _power_piercing(ball)
		"kubos": _power_fortress()
		"hexxa": _power_chain_lightning(peg)
		"nova": _power_supernova(peg)
	AudioManager.play_sfx("powerup_prism")
	power_activated.emit(selected_character, get_selected()["power_name"])

func _power_multiball(ball: RigidBody2D, peg: Node) -> void:
	var game_manager := ball.get_parent()
	var ball_scene: PackedScene = load(GameConfig.BALL_SCENE_PATH)
	for i in range(2):
		var clone: RigidBody2D = ball_scene.instantiate()
		clone.position = ball.global_position
		clone.is_clone = true
		var angle := ball.linear_velocity.angle() + (PI / 6.0 if i == 0 else -PI / 6.0)
		var speed := ball.linear_velocity.length() * 0.8
		game_manager.add_child(clone)
		clone.launch(Vector2.from_angle(angle) * speed)
		clone.ball_lost.connect(func(): clone.queue_free())

func _power_piercing(ball: RigidBody2D) -> void:
	ball.piercing_remaining = 3

func _power_fortress() -> void:
	var tree := get_tree()
	var buckets := tree.get_nodes_in_group("bucket")
	if buckets.is_empty():
		# Find bucket in current scene
		var scene := tree.current_scene
		if scene:
			var bucket := scene.get_node_or_null("Bucket")
			if bucket:
				_expand_bucket(bucket)
	else:
		for b in buckets:
			_expand_bucket(b)

func _expand_bucket(bucket: Node2D) -> void:
	var original_scale: float = bucket.scale.x
	bucket.scale.x *= 2.0
	# Reset after 5 seconds
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(bucket):
			bucket.scale.x = original_scale
	)

func _power_chain_lightning(peg: Node) -> void:
	var pegs_container: Node = peg.get_parent()
	if not pegs_container:
		return
	var center: Vector2 = peg.global_position
	var candidates: Array[Dictionary] = []
	for other in pegs_container.get_children():
		if other == peg or not other.has_method("hit"):
			continue
		if other.is_hit():
			continue
		var dist: float = center.distance_to(other.global_position)
		if dist <= GameConfig.CHAIN_RADIUS * 1.5:
			candidates.append({"peg": other, "dist": dist})
	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])
	var targets := mini(3, candidates.size())
	for i in range(targets):
		var target: Node = candidates[i]["peg"]
		var delay := 0.1 + float(i) * 0.15
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(target) and not target.is_hit():
				target.hit()
		)

func _power_supernova(peg: Node) -> void:
	var pegs_container: Node = peg.get_parent()
	if not pegs_container:
		return
	var center: Vector2 = peg.global_position
	var radius := GameConfig.BOMB_RADIUS * 2.0
	for other in pegs_container.get_children():
		if other == peg or not other.has_method("hit"):
			continue
		if other.is_hit():
			continue
		if center.distance_to(other.global_position) <= radius:
			other.hit()

# --- Shape Drawing Utility ---

static func draw_character_shape(canvas: CanvasItem, id: String, pos: Vector2, radius: float, color: Color, line_width: float = 2.0) -> void:
	var data: Dictionary = CHARACTERS.get(id, CHARACTERS["orbie"])
	var shape: String = data["shape"]
	match shape:
		"circle":
			canvas.draw_arc(pos, radius, 0, TAU, 32, color, line_width, true)
		"triangle":
			var pts := PackedVector2Array()
			for i in range(3):
				var angle := TAU * float(i) / 3.0 - PI / 2.0
				pts.append(pos + Vector2.from_angle(angle) * radius)
			pts.append(pts[0])
			canvas.draw_polyline(pts, color, line_width)
		"square":
			var half := radius * 0.75
			var pts := PackedVector2Array([
				pos + Vector2(-half, -half), pos + Vector2(half, -half),
				pos + Vector2(half, half), pos + Vector2(-half, half),
				pos + Vector2(-half, -half),
			])
			canvas.draw_polyline(pts, color, line_width)
		"hexagon":
			var pts := PackedVector2Array()
			for i in range(6):
				var angle := TAU * float(i) / 6.0 - PI / 6.0
				pts.append(pos + Vector2.from_angle(angle) * radius)
			pts.append(pts[0])
			canvas.draw_polyline(pts, color, line_width)
		"star":
			var pts := PackedVector2Array()
			for i in range(5):
				var angle := TAU * float(i) / 5.0 - PI / 2.0
				pts.append(pos + Vector2.from_angle(angle) * radius)
				var inner_angle := angle + TAU / 10.0
				pts.append(pos + Vector2.from_angle(inner_angle) * (radius * 0.4))
			pts.append(pts[0])
			canvas.draw_polyline(pts, color, line_width)
