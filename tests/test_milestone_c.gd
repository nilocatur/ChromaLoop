extends SceneTree

const PuzzleSimulation = preload("res://scripts/core/PuzzleSimulation.gd")

func _initialize() -> void:
	var level := {
		"id": "mechanic_test", "seed": 1, "belt_capacity": 22, "lane_count": 4,
		"tray_marble_count": 9, "moves_limit": 2,
		"trays": [
			{"id": "open", "grid_x": 0, "grid_y": 0, "type": "standard", "marbles": ["red", "red", "red", "red", "red", "red", "red", "red", "red"]},
			{"id": "hidden", "grid_x": 1, "grid_y": 0, "type": "mystery", "unlock_after": ["open"], "marbles": ["blue", "blue", "blue", "blue", "blue", "blue", "blue", "blue", "blue"]}
		],
		"lanes": [[{"id": "r1", "color": "red", "capacity": 3}, {"id": "r2", "color": "blue", "capacity": 3}], [{"id": "r3", "color": "red", "capacity": 3}, {"id": "r4", "color": "blue", "capacity": 3}], [{"id": "r5", "color": "red", "capacity": 3}], [{"id": "r6", "color": "blue", "capacity": 3}]]
	}
	var simulation = PuzzleSimulation.new()
	simulation.load_level(level)
	assert(not simulation.can_release("hidden"))
	var first: Dictionary = simulation.release_tray("open")
	assert(first.get("ok", false))
	assert(simulation.can_release("hidden"))
	assert((first.get("events", []) as Array).any(func(event): return event.get("type", "") == "tray_revealed"))
	assert(simulation.release_tray("hidden").get("result", "") == "won")
	print("Milestone C mechanic self-check passed")
	quit(0)
