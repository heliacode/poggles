class_name LevelLoader
extends Node

static func load_level(level_number: int) -> LevelData:
	var path := "res://data/levels/level_%03d.tres" % level_number
	if ResourceLoader.exists(path):
		return load(path) as LevelData
	return null

static func spawn_pegs(level_data: LevelData, container: Node2D, peg_script: Script) -> void:
	# Clear existing pegs
	for child in container.get_children():
		child.queue_free()

	for i in range(level_data.peg_positions.size()):
		var peg := StaticBody2D.new()
		peg.set_script(peg_script)
		peg.position = level_data.peg_positions[i]
		if i < level_data.peg_types.size():
			peg.peg_type = level_data.peg_types[i]
		if i < level_data.peg_specials.size() and level_data.peg_specials[i] != "":
			peg.special_type = level_data.peg_specials[i]
		if i < level_data.peg_power_ups.size() and level_data.peg_power_ups[i] != "":
			peg.power_up_type = level_data.peg_power_ups[i]

		# Add required child nodes
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		peg.add_child(collision)

		container.add_child(peg)
