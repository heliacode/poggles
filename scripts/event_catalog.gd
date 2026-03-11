class_name EventCatalog
extends RefCounted

## Static catalog of all event scenarios.

static func get_all_events() -> Array[EventData]:
	return [
		_event_01(), _event_02(), _event_03(), _event_04(), _event_05(),
		_event_06(), _event_07(), _event_08(), _event_09(), _event_10(),
		_event_11(), _event_12(), _event_13(), _event_14(), _event_15(),
		_event_16(), _event_17(), _event_18(), _event_19(), _event_20(),
	]

static func get_events_for_act(act: int) -> Array[EventData]:
	var result: Array[EventData] = []
	for e in get_all_events():
		if e.is_available_in_act(act):
			result.append(e)
	return result

static func get_random_event(act: int, rng: RandomNumberGenerator = null) -> EventData:
	var pool := get_events_for_act(act)
	if pool.is_empty():
		return _event_01()  # fallback
	if rng:
		return pool[rng.randi_range(0, pool.size() - 1)]
	return pool[randi() % pool.size()]

# --- Event Definitions ---

static func _event_01() -> EventData:
	return EventData.new(
		"dormant_node",
		"The Dormant Node",
		"You encounter a peg cluster untouched by the Corruption — perfectly preserved, still radiating faint blue light. It hums when you approach.",
		[
			{"text": "Absorb it", "outcomes": {"coins": 15}},
			{"text": "Resonate with it", "outcomes": {"coins": 30}, "probability": 0.6},
			{"text": "Leave it", "outcomes": {"balls": 1}},
		],
		[]
	)

static func _event_02() -> EventData:
	return EventData.new(
		"corruption_broker",
		"The Corruption Broker",
		"A fractured intelligence offers you a trade. It is not hostile — it is transactional. It slides a corrupted peg toward you across the void.",
		[
			{"text": "Accept the deal", "outcomes": {"coins": 40, "next_board_mods": {"extra_armored": 2}}},
			{"text": "Demand better terms", "outcomes": {"coins": 70}, "probability": 0.5},
			{"text": "Purge the Broker", "outcomes": {"balls": -1, "coins": 20, "permanent_orange_score_bonus": 5}},
		],
		[]
	)

static func _event_03() -> EventData:
	return EventData.new(
		"echo_chamber",
		"Echo Chamber",
		"A geometric chamber vibrates at a frequency you recognize. It's a recording — a playback of a previous attempt. Your own trajectory, ghosted in faint white lines.",
		[
			{"text": "Watch the echo", "outcomes": {"next_board_mods": {"score_multiplier": 0.05}}},
			{"text": "Absorb the echo", "outcomes": {"balls": 1}},
			{"text": "Overwrite the echo", "outcomes": {"next_board_mods": {"multiplier_pegs_pre_activated": true}}},
		],
		[1]
	)

static func _event_04() -> EventData:
	return EventData.new(
		"gravity_anomaly",
		"The Gravity Anomaly",
		"The Lattice here is folded. A collapsed node has created a persistent gravity well, and several pegs have been spiraling into it for centuries.",
		[
			{"text": "Slingshot through it", "outcomes": {"next_board_mods": {"gravity_boost_first_shot": true}}},
			{"text": "Harvest the anomaly", "outcomes": {"coins_random": [20, 45]}},
			{"text": "Destabilize it", "outcomes": {"next_board_mods": {"gravity_pegs_pre_triggered": true}}},
		],
		[2]
	)

static func _event_05() -> EventData:
	return EventData.new(
		"ghostlight_merchant",
		"Ghostlight Merchant",
		"A drifting node offers services, its geometry half-dissolved. The price is paid in light — your light.",
		[
			{"text": "Buy trajectory sight", "outcomes": {"coins": -20, "next_board_mods": {"extended_aim_line": true}}},
			{"text": "Buy peg knowledge", "outcomes": {"coins": -15}},
			{"text": "Buy insurance", "outcomes": {"coins": -30, "balls": 1}},
		],
		[]
	)

