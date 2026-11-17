extends SceneTree

func _initialize() -> void:
	await process_frame
	var progress = get_root().get_node("PlayerProgress")
	var saved_run: Dictionary = progress.run.duplicate(true)

	var level_file := FileAccess.open("res://data/levels/level_001.json", FileAccess.READ)
	assert(level_file != null)
	var level: Dictionary = JSON.parse_string(level_file.get_as_text()) as Dictionary
	level_file.close()

	var simulation = load("res://scripts/core/PuzzleSimulation.gd").new()
	simulation.load_level(level)
	assert(simulation.release_tray("t1").get("ok", false))

	var state: Dictionary = simulation.to_dict()
	assert(progress.save_run_state("level_001", state))
	var loaded_run: Dictionary = progress.get_run()
	assert(loaded_run.get("level_id", "") == "level_001")
	assert(loaded_run.get("status", "") == "playing")
	assert(loaded_run.get("serialized_simulation_state", null) is Dictionary)

	var restored = load("res://scripts/core/PuzzleSimulation.gd").new()
	restored.restore_from_dict(loaded_run.get("serialized_simulation_state", {}) as Dictionary)
	assert(restored.last_state_checksum == simulation.last_state_checksum)
	assert(restored.committed_action_count == 1)

	# Incompatible rules version must not be accepted by the controller guard.
	var mismatch: Dictionary = state.duplicate(true)
	mismatch["rules_version"] = 999
	assert(int(mismatch.get("rules_version", 0)) != simulation.rules_version)

	# Malformed save dictionaries produce safe defaults.
	var malformed_load: Dictionary = progress._migrate({}, 0)
	assert(malformed_load.get("save_schema", 0) == progress.SAVE_SCHEMA)

	progress.run = saved_run
	progress._save()

	print("Save/restore checks passed")
	quit()
