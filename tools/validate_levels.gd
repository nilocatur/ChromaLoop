@tool
extends EditorScript

const LevelValidator = preload("res://scripts/data/LevelValidator.gd")

func _run() -> void:
	var validator = LevelValidator.new()
	var failures := 0
	for number in range(1, 31):
		var path := "res://data/levels/level_%03d.json" % number
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("Missing " + path)
			failures += 1
			continue
		var level: Dictionary = JSON.parse_string(file.get_as_text()) as Dictionary
		var errors: Array = validator.validate(level)
		var solved: Dictionary = validator.solve(level)
		if errors.size() > 0 or solved.get("classification", "") != "solvable":
			push_error("%s: %s / %s" % [path, errors, solved])
			failures += 1
	print("ChromaLoop level validation: %d failures" % failures)
