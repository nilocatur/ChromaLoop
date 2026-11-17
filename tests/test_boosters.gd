extends SceneTree

const PuzzleSimulation = preload("res://scripts/core/PuzzleSimulation.gd")

func _level() -> Dictionary:
	return {
		"id": "booster_test", "seed": 5, "belt_capacity": 22, "lane_count": 2,
		"tray_marble_count": 9, "moves_limit": null,
		"allowed_boosters": ["sweep", "picker", "reorder"],
		"trays": [
			{"id": "open", "grid_x": 0, "grid_y": 0, "type": "standard", "marbles": ["red", "red", "red", "red", "red", "red", "red", "red", "red"]},
			{"id": "hidden", "grid_x": 1, "grid_y": 0, "type": "mystery", "unlock_after": ["open"], "marbles": ["blue", "blue", "blue", "blue", "blue", "blue", "blue", "blue", "blue"]}
		],
		"lanes": [
			[{"id": "r1", "color": "green", "capacity": 3}, {"id": "r2", "color": "green", "capacity": 3}],
			[{"id": "r3", "color": "yellow", "capacity": 3}]
		]
	}

func _initialize() -> void:
	# Sweep clears the belt into the rescued sink.
	var sweep_sim = PuzzleSimulation.new()
	sweep_sim.load_level(_level())
	assert(sweep_sim.release_tray("open").get("ok", false))
	assert(sweep_sim.belt.count_used() == 9)
	assert(sweep_sim.can_use_booster("sweep").get("ok", false))
	var swept: Dictionary = sweep_sim.apply_booster("sweep")
	assert(swept.get("ok", false))
	assert(sweep_sim.belt.count_used() == 0)
	assert(sweep_sim.rescued_token_ids.size() == 9)
	# Using sweep with an empty belt is a no-op that consumes nothing.
	assert(not sweep_sim.can_use_booster("sweep").get("ok", false))

	# Picker unlocks exactly one inaccessible tray and nothing else.
	var picker_sim = PuzzleSimulation.new()
	picker_sim.load_level(_level())
	assert(not picker_sim.can_use_booster("picker", "open").get("ok", false))
	assert(picker_sim.can_use_booster("picker", "hidden").get("ok", false))
	var picked: Dictionary = picker_sim.apply_booster("picker", "hidden")
	assert(picked.get("ok", false))
	assert(picker_sim.trays["hidden"].is_accessible())
	assert(not picker_sim.can_use_booster("picker", "hidden").get("ok", false))
	assert(not picker_sim.can_use_booster("picker", "missing").get("ok", false))

	# Reorder deterministically sorts queued receivers while preserving counts.
	var reorder_sim = PuzzleSimulation.new()
	reorder_sim.load_level(_level())
	assert(reorder_sim.can_use_booster("reorder").get("ok", false))
	var before_total := _total_receivers(reorder_sim)
	reorder_sim.apply_booster("reorder")
	assert(_total_receivers(reorder_sim) == before_total)
	var reorder_check = PuzzleSimulation.new()
	reorder_check.load_level(_level())
	reorder_check.apply_booster("reorder")
	assert(reorder_check.last_state_checksum == reorder_sim.last_state_checksum)

	# Disallowed and unknown boosters are rejected.
	var restricted = PuzzleSimulation.new()
	var restricted_level := _level()
	restricted_level["allowed_boosters"] = []
	restricted.load_level(restricted_level)
	assert(not restricted.can_use_booster("sweep").get("ok", false))
	assert(not restricted.can_use_booster("teleport").get("ok", false))

	# Terminal states block booster use.
	var finished = PuzzleSimulation.new()
	finished.load_level(_level())
	finished.status = "won"
	assert(not finished.can_use_booster("sweep").get("ok", false))

	print("Booster checks passed")
	quit()

func _total_receivers(simulation) -> int:
	var total := 0
	for lane in simulation.lanes:
		total += lane.queue.size()
	return total
