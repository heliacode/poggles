extends Node

var _master_bus := AudioServer.get_bus_index("Master")
var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _music_crossfade_player: AudioStreamPlayer
var _combo_pitch := 1.0
var _combo_count := 0

const SFX_POOL_SIZE := 16
const COMBO_PITCH_STEP := 0.05
const COMBO_PITCH_MAX := 2.0
const COMBO_PITCH_RESET := 1.0

# Preloaded procedural SFX
var _sfx_cache: Dictionary = {}

func _ready() -> void:
	_ensure_buses()
	_apply_saved_volumes()
	_create_sfx_pool()
	_create_music_players()
	_generate_all_sfx()

func _ensure_buses() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.get_bus_index("SFX"), "Master")
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.get_bus_index("Music"), "Master")

func _apply_saved_volumes() -> void:
	set_master_volume(SaveData.get_master_volume())
	set_sfx_volume(SaveData.get_sfx_volume())
	set_music_volume(SaveData.get_music_volume())

func _create_sfx_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

func _create_music_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	_music_crossfade_player = AudioStreamPlayer.new()
	_music_crossfade_player.bus = "Music"
	add_child(_music_crossfade_player)

func _get_free_player() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.playing:
			return player
	# All busy — steal the oldest
	return _sfx_pool[0]

# --- Public API ---

func set_master_volume(vol: float) -> void:
	AudioServer.set_bus_volume_db(_master_bus, linear_to_db(vol))

func set_sfx_volume(vol: float) -> void:
	var idx := AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(vol))

func set_music_volume(vol: float) -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(vol))

func play_sfx(sfx_name: String, pitch_override: float = 0.0) -> void:
	if not _sfx_cache.has(sfx_name):
		return
	var player := _get_free_player()
	player.stream = _sfx_cache[sfx_name]
	if pitch_override > 0.0:
		player.pitch_scale = pitch_override
	else:
		player.pitch_scale = 1.0
	player.play()

func play_sfx_pitched(sfx_name: String, pitch: float) -> void:
	play_sfx(sfx_name, pitch)

func play_peg_hit(peg_type: String) -> void:
	_combo_count += 1
	_combo_pitch = minf(COMBO_PITCH_RESET + float(_combo_count) * COMBO_PITCH_STEP, COMBO_PITCH_MAX)
	var sfx_name := "peg_hit"
	if peg_type == "orange":
		sfx_name = "orange_clear"
	play_sfx(sfx_name, _combo_pitch)

func reset_combo_pitch() -> void:
	_combo_count = 0
	_combo_pitch = COMBO_PITCH_RESET

func play_music(track_name: String) -> void:
	if not _sfx_cache.has("music_" + track_name):
		return
	if _music_player.playing:
		# Crossfade
		_music_crossfade_player.stream = _sfx_cache["music_" + track_name]
		_music_crossfade_player.volume_db = -40.0
		_music_crossfade_player.play()
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_music_player, "volume_db", -40.0, 1.0)
		tween.tween_property(_music_crossfade_player, "volume_db", 0.0, 1.0)
		tween.chain().tween_callback(func():
			_music_player.stop()
			# Swap players
			var tmp := _music_player
			_music_player = _music_crossfade_player
			_music_crossfade_player = tmp
		)
	else:
		_music_player.stream = _sfx_cache["music_" + track_name]
		_music_player.volume_db = 0.0
		_music_player.play()

func stop_music(fade_time: float = 0.5) -> void:
	if _music_player.playing:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -40.0, fade_time)
		tween.tween_callback(_music_player.stop)

# --- Procedural SFX Generation ---

