class_name AudioDirector
extends Node

# §7.2 / §23.1 — Music & SFX buses + Master. Event keys map to real audio.
var music_bus: int = 1
var sfx_bus: int = 2
var master_bus: int = 0

var music_volume: float = 0.8
var sfx_volume: float = 0.8
var haptics: bool = true
var reduced_motion: bool = false

var _music_player: AudioStreamPlayer2D

const MAX_ROLLING_CONCURRENT := 2  # §7.2 — limit concurrent rolling sounds

func _ready() -> void:
	_setup_buses()
	_music_player = AudioStreamPlayer2D.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	var progress = get_node_or_null("/root/PlayerProgress")
	if progress != null:
		apply_settings(progress.get_settings())
		progress.settings_changed.connect(self._on_settings_changed)

func _setup_buses() -> void:
	# ensure Music and SFX buses exist (§7.2). add_bus() returns void; index is last.
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "Music")
		music_bus = idx
	else:
		music_bus = AudioServer.get_bus_index("Music")

	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "SFX")
		sfx_bus = idx
	else:
		sfx_bus = AudioServer.get_bus_index("SFX")

	master_bus = 0
	set_bus_volumes()

func set_bus_volumes() -> void:
	AudioServer.set_bus_volume_db(music_bus, _linear_to_db(music_volume))
	AudioServer.set_bus_volume_db(sfx_bus, _linear_to_db(sfx_volume))

func _linear_to_db(linear: float) -> float:
	if linear <= 0:
		return -80.0
	return 20.0 * (log(linear) / log(10.0))

func play_music(event_key: String, loop: bool = true) -> void:
	if music_volume <= 0:
		return
	var path := _asset_path(event_key)
	if path == "":
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var playback_stream: AudioStream = stream.duplicate() as AudioStream
	if playback_stream is AudioStreamWAV:
		playback_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	elif playback_stream is AudioStreamOggVorbis:
		playback_stream.loop = loop
	_music_player.stream = playback_stream
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()
	_music_player.stream = null

func play_sfx(event_key: String) -> void:
	if sfx_volume <= 0:
		return
	var path := _asset_path(event_key)
	if path == "":
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.bus = "SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _asset_path(event_key: String) -> String:
	# §7.2 / §19.4 — placeholder mapping until real audio imported & AUDIO_MAPPING.md written
	var mapping = {
		"ui_tap": "res://assets/audio/sfx/button_tap.wav",
		"tray_select": "res://assets/audio/sfx/tile_tap.wav",
		"marble_release": "res://assets/audio/sfx/marble_drop.wav",
		"marble_roll": "res://assets/audio/sfx/belt_hum_loop.wav",
		"receiver_fill": "res://assets/audio/sfx/slot_fill_1.wav",
		"receiver_complete": "res://assets/audio/sfx/stars_appear.wav",
		"belt_warning": "res://assets/audio/sfx/belt_jam.wav",
		"booster_use": "res://assets/audio/sfx/cannon.wav",
		"victory": "res://assets/audio/sfx/level_complete.wav",
		"failure": "res://assets/audio/sfx/fail.wav",
		"lobby_music": "res://assets/audio/music/bgm_lobby.wav",
		"gameplay_music": "res://assets/audio/music/bgm_game.wav",
		"ice_break": "res://assets/audio/sfx/ice_break.wav",
		"mystery_reveal": "res://assets/audio/sfx/mystery_reveal.wav",
		"magnet": "res://assets/audio/sfx/magnet.wav",
		"shuffle": "res://assets/audio/sfx/shuffle.wav",
		"booster_locked": "res://assets/audio/sfx/booster_locked.wav"
	}
	return mapping.get(event_key, "") as String

func set_music_volume(v: float) -> void:
	music_volume = clamp(v, 0.0, 1.0)
	set_bus_volumes()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clamp(v, 0.0, 1.0)
	set_bus_volumes()

func set_haptics(enabled: bool) -> void:
	haptics = enabled

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled

func vibrate(duration_ms: int) -> void:
	if haptics and duration_ms > 0:
		Input.vibrate_handheld(duration_ms)

func apply_settings(values: Dictionary) -> void:
	set_music_volume(values.get("music_volume", 0.8) as float)
	set_sfx_volume(values.get("sfx_volume", 0.8) as float)
	set_haptics(values.get("haptics", true) as bool)
	set_reduced_motion(values.get("reduced_motion", false) as bool)

func _on_settings_changed() -> void:
	var progress = get_node_or_null("/root/PlayerProgress")
	if progress != null:
		apply_settings(progress.get_settings())
