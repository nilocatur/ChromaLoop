extends SceneTree

const PuzzleSimulation = preload("res://scripts/core/PuzzleSimulation.gd")

func _load_level() -> Dictionary:
	var file := FileAccess.open("res://data/levels/level_001.json", FileAccess.READ)
	assert(file != null)
	var level: Dictionary = JSON.parse_string(file.get_as_text()) as Dictionary
	file.close()
	return level

func _initialize() -> void:
	var level := _load_level()

	var first := PuzzleSimulation.new()
	first.load_level(level)
	var first_result: Dictionary = first.release_tray("t1")
	assert(first_result.get("ok", false))
	var midpoint: Dictionary = first.to_dict()
	var checkpoint_checksum := first.last_state_checksum
	var second_result: Dictionary = first.release_tray("t2")
	assert(second_result.get("ok", false))
	assert(first.get_status() == "won")
	var final_checksum := first.last_state_checksum

	# Same actions, fresh instance
	var replay := PuzzleSimulation.new()
	replay.load_level(level)
	replay.release_tray("t1")
	assert(replay.last_state_checksum == checkpoint_checksum)
	replay.release_tray("t2")
	assert(replay.get_status() == "won")
	assert(replay.last_state_checksum == final_checksum)

	# Serialize after first action, restore, then continue
	var restored := PuzzleSimulation.new()
	restored.restore_from_dict(midpoint)
	assert(restored.last_state_checksum == checkpoint_checksum)
	assert(restored.can_release("t2"))
	restored.release_tray("t2")
	assert(restored.get_status() == "won")
	assert(restored.last_state_checksum == final_checksum)

	# Round-trip fields survive
	var round_trip: Dictionary = restored.to_dict()
	assert(round_trip.get("belt_capacity", 0) == level.get("belt_capacity"))
	assert((round_trip.get("trays", []) as Array).size() == 2)
	assert((round_trip.get("lanes", []) as Array).size() == 4)
	assert(round_trip.get("status", "") == "won")

	# Jam rollback stays byte-identical for every token
	var jam_level := {
		"id": "jam_rollback", "seed": 7, "belt_capacity": 1, "lane_count": 4,
		"tray_marble_count": 2, "moves_limit": null,
		"trays": [{"id": "t1", "grid_x": 0, "grid_y": 0, "marbles": ["red", "red"]}],
		"lanes": [[], [], [], []]
	}
	var jam := PuzzleSimulation.new()
	jam.load_level(jam_level)
	var before: Dictionary = jam.to_dict()
	var jam_result: Dictionary = jam.release_tray("t1")
	assert(jam_result.get("result", "") == "jammed")
	var after: Dictionary = jam.to_dict()
	assert((before.get("trays", []) as Array)[0]["marbles"] == (after.get("trays", []) as Array)[0]["marbles"])
	assert(before.get("belt") == after.get("belt"))
	assert((after.get("trays", []) as Array)[0]["consumed"] == false)

	print("Deterministic replay checks passed")
	quit()
