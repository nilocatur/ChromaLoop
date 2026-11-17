class_name TrayModel
extends RefCounted

const MarbleToken = preload("res://scripts/core/MarbleToken.gd")

# §21.1 — Tray: ordered list of tokens, consumed flag, revealed state, unlock predicates.
var id: String
var grid_x: int = 0
var grid_y: int = 0
var type: String = "standard"
var marbles: Array = []        # Array[MarbleToken]
var consumed: bool = false
var revealed: bool = true      # false for mystery/hidden trays
var unlock_predicates: Array = []  # list of condition strings
var blocked: bool = false

func _init(tray_id: String = "") -> void:
	id = tray_id

func setup(tray_id: String, x: int, y: int, color_ids: Array, tray_type: String = "standard") -> void:
	id = tray_id
	grid_x = x
	grid_y = y
	type = tray_type
	marbles = []
	for i in range(color_ids.size()):
		var token = MarbleToken.new()
		token._init(tray_id + "_m" + str(i), color_ids[i], tray_id)
		marbles.push_back(token)
	consumed = false
	revealed = true
	blocked = false
	unlock_predicates = []

func configure_mechanic(data: Dictionary) -> void:
	unlock_predicates = (data.get("unlock_after", []) as Array).duplicate()
	if ["mystery", "locked", "crate", "ice"].has(type):
		blocked = unlock_predicates.size() > 0
		revealed = type != "mystery" or not blocked

func try_unlock(consumed_ids: Dictionary) -> bool:
	if not blocked:
		return false
	for prerequisite in unlock_predicates:
		if not consumed_ids.has(prerequisite):
			return false
	blocked = false
	revealed = true
	return true

func remaining_count() -> int:
	var count := 0
	for token in marbles:
		if token.state != MarbleToken.STATE_CLEARED and token.state != MarbleToken.STATE_RECEIVER:
			count += 1
	return count

func is_consumed() -> bool:
	return consumed

func mark_consumed() -> void:
	consumed = true

func is_revealed() -> bool:
	return revealed

func is_accessible() -> bool:
	return revealed and not blocked

func reveal() -> void:
	revealed = true

func to_dict() -> Dictionary:
	var d = {
		"id": id,
		"grid_x": grid_x,
		"grid_y": grid_y,
		"type": type,
		"consumed": consumed,
		"revealed": revealed,
		"blocked": blocked,
		"unlock_after": unlock_predicates.duplicate(),
	}
	var marbles_arr = []
	for t in marbles:
		marbles_arr.push_back(t.to_dict())
	d["marbles"] = marbles_arr
	return d
