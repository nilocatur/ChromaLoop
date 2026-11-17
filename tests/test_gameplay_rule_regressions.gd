extends SceneTree

const PuzzleSimulation = preload("res://scripts/core/PuzzleSimulation.gd")

func _initialize() -> void:
	_test_exact_full_belt_commits_failure()
	_test_full_belt_waits_for_progressing_tray()
	_test_full_belt_sees_multi_tray_progress()
	_test_full_belt_rejects_nonprogressing_tray()
	_test_partial_receiver_survives_save_and_reorder()
	_test_promoted_receiver_drains_older_belt_token_first()
	print("Gameplay rule regression checks passed")
	quit(0)

func _test_exact_full_belt_commits_failure() -> void:
	var simulation = PuzzleSimulation.new()
	simulation.load_level({
		"id": "exact_full", "belt_capacity": 2, "lane_count": 1,
		"tray_marble_count": 2, "moves_limit": null,
		"trays": [{"id": "t", "marbles": ["red", "red"]}],
		"lanes": [[]]
	})
	var result: Dictionary = simulation.release_tray("t")
	assert(result.get("result", "") == "jammed")
	assert(simulation.trays["t"].is_consumed())
	assert(simulation.belt.count_used() == 2)
	assert((result.get("events", []) as Array).any(func(event): return event.get("type", "") == "marble_to_belt"))

func _test_full_belt_waits_for_progressing_tray() -> void:
	var simulation = PuzzleSimulation.new()
	simulation.load_level({
		"id": "full_but_progressing", "belt_capacity": 2, "lane_count": 1,
		"tray_marble_count": 3, "moves_limit": null,
		"trays": [
			{"id": "belt", "marbles": ["blue", "blue"]},
			{"id": "drain", "marbles": ["red", "red", "red"]}
		],
		"lanes": [[{"id": "red_box", "color": "red", "capacity": 3}]]
	})
	var first: Dictionary = simulation.release_tray("belt")
	assert(first.get("result", "") == "playing")
	assert(simulation.belt.is_full())
	assert(simulation.can_release("drain"))
	var second: Dictionary = simulation.release_tray("drain")
	assert(second.get("result", "") == "jammed")
	assert(not second.get("overflowed", true))

func _test_full_belt_rejects_nonprogressing_tray() -> void:
	var simulation = PuzzleSimulation.new()
	simulation.load_level({
		"id": "full_no_progress", "belt_capacity": 2, "lane_count": 1,
		"tray_marble_count": 1, "moves_limit": null,
		"trays": [
			{"id": "belt_a", "marbles": ["blue"]},
			{"id": "belt_b", "marbles": ["blue"]},
			{"id": "partial", "marbles": ["red"]}
		],
		"lanes": [[{"id": "red_box", "color": "red", "capacity": 3}]]
	})
	simulation.release_tray("belt_a")
	var second: Dictionary = simulation.release_tray("belt_b")
	assert(second.get("result", "") == "jammed")

func _test_full_belt_sees_multi_tray_progress() -> void:
	var simulation = PuzzleSimulation.new()
	simulation.load_level({
		"id": "full_multi_tray_progress", "belt_capacity": 2, "lane_count": 1,
		"tray_marble_count": 1, "moves_limit": null,
		"trays": [
			{"id": "belt_a", "marbles": ["blue"]},
			{"id": "belt_b", "marbles": ["blue"]},
			{"id": "red_a", "marbles": ["red"]},
			{"id": "red_b", "marbles": ["red"]},
			{"id": "red_c", "marbles": ["red"]}
		],
		"lanes": [[{"id": "red_box", "color": "red", "capacity": 3}]]
	})
	simulation.release_tray("belt_a")
	var full_result: Dictionary = simulation.release_tray("belt_b")
	assert(full_result.get("result", "") == "playing")
	assert(simulation.release_tray("red_a").get("result", "") == "playing")
	assert(simulation.release_tray("red_b").get("result", "") == "playing")
	var progress_result: Dictionary = simulation.release_tray("red_c")
	assert(progress_result.get("result", "") == "jammed")
	assert(simulation.lanes[0].remaining_receivers_count() == 0)

func _test_partial_receiver_survives_save_and_reorder() -> void:
	var simulation = PuzzleSimulation.new()
	simulation.load_level({
		"id": "partial", "belt_capacity": 6, "lane_count": 1,
		"tray_marble_count": 1, "moves_limit": null,
		"allowed_boosters": ["reorder"],
		"trays": [{"id": "t", "marbles": ["red"]}],
		"lanes": [[
			{"id": "r1", "color": "red", "capacity": 3},
			{"id": "r2", "color": "blue", "capacity": 3},
			{"id": "r3", "color": "green", "capacity": 3}
		]]
	})
	simulation.release_tray("t")
	assert(simulation.lanes[0].front().get("current_count", 0) == 1)
	simulation.apply_booster("reorder")
	assert(simulation.lanes[0].front().get("current_count", 0) == 1)
	var restored = PuzzleSimulation.new()
	restored.restore_from_dict(simulation.to_dict())
	assert(restored.lanes[0].front().get("current_count", 0) == 1)

func _test_promoted_receiver_drains_older_belt_token_first() -> void:
	var simulation = PuzzleSimulation.new()
	simulation.load_level({
		"id": "cascade_order", "belt_capacity": 8, "lane_count": 1,
		"tray_marble_count": 4, "moves_limit": null,
		"trays": [
			{"id": "old", "marbles": ["blue", "green", "green", "green"]},
			{"id": "release", "marbles": ["red", "red", "red", "blue"]}
		],
		"lanes": [[
			{"id": "red_box", "color": "red", "capacity": 3},
			{"id": "blue_box", "color": "blue", "capacity": 3},
			{"id": "green_box", "color": "green", "capacity": 3}
		]]
	})
	simulation.release_tray("old")
	var result: Dictionary = simulation.release_tray("release")
	var events: Array = result.get("events", []) as Array
	var old_blue_absorb := -1
	var new_blue_absorb := -1
	for i in range(events.size()):
		var event: Dictionary = events[i] as Dictionary
		if event.get("type", "") != "marble_absorbed":
			continue
		if event.get("token_id", "") == "old_m0":
			old_blue_absorb = i
		elif event.get("token_id", "") == "release_m3":
			new_blue_absorb = i
	assert(old_blue_absorb >= 0)
	assert(new_blue_absorb >= 0)
	assert(old_blue_absorb < new_blue_absorb)
