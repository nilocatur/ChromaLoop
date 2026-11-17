class_name LevelValidator
extends RefCounted

const PuzzleSimulation = preload("res://scripts/core/PuzzleSimulation.gd")
const COLORS = ["red", "blue", "green", "yellow", "purple", "orange", "pink", "cyan", "navy", "lime", "silver", "brown"]
const TRAY_TYPES = ["standard", "mystery", "locked", "crate", "ice"]

func validate(level: Dictionary) -> Array:
	var errors: Array = []
	for key in ["id", "number", "seed", "belt_capacity", "lane_count", "tray_marble_count", "trays", "lanes"]:
		if not level.has(key):
			errors.push_back("missing " + key)
	if level.get("lane_count", 0) as int != 4:
		errors.push_back("lane_count must be 4")
	var supply: Dictionary = {}
	var tray_ids: Dictionary = {}
	var tray_colors: Dictionary = {}
	for tray in level.get("trays", []):
		var tray_id: String = tray.get("id", "") as String
		if tray_id == "" or tray_ids.has(tray_id):
			errors.push_back("missing or duplicate tray id " + tray_id)
		tray_ids[tray_id] = true
		var tray_type: String = tray.get("type", "standard") as String
		if not TRAY_TYPES.has(tray_type):
			errors.push_back("unknown tray type " + tray_type)
		var marbles: Array = tray.get("marbles", []) as Array
		if marbles.size() != level.get("tray_marble_count", 9) as int:
			errors.push_back("tray " + str(tray.get("id", "")) + " has wrong marble count")
		for color in marbles:
			if not COLORS.has(color):
				errors.push_back("unknown color " + str(color))
			supply[color] = supply.get(color, 0) as int + 1
		var unique_colors: Dictionary = {}
		for color in marbles:
			unique_colors[color] = true
		if unique_colors.size() != 1:
			errors.push_back("tray " + tray_id + " must contain one marble color")
		elif not marbles.is_empty():
			var tray_color: String = String(marbles[0])
			if tray_colors.has(tray_color):
				errors.push_back("duplicate tray color " + tray_color)
			tray_colors[tray_color] = true
	for tray in level.get("trays", []):
		var tray_type: String = tray.get("type", "standard") as String
		var prerequisites: Array = tray.get("unlock_after", []) as Array
		if tray_type != "standard" and prerequisites.size() == 0:
			errors.push_back("mechanic tray requires unlock_after")
		for prerequisite in prerequisites:
			if not tray_ids.has(prerequisite) or prerequisite == tray.get("id", ""):
				errors.push_back("invalid unlock prerequisite " + str(prerequisite))
	var opening_count := 0
	for tray in level.get("trays", []):
		if (tray.get("unlock_after", []) as Array).size() == 0:
			opening_count += 1
	if opening_count == 0:
		errors.push_back("level has no opening tray")
	var reachable: Dictionary = {}
	var changed := true
	while changed:
		changed = false
		for tray in level.get("trays", []):
			var tray_id: String = String(tray.get("id", ""))
			if reachable.has(tray_id):
				continue
			var ready := true
			for prerequisite in tray.get("unlock_after", []):
				if not reachable.has(prerequisite):
					ready = false
					break
			if ready:
				reachable[tray_id] = true
				changed = true
	if reachable.size() != tray_ids.size():
		errors.push_back("tray prerequisites contain a cycle or unreachable tray")
	var demand: Dictionary = {}
	var lanes: Array = level.get("lanes", []) as Array
	if lanes.size() != 4:
		errors.push_back("lanes array must contain 4 lanes")
	for lane in lanes:
		for receiver in lane:
			var capacity: int = receiver.get("capacity", 0) as int
			if capacity != 3:
				errors.push_back("receiver capacity must be 3")
			var color: String = receiver.get("color", "") as String
			demand[color] = demand.get(color, 0) as int + capacity
	if supply != demand:
		errors.push_back("color supply does not equal receiver demand")
	return errors

func solve(level: Dictionary, state_budget: int = 10000) -> Dictionary:
	var tray_ids: Array = []
	for tray in level.get("trays", []):
		tray_ids.push_back(tray.get("id", "") as String)
	var result = {"classification": "unsolvable", "trace": [], "states_explored": 0, "solution_count": 0}
	_search(level, tray_ids, [], result, state_budget)
	if result.get("states_explored", 0) as int >= state_budget:
		result["classification"] = "unverified"
	return result

func _search(level: Dictionary, remaining: Array, trace: Array, result: Dictionary, budget: int) -> void:
	if result.get("states_explored", 0) as int >= budget:
		return
	if remaining.size() == 0:
		result["states_explored"] = result.get("states_explored", 0) as int + 1
		var simulation = PuzzleSimulation.new()
		simulation.load_level(level)
		for i in range(trace.size()):
			var release: Dictionary = simulation.release_tray(trace[i], false)
			if release.get("overflowed", false):
				break
			# Skip expensive future-action lookahead while validating a complete trace.
			# Later trace actions determine whether a provisionally full belt can progress.
			if simulation.get_status() == "jammed" and i < trace.size() - 1:
				simulation.status = "playing"
		if simulation.get_status() == "won":
			result["classification"] = "solvable"
			result["solution_count"] = result.get("solution_count", 0) as int + 1
			if (result.get("trace", []) as Array).is_empty():
				result["trace"] = trace.duplicate()
		return
	for i in range(remaining.size()):
		var tray_id: String = String(remaining[i])
		if not _prerequisites_met(level, tray_id, trace):
			continue
		var next_remaining = remaining.duplicate()
		next_remaining.pop_at(i)
		var next_trace = trace.duplicate()
		next_trace.push_back(tray_id)
		_search(level, next_remaining, next_trace, result, budget)

func _prerequisites_met(level: Dictionary, tray_id: String, trace: Array) -> bool:
	for tray in level.get("trays", []):
		if String(tray.get("id", "")) != tray_id:
			continue
		for prerequisite in tray.get("unlock_after", []):
			if not trace.has(prerequisite):
				return false
		return true
	return false