static func _event_06() -> EventData:
	return EventData.new(
		"fracture_line",
		"The Fracture Line",
		"The Lattice has split here. Two divergent paths float apart, each with its own damaged logic. You can only travel one.",
		[
			{"text": "The Stable Path", "outcomes": {"next_board_mods": {"convert_blue_to_orange": 1}}},
			{"text": "The Volatile Path", "outcomes": {"next_board_mods": {"extra_bomb": 2, "extra_chain": 1}}},
		],
		[2, 3]
	)

static func _event_07() -> EventData:
	return EventData.new(
		"null_pocket",
		"The Null Pocket",
		"You've found a space where the Corruption consumed everything — and then itself. A void, perfectly still, radiating an absence that feels almost peaceful.",
		[
			{"text": "Rest in the void", "outcomes": {"balls": 2}},
			{"text": "Study the null", "outcomes": {"coins": 25, "permanent_coin_bonus": 1}},
			{"text": "Seed the void", "outcomes": {"next_board_mods": {"score_per_5_cleared": 50}}},
		],
		[3]
	)

static func _event_08() -> EventData:
	return EventData.new(
		"archive_shard",
		"The Archive Shard",
		"A crystallized data fragment from before the Collapse. Inside: structural memories, peg configurations, layout blueprints. The data is fragmented but salvageable.",
		[
			{"text": "Extract layout data", "outcomes": {"next_board_mods": {"fewer_pegs_more_orange": true}}},
			{"text": "Extract scoring data", "outcomes": {"next_board_mods": {"score_multiplier": 0.25}}},
			{"text": "Extract ball physics data", "outcomes": {"balls": 1, "coins": 10}},
		],
		[]
	)

static func _event_09() -> EventData:
	return EventData.new(
		"wardens_challenge",
		"The Warden's Challenge",
		"A residual guardian intelligence still runs its old patrol. It doesn't understand the Collapse. It sees an intruder and issues a formal challenge.",
		[
			{"text": "Accept the challenge", "outcomes": {"coins": 80, "balls_risk": -1}, "probability": 0.7},
			{"text": "Reason with it", "outcomes": {"coins": 30}},
			{"text": "Ignore it", "outcomes": {}},
		],
		[1, 2]
	)

static func _event_10() -> EventData:
	return EventData.new(
		"resonance_feedback",
		"Resonance Feedback",
		"VERTEX vibrates at a harmonic the Lattice recognizes. For a moment, the geometry reorganizes itself in sympathy. It won't last — but it's real.",
		[
			{"text": "Sustain the resonance", "outcomes": {"balls": -1, "coins": 50, "next_board_mods": {"extra_green": 2}}},
			{"text": "Release outward", "outcomes": {"next_board_mods": {"convert_blue_to_purple": 3}}},
			{"text": "Channel inward", "outcomes": {"permanent_coin_bonus": 1}},
		],
		[]
	)

static func _event_11() -> EventData:
	return EventData.new(
		"peg_graveyard",
		"The Peg Graveyard",
		"Shattered remains of ancient pegs litter the void. Some still flicker with residual energy, waiting to be repurposed.",
		[
			{"text": "Salvage the energy", "outcomes": {"coins": 35, "balls": 1}},
			{"text": "Reconstruct a peg", "outcomes": {"next_board_mods": {"extra_green": 1, "extra_bomb": 1}}},
			{"text": "Leave them in peace", "outcomes": {"score_bonus": 200}},
		],
		[]
	)

static func _event_12() -> EventData:
	return EventData.new(
		"time_loop",
		"Temporal Fold",
		"The Lattice here is folded in time. You can see echoes of your future trajectory — or rewind to claim what you've already lost.",
		[
			{"text": "Glimpse the future", "outcomes": {"next_board_mods": {"extended_aim_line": true}}},
			{"text": "Rewind for resources", "outcomes": {"balls": 2, "coins": -15}},
			{"text": "Collapse the fold", "outcomes": {"coins": 45}},
		],
		[2, 3]
	)

static func _event_13() -> EventData:
	return EventData.new(
		"crystal_cache",
		"Crystal Cache",
		"A hidden stash of crystallized stardust. The Corruption hasn't found it yet, but cracking it open will make noise.",
		[
			{"text": "Crack it open", "outcomes": {"coins": 60, "next_board_mods": {"extra_armored": 3}}, "probability": 0.8},
			{"text": "Carefully extract", "outcomes": {"coins": 25}},
			{"text": "Mark it for later", "outcomes": {"permanent_coin_bonus": 2}},
		],
		[1, 2]
	)

