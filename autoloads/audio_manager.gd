extends Node

var _master_bus := AudioServer.get_bus_index("Master")

func _ready() -> void:
	_ensure_buses()
	_apply_saved_volumes()

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

func play_sfx(stream: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
