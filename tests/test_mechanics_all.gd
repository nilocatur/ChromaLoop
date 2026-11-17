extends SceneTree

const PuzzleSimulation = preload("res://scripts/core/PuzzleSimulation.gd")

func _level() -> Dictionary:
	return {
		"id": "mechanics_all", "seed": 11, "belt_capacity": 22, "lane_count": 4,
		"tray_marble_count": 9, "moves_limit": null,
		"trays": [
			{"id": "open", "grid_x": 0, "grid_y": 0, "type": "standard", "marbles": ["red", "red", "red", "red", "red", "red", "red", "red", "red"]},
			{"id": "mystery", "grid_x": 1, "grid_y": 0, "type": "mystery", "unlock_after": ["open"], "marbles": ["blue", "blue", "blue", "blue", "blue", "blue", "blue", "blue", "blue"]},
			{"id": "locked", "grid_x": 0, "grid_y": 1, "type": "locked", "unlock_after": ["mystery"], "marbles": ["green", "green", "green", "green", "green", "green", "green", "green", "green"]},
			{"id": "crate", "grid_x": 1, "grid_y": 1, "type": "crate", "unlock_after": ["locked"], "marbles": ["yellow", "yellow", "yellow", "yellow", "yellow", "yellow", "yellow", "yellow", "yellow"]},
			{"id": "ice", "grid_x": 2, "grid_y": 1, "type": "ice", "unlock_after": ["crate"], "marbles": ["purple", "purple", "purple", "purple", "purple", "purple", "purple", "purple", "purple"]}
		],
		"lanes": [
			[{"id": "r1", "color": "red", "capacity": 3}, {"id": "r1b", "color": "red", "capacity": 3}],
			[{"id": "r2", "color": "blue", "capacity": 3}, {"id": "r2b", "color": "blue", "capacity": 3}],
			[{"id": "r3", "color": "green", "capacity": 3}, {"id": "r3b", "color": "green", "capacity": 3}],
			[{"id": "r4", "color": "yellow", "capacity": 3}, {"id": "r4b", "color": "yellow", "capacity": 3}]
		]
	}

func _initialize() -> void:
	var sim = PuzzleSimulation.new()
	sim.load_level(_level())

	# Every mechanic starts blocked; mystery must not leak its contents.
	assert(not sim.trays["mystery"].is_revealed())
	assert(not sim.trays["locked"].is_accessible())
	assert(not sim.trays["crate"].is_accessible())
	assert(not sim.trays["ice"].is_accessible())

	var events: Array = sim.release_tray("open").get("events", [])
	assert(_has_event(events, "tray_revealed", "mystery"))
	assert(_event_index(events, "marble_released") < _event_index(events, "tray_revealed"))
	assert(sim.trays["mystery"].is_revealed())
	assert(sim.trays["mystery"].is_accessible())

	events = sim.release_tray("mystery").get("events", [])
	assert(_has_event(events, "tray_unlocked", "locked"))
	events = sim.release_tray("locked").get("events", [])
	assert(_has_event(events, "obstacle_cleared", "crate"))
	events = sim.release_tray("crate").get("events", [])
	assert(_has_event(events, "obstacle_cleared", "ice"))

	# Each mechanic state survives serialization.
	var restored = PuzzleSimulation.new()
	restored.restore_from_dict(sim.to_dict())
	assert(restored.trays["ice"].is_accessible())
	assert(restored.trays["mystery"].is_revealed())
	assert(restored.last_state_checksum == sim.last_state_checksum)

	print("All mechanics checks passed")
	quit()

func _has_event(events: Array, type: String, mechanic: String) -> bool:
	for event in events:
		if String(event.get("type", "")) == type and String(event.get("mechanic", "")) == mechanic:
			return true
	return false

func _event_index(events: Array, type: String) -> int:
	for i in range(events.size()):
		if String((events[i] as Dictionary).get("type", "")) == type:
			return i
	return -1