static func _event_14() -> EventData:
	return EventData.new(
		"mirror_node",
		"The Mirror Node",
		"A perfect reflection of yourself stares back from within the Lattice. It offers a trade — your certainty for its potential.",
		[
			{"text": "Trade certainty", "outcomes": {"balls": -1, "coins": 80}},
			{"text": "Merge with the reflection", "outcomes": {"balls": 1, "next_board_mods": {"score_multiplier": 0.15}}},
			{"text": "Shatter the mirror", "outcomes": {"coins": 20, "score_bonus": 300}},
		],
		[]
	)

static func _event_15() -> EventData:
	return EventData.new(
		"overcharged_node",
		"Overcharged Node",
		"This node crackles with excess energy. It's unstable — touching it could yield great power or backfire spectacularly.",
		[
			{"text": "Absorb the charge", "outcomes": {"next_board_mods": {"extra_chain": 2, "extra_bomb": 1}}, "probability": 0.65},
			{"text": "Siphon carefully", "outcomes": {"coins": 30, "balls": 1}},
			{"text": "Destabilize it", "outcomes": {"next_board_mods": {"gravity_pegs_pre_triggered": true}}, "probability": 0.5},
		],
		[2, 3]
	)

static func _event_16() -> EventData:
	return EventData.new(
		"wandering_merchant",
		"Wandering Merchant",
		"A figure made of interlocking geometries approaches. It speaks in angles and offers three wares.",
		[
			{"text": "Buy extra ammo (20 coins)", "outcomes": {"coins": -20, "balls": 3}},
			{"text": "Buy a power boost (30 coins)", "outcomes": {"coins": -30, "next_board_mods": {"score_multiplier": 0.3}}},
			{"text": "Rob the merchant", "outcomes": {"coins": 50, "balls_risk": -2}, "probability": 0.4},
		],
		[]
	)

static func _event_17() -> EventData:
	return EventData.new(
		"void_bloom",
		"Void Bloom",
		"Flowers of pure energy have grown in the absence of structure. They pulse with alien beauty.",
		[
			{"text": "Harvest the blooms", "outcomes": {"coins_random": [30, 70]}},
			{"text": "Plant seeds", "outcomes": {"permanent_orange_score_bonus": 8}},
			{"text": "Meditate among them", "outcomes": {"balls": 2}},
		],
		[3]
	)

static func _event_18() -> EventData:
	return EventData.new(
		"data_corruption",
		"Data Corruption",
		"A section of the Lattice is corrupted beyond recognition. The data streams are garbled, but patterns emerge in the chaos.",
		[
			{"text": "Decode the patterns", "outcomes": {"next_board_mods": {"fewer_pegs_more_orange": true}}, "probability": 0.7},
			{"text": "Purge the corruption", "outcomes": {"coins": 40}},
			{"text": "Embrace the chaos", "outcomes": {"next_board_mods": {"extra_bomb": 2, "extra_chain": 2}}},
		],
		[2, 3]
	)

static func _event_19() -> EventData:
	return EventData.new(
		"stardust_rain",
		"Stardust Rain",
		"The void above shimmers as stardust falls like rain. Each mote carries memories of what the Lattice once was.",
		[
			{"text": "Collect the stardust", "outcomes": {"coins": 25, "score_bonus": 150}},
			{"text": "Channel into power", "outcomes": {"balls": 1, "next_board_mods": {"extra_green": 1}}},
			{"text": "Let it wash over you", "outcomes": {"balls": 3}},
		],
		[]
	)

static func _event_20() -> EventData:
	return EventData.new(
		"lattice_fragment",
		"Lattice Fragment",
		"A shard of the original Lattice floats here, perfectly preserved. It hums with forgotten purpose. You could rebuild with it — or shatter it for power.",
		[
			{"text": "Rebuild with it", "outcomes": {"next_board_mods": {"convert_blue_to_orange": 2, "score_multiplier": 0.1}}},
			{"text": "Shatter for power", "outcomes": {"coins": 55, "balls": 1}},
			{"text": "Study the fragment", "outcomes": {"permanent_coin_bonus": 1, "permanent_orange_score_bonus": 5}},
		],
		[3]
	)
