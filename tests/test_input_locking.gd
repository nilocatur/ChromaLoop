extends SceneTree

func _initialize() -> void:
	await process_frame
	var gameplay = load("res://scenes/gameplay/Gameplay.tscn").instantiate()
	get_root().add_child(gameplay)
	await process_frame
	await process_frame
	if gameplay.audio_director != null:
		gameplay.audio_director.set_reduced_motion(true)
		gameplay.audio_director.set_sfx_volume(0.0)

	var tray_ids: Array = gameplay.simulation.trays.keys()
	assert(tray_ids.size() > 0)
	var target := ""
	for id in tray_ids:
		if gameplay.simulation.can_release(id):
			target = String(id)
			break
	assert(target != "")
	var before_actions: int = gameplay.simulation.committed_action_count

	# Rapid duplicate taps: the input lock must admit exactly one release.
	gameplay.on_tray_tap(target)
	gameplay.on_tray_tap(target)
	gameplay.on_tray_tap(target)
	assert(gameplay.simulation.committed_action_count == before_actions + 1)

	# The released tray cannot be tapped a second time after the lock clears.
	gameplay._input_locked = false
	assert(not gameplay.simulation.can_release(target))

	if gameplay.player_progress != null:
		gameplay.player_progress.clear_run()
	if gameplay.audio_director != null:
		gameplay.audio_director.set_reduced_motion(false)
		gameplay.audio_director.set_sfx_volume(0.8)
	gameplay.free()
	await process_frame

	print("Input locking checks passed")
	quit()
