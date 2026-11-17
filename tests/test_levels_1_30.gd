extends SceneTree

const LevelValidator = preload("res://scripts/data/LevelValidator.gd")
const PuzzleSimulation = preload("res://scripts/core/PuzzleSimulation.gd")

func _initialize() -> void:
	var validator = LevelValidator.new()
	var mechanic_counts := {"mystery": 0, "locked": 0, "crate": 0, "ice": 0}
	var signatures: Dictionary = {}
	for number in range(1, 31):
		var file := FileAccess.open("res://data/levels/level_%03d.json" % number, FileAccess.READ)
		assert(file != null)
		var level: Dictionary = JSON.parse_string(file.get_as_text()) as Dictionary
		assert(validator.validate(level).is_empty(), str(validator.validate(level)))
		if number <= 10:
			var tutorial_colors: Dictionary = {}
			for tray in level.get("trays", []):
				tutorial_colors[(tray.get("marbles", []) as Array)[0]] = true
			assert(tutorial_colors.size() >= 2 and tutorial_colors.size() <= 4, "Levels 1-10 require 2-4 colors")
		var signature := JSON.stringify([level.get("trays", []), level.get("lanes", [])])
		assert(not signatures.has(signature), "duplicate level layout")
		signatures[signature] = true
		for tray in level.get("trays", []):
			var marbles: Array = tray.get("marbles", []) as Array
			assert(not marbles.is_empty())
			assert(marbles.all(func(color): return color == marbles[0]), "mixed-color tray in %s" % level.get("id", ""))
			var type: String = tray.get("type", "standard") as String
			if mechanic_counts.has(type):
				mechanic_counts[type] += 1
		var trace: Array = (level.get("validation", {}) as Dictionary).get("expected_trace", []) as Array
		var tray_color_set: Dictionary = {}
		for tray in level.get("trays", []):
			tray_color_set[(tray.get("marbles", []) as Array)[0]] = true
		assert(tray_color_set.size() == (level.get("trays", []) as Array).size(), "duplicate tray color in %s" % level.get("id", ""))
		assert(trace.size() == (level.get("trays", []) as Array).size())
		var simulation = PuzzleSimulation.new()
		simulation.load_level(level)
		for tray_id in trace:
			var result: Dictionary = simulation.release_tray(tray_id)
			assert(result.get("ok", false), "%s blocked in %s" % [tray_id, level.get("id", "")])
		assert(simulation.get_status() == "won", str(level.get("id", "")))
		var solved: Dictionary = validator.solve(level)
		assert(solved.get("classification", "") == "solvable", str(level.get("id", "")))
		var expected_solutions := int((level.get("validation", {}) as Dictionary).get("solution_count", -1))
		assert(int(solved.get("solution_count", 0)) == expected_solutions, "solution count drift in %s" % level.get("id", ""))
		var solution_ratio := float(expected_solutions) / float(maxi(1, int(solved.get("states_explored", 0))))
		if String(level.get("difficulty", "")) == "easy":
			assert(solution_ratio >= 0.75, "easy level has too few safe orders: %s" % level.get("id", ""))
		elif String(level.get("difficulty", "")) == "hard":
			assert(solution_ratio <= 0.4, "hard level has too many safe orders: %s" % level.get("id", ""))
		if number >= 11:
			var opening := PuzzleSimulation.new()
			opening.load_level(level)
			assert(opening.release_tray("t1").get("ok", false))
			var available := 0
			for tray_id in opening.tray_order:
				if opening.can_release(String(tray_id)):
					available += 1
			assert(available >= 2, "advanced level has forced linear tray order: %s" % level.get("id", ""))
	for count in mechanic_counts.values():
		assert(count > 0)
	print("Levels 1-30 validated with mystery, lock, crate, and ice")
	quit(0)