func _generate_all_sfx() -> void:
	_sfx_cache["peg_hit"] = _gen_peg_hit()
	_sfx_cache["orange_clear"] = _gen_orange_clear()
	_sfx_cache["cannon_fire"] = _gen_cannon_fire()
	_sfx_cache["ball_catch"] = _gen_ball_catch()
	_sfx_cache["ball_lost"] = _gen_ball_lost()
	_sfx_cache["level_complete"] = _gen_level_complete()
	_sfx_cache["game_over"] = _gen_game_over()
	_sfx_cache["fever_trigger"] = _gen_fever_trigger()
	_sfx_cache["powerup_prism"] = _gen_powerup_prism()
	_sfx_cache["powerup_overdrive"] = _gen_powerup_overdrive()
	_sfx_cache["powerup_phantom"] = _gen_powerup_phantom()
	_sfx_cache["powerup_overload"] = _gen_powerup_overload()
	_sfx_cache["menu_click"] = _gen_menu_click()
	_sfx_cache["menu_hover"] = _gen_menu_hover()
	_sfx_cache["transition_whoosh"] = _gen_transition_whoosh()
	_sfx_cache["bomb_explode"] = _gen_bomb_explode()
	_sfx_cache["chain_zap"] = _gen_chain_zap()
	_sfx_cache["armor_crack"] = _gen_armor_crack()
	_sfx_cache["gravity_well"] = _gen_gravity_well()
	_sfx_cache["near_miss"] = _gen_near_miss()
	_sfx_cache["relic_acquire"] = _gen_relic_acquire()
	_sfx_cache["shop_buy"] = _gen_shop_buy()
	_sfx_cache["shop_reroll"] = _gen_menu_click()
	# Generate procedural music tracks
	_sfx_cache["music_menu"] = _gen_music_menu()
	_sfx_cache["music_gameplay"] = _gen_music_gameplay()
	_sfx_cache["music_boss"] = _gen_music_boss()

func _make_sample(duration: float, sample_rate: int = 22050) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(duration * float(sample_rate)))
	return samples

func _samples_to_stream(samples: PackedFloat32Array, sample_rate: int = 22050) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	# Convert float32 to 16-bit PCM
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var val := clampf(samples[i], -1.0, 1.0)
		var int_val := int(val * 32767.0)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
	stream.data = data
	return stream

func _gen_peg_hit() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.08
	var samples := _make_sample(dur, rate)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		var freq := 880.0 + t * 2000.0  # Rising pitch
		samples[i] = sin(t * freq * TAU) * env * env * 0.4
	return _samples_to_stream(samples, rate)

func _gen_orange_clear() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.12
	var samples := _make_sample(dur, rate)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		var freq := 1200.0 + sin(t * 30.0) * 200.0
		samples[i] = (sin(t * freq * TAU) * 0.3 + sin(t * freq * 1.5 * TAU) * 0.15) * env * 0.5
	return _samples_to_stream(samples, rate)

func _gen_cannon_fire() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.15
	var samples := _make_sample(dur, rate)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur) * maxf(0.0, 1.0 - t / dur)
		var whoosh := sin(t * 200.0 * TAU) * (1.0 - t / dur)
		var noise := rng.randf_range(-1.0, 1.0) * maxf(0.0, 0.3 - t)
		samples[i] = (whoosh * 0.3 + noise * 0.2) * env * 0.5
	return _samples_to_stream(samples, rate)

func _gen_ball_catch() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.15
	var samples := _make_sample(dur, rate)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		var freq := 1400.0 + t * 800.0
		samples[i] = (sin(t * freq * TAU) * 0.3 + sin(t * freq * 2.0 * TAU) * 0.1) * env * env * 0.5
	return _samples_to_stream(samples, rate)

func _gen_ball_lost() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.2
	var samples := _make_sample(dur, rate)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		var freq := 300.0 - t * 600.0  # Descending
		samples[i] = sin(t * maxf(freq, 80.0) * TAU) * env * 0.3
	return _samples_to_stream(samples, rate)

func _gen_level_complete() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.8
	var samples := _make_sample(dur, rate)
	# Ascending arpeggio chord
	var notes := [523.25, 659.25, 783.99, 1046.5]  # C5, E5, G5, C6
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var val := 0.0
		for n_idx in range(notes.size()):
			var note_start := float(n_idx) * 0.12
			var note_t := t - note_start
			if note_t >= 0:
				var note_env := maxf(0.0, 1.0 - note_t / (dur - note_start)) * minf(note_t / 0.01, 1.0)
				val += sin(t * notes[n_idx] * TAU) * note_env * 0.15
		samples[i] = val * 0.6
	return _samples_to_stream(samples, rate)

func _gen_game_over() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.6
	var samples := _make_sample(dur, rate)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		var freq := 220.0 - t * 80.0
		samples[i] = (sin(t * freq * TAU) * 0.3 + sin(t * freq * 0.5 * TAU) * 0.2) * env * 0.4
	return _samples_to_stream(samples, rate)

func _gen_fever_trigger() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.5
	var samples := _make_sample(dur, rate)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := minf(t / 0.05, 1.0) * maxf(0.0, 1.0 - (t - 0.2) / 0.3)
		var freq := 600.0 + t * 1200.0  # Rising swell
		var val := sin(t * freq * TAU) * 0.2 + sin(t * freq * 1.5 * TAU) * 0.1 + sin(t * freq * 2.0 * TAU) * 0.05
		samples[i] = val * env * 0.6
	return _samples_to_stream(samples, rate)

