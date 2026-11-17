extends SceneTree

const LevelValidator = preload("res://scripts/data/LevelValidator.gd")
const PuzzleSimulation = preload("res://scripts/core/PuzzleSimulation.gd")

func _initialize() -> void:
	var validator = LevelValidator.new()
	var signatures: Dictionary = {}
	for number in range(1, 11):
		var path = "res://data/levels/level_%03d.json" % number
		var file = FileAccess.open(path, FileAccess.READ)
		assert(file != null)
		var level: Dictionary = JSON.parse_string(file.get_as_text()) as Dictionary
		file.close()
		var errors: Array = validator.validate(level)
		assert(errors.size() == 0, str(errors))
		var signature = JSON.stringify([level.get("trays", []), level.get("lanes", [])])
		assert(not signatures.has(signature), "duplicate level layout")
		signatures[signature] = true
		var solved: Dictionary = validator.solve(level)
		assert(solved.get("classification", "") == "solvable")
		var simulation = PuzzleSimulation.new()
		simulation.load_level(level)
		for tray_id in level.get("validation", {}).get("expected_trace", []):
			simulation.release_tray(tray_id)
		assert(simulation.get_status() == "won")
		print("level_%03d: %s, states=%d" % [number, solved.get("classification", ""), solved.get("states_explored", 0)])
	print("Levels 1-10 validated")
	quit(0)
