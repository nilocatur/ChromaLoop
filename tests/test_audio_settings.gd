extends SceneTree

func _initialize() -> void:
	await process_frame
	var audio = get_root().get_node("AudioDirector")
	var progress = get_root().get_node("PlayerProgress")

	audio.set_music_volume(0.0)
	audio.set_sfx_volume(0.0)
	assert(AudioServer.get_bus_volume_db(audio.music_bus) <= -79.0)
	assert(AudioServer.get_bus_volume_db(audio.sfx_bus) <= -79.0)

	audio.set_music_volume(1.0)
	audio.set_sfx_volume(1.0)
	assert(abs(AudioServer.get_bus_volume_db(audio.music_bus)) < 0.5)
	assert(abs(AudioServer.get_bus_volume_db(audio.sfx_bus)) < 0.5)

	# apply_settings mirrors persisted values onto the buses and toggles.
	audio.apply_settings({"music_volume": 0.0, "sfx_volume": 0.0, "haptics": false, "reduced_motion": true})
	assert(audio.music_volume == 0.0)
	assert(audio.reduced_motion)
	assert(not audio.haptics)

	# Settings persist through the save layer.
	var saved_settings: Dictionary = progress.settings.duplicate(true)
	progress.set_setting("music_volume", 0.25)
	progress.set_setting("reduced_motion", true)
	var reloaded: Dictionary = progress.get_settings()
	assert(abs(reloaded.get("music_volume", 0.0) - 0.25) < 0.001)
	progress.settings = saved_settings
	progress._save()

	audio.stop_music()
	audio.set_music_volume(0.0)
	audio.set_sfx_volume(0.0)

	print("Audio/settings checks passed")
	quit()