func _gen_powerup_prism() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.25
	var samples := _make_sample(dur, rate)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur) * minf(t / 0.01, 1.0)
		samples[i] = (sin(t * 1000.0 * TAU) * 0.2 + sin(t * 1500.0 * TAU) * 0.15 + sin(t * 2000.0 * TAU) * 0.1) * env * 0.5
	return _samples_to_stream(samples, rate)

func _gen_powerup_overdrive() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.3
	var samples := _make_sample(dur, rate)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := minf(t / 0.02, 1.0) * maxf(0.0, 1.0 - t / dur)
		var freq := 400.0 + t * 800.0
		var saw := fmod(t * freq, 1.0) * 2.0 - 1.0
		samples[i] = (saw * 0.15 + sin(t * freq * TAU) * 0.2) * env * 0.5
	return _samples_to_stream(samples, rate)

func _gen_powerup_phantom() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.3
	var samples := _make_sample(dur, rate)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		var freq := 800.0 + sin(t * 20.0) * 200.0
		samples[i] = sin(t * freq * TAU) * env * env * 0.3
	return _samples_to_stream(samples, rate)

func _gen_powerup_overload() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.25
	var samples := _make_sample(dur, rate)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		samples[i] = (sin(t * 600.0 * TAU) * 0.2 + rng.randf_range(-0.1, 0.1)) * env * 0.5
	return _samples_to_stream(samples, rate)

func _gen_menu_click() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.05
	var samples := _make_sample(dur, rate)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		samples[i] = sin(t * 1200.0 * TAU) * env * env * 0.3
	return _samples_to_stream(samples, rate)

func _gen_menu_hover() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.03
	var samples := _make_sample(dur, rate)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		samples[i] = sin(t * 900.0 * TAU) * env * 0.15
	return _samples_to_stream(samples, rate)

func _gen_transition_whoosh() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.25
	var samples := _make_sample(dur, rate)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := sin(t / dur * PI)  # Bell curve
		var noise := rng.randf_range(-1.0, 1.0)
		var filtered := sin(t * (200.0 + t * 800.0) * TAU) * 0.1
		samples[i] = (noise * 0.15 + filtered) * env * 0.4
	return _samples_to_stream(samples, rate)

func _gen_bomb_explode() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.3
	var samples := _make_sample(dur, rate)
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		var noise := rng.randf_range(-1.0, 1.0)
		var bass := sin(t * 80.0 * TAU) * maxf(0.0, 1.0 - t / 0.1)
		samples[i] = (noise * 0.2 * env * env + bass * 0.4) * 0.5
	return _samples_to_stream(samples, rate)

func _gen_chain_zap() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.15
	var samples := _make_sample(dur, rate)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		var buzz := sin(t * 2000.0 * TAU) * sin(t * 50.0 * TAU)
		samples[i] = (buzz * 0.2 + rng.randf_range(-0.05, 0.05)) * env * 0.5
	return _samples_to_stream(samples, rate)

func _gen_armor_crack() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.1
	var samples := _make_sample(dur, rate)
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		var crack := rng.randf_range(-1.0, 1.0) * maxf(0.0, 0.02 - t) * 50.0
		samples[i] = (sin(t * 400.0 * TAU) * 0.2 + crack) * env * 0.4
	return _samples_to_stream(samples, rate)

func _gen_gravity_well() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.4
	var samples := _make_sample(dur, rate)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur) * minf(t / 0.05, 1.0)
		var freq := 200.0 + sin(t * 8.0) * 100.0  # Wobbling low tone
		samples[i] = sin(t * freq * TAU) * env * 0.25
	return _samples_to_stream(samples, rate)

func _gen_near_miss() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.06
	var samples := _make_sample(dur, rate)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		samples[i] = sin(t * 2500.0 * TAU) * env * env * 0.12
	return _samples_to_stream(samples, rate)

func _gen_relic_acquire() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.5
	var samples := _make_sample(dur, rate)
	var notes := [523.25, 783.99, 1046.5]  # C5, G5, C6
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var val := 0.0
		for n_idx in range(notes.size()):
			var note_start := float(n_idx) * 0.1
			var note_t := t - note_start
			if note_t >= 0:
				var note_env := maxf(0.0, 1.0 - note_t / (dur - note_start)) * minf(note_t / 0.01, 1.0)
				val += sin(t * notes[n_idx] * TAU) * note_env * 0.15
		samples[i] = val * 0.5
	return _samples_to_stream(samples, rate)

