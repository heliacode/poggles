class_name BossData
extends RefCounted

var boss_name: String
var title: String
var description: String
var act: int
var hp: int
var phases: Array[Dictionary]  # [{hp_threshold: float, action: String}]
var layout_type: String

static func get_boss(act: int) -> BossData:
	match act:
		1: return _sentinel()
		2: return _warden()
		3: return _void()
	return _sentinel()

static func _sentinel() -> BossData:
	var b := BossData.new()
	b.boss_name = "The Sentinel"
	b.title = "Guardian of the Surface"
	b.description = "A hexagonal fortress with an armored core."
	b.act = 1
	b.hp = 500
	b.phases = [
		{"hp_threshold": 0.5, "action": "spawn_armored", "count": 3},
		{"hp_threshold": 0.25, "action": "narrow_bucket"},
	]
	b.layout_type = "hexagonal"
	return b

static func _warden() -> BossData:
	var b := BossData.new()
	b.boss_name = "The Warden"
	b.title = "Keeper of the Core"
	b.description = "Moving pegs and gravity wells in a defensive ring."
	b.act = 2
	b.hp = 800
	b.phases = [
		{"hp_threshold": 0.5, "action": "add_movement"},
		{"hp_threshold": 0.25, "action": "spawn_gravity", "count": 2},
	]
	b.layout_type = "ring_defense"
	return b

static func _void() -> BossData:
	var b := BossData.new()
	b.boss_name = "The Void"
	b.title = "Heart of the Abyss"
	b.description = "Invisible pegs that shift and fade."
	b.act = 3
	b.hp = 1200
	b.phases = [
		{"hp_threshold": 0.5, "action": "hide_pegs"},
		{"hp_threshold": 0.25, "action": "shrink_area"},
	]
	b.layout_type = "void_scatter"
	return b
