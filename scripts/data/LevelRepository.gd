class_name LevelRepository
extends Node

# §22 — loads level JSONs from data/levels/
var levels: Dictionary = {}

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	var dir := DirAccess.open("res://data/levels/")
	if dir == null:
		push_error("LevelRepository: cannot open res://data/levels/")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var path := "res://data/levels/" + file_name
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				var data := JSON.parse_string(f.get_as_text()) as Dictionary
				f.close()
				if data != null and data.has("id"):
					levels[data["id"]] = data
		file_name = dir.get_next()
	dir.list_dir_end()

func get_level(level_id: String) -> Dictionary:
	return levels.get(level_id, {}) as Dictionary

func get_level_by_number(number: int) -> Dictionary:
	for key in levels.keys():
		if levels[key].get("number", 0) as int == number:
			return levels[key] as Dictionary
	return {}

func get_all_level_ids() -> Array:
	return levels.keys()

func level_exists(level_id: String) -> bool:
	return levels.has(level_id)