func _gen_shop_buy() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.2
	var samples := _make_sample(dur, rate)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur) * minf(t / 0.005, 1.0)
		samples[i] = (sin(t * 800.0 * TAU) * 0.2 + sin(t * 1200.0 * TAU) * 0.1) * env * 0.5
	return _samples_to_stream(samples, rate)

# --- Procedural Music Generation ---

func _gen_music_menu() -> AudioStreamWAV:
	var rate := 22050
	var dur := 16.0  # 16 second loop
	var samples := _make_sample(dur, rate)
	# Ambient pad with slow arpeggio
	var chord := [261.63, 329.63, 392.0, 523.25]  # C4, E4, G4, C5
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var val := 0.0
		# Pad: soft sustained chord
		for note in chord:
			val += sin(t * note * TAU) * 0.03
		# Slow arpeggio (one note every 2 seconds)
		var arp_idx := int(fmod(t, 8.0) / 2.0)
		var arp_note: float = chord[arp_idx]
		var arp_phase := fmod(t, 2.0)
		var arp_env := maxf(0.0, 1.0 - arp_phase / 1.5) * minf(arp_phase / 0.05, 1.0)
		val += sin(t * arp_note * 2.0 * TAU) * arp_env * 0.04
		# Sub bass
		val += sin(t * 65.41 * TAU) * 0.02
		samples[i] = val * 0.7
	var stream := _samples_to_stream(samples, rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples.size()
	return stream

func _gen_music_gameplay() -> AudioStreamWAV:
	var rate := 22050
	var dur := 16.0
	var samples := _make_sample(dur, rate)
	# More energetic — pulsing bass + arpeggiated synth
	var bpm := 120.0
	var beat_dur := 60.0 / bpm
	var chord := [220.0, 261.63, 329.63, 392.0]  # A3, C4, E4, G4
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var val := 0.0
		# Kick-like bass pulse on beats
		var beat_phase := fmod(t, beat_dur)
		var kick_env := maxf(0.0, 1.0 - beat_phase / 0.1)
		val += sin(beat_phase * 80.0 * TAU) * kick_env * kick_env * 0.08
		# Arpeggio — 16th notes
		var sixteenth := beat_dur / 4.0
		var arp_phase := fmod(t, sixteenth)
		var arp_idx := int(fmod(t / sixteenth, 4.0))
		var arp_note: float = chord[arp_idx]
		var arp_env := maxf(0.0, 1.0 - arp_phase / (sixteenth * 0.8)) * minf(arp_phase / 0.005, 1.0)
		val += sin(t * arp_note * TAU) * arp_env * 0.04
		# Pad
		val += sin(t * 130.81 * TAU) * 0.015
		val += sin(t * 196.0 * TAU) * 0.01
		samples[i] = val * 0.8
	var stream := _samples_to_stream(samples, rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples.size()
	return stream

func _gen_music_boss() -> AudioStreamWAV:
	var rate := 22050
	var dur := 16.0
	var samples := _make_sample(dur, rate)
	# Tense, faster, minor key
	var bpm := 140.0
	var beat_dur := 60.0 / bpm
	var chord := [196.0, 233.08, 293.66, 349.23]  # G3, Bb3, D4, F4 (Gm7)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var val := 0.0
		# Aggressive kick
		var beat_phase := fmod(t, beat_dur)
		var kick_env := maxf(0.0, 1.0 - beat_phase / 0.08)
		val += sin(beat_phase * 60.0 * TAU) * kick_env * kick_env * 0.1
		# Fast arpeggio
		var eighth := beat_dur / 2.0
		var arp_phase := fmod(t, eighth)
		var arp_idx := int(fmod(t / eighth, 4.0))
		var arp_note: float = chord[arp_idx]
		var arp_env := maxf(0.0, 1.0 - arp_phase / (eighth * 0.7)) * minf(arp_phase / 0.003, 1.0)
		var saw := fmod(t * arp_note, 1.0) * 2.0 - 1.0
		val += saw * arp_env * 0.03
		# Tension drone
		val += sin(t * 98.0 * TAU) * 0.02
		val += sin(t * 100.0 * TAU) * 0.015  # Slight detuning for tension
		samples[i] = val * 0.8
	var stream := _samples_to_stream(samples, rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples.size()
	return stream
