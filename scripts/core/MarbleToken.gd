class_name MarbleToken
extends RefCounted

# §21.1 Entity records — MarbleToken states
const STATE_TRAY = "TRAY"
const STATE_IN_FLIGHT = "IN_FLIGHT"
const STATE_BELT = "BELT"
const STATE_RECEIVER = "RECEIVER"
const STATE_CLEARED = "CLEARED"

var id: String
var color_id: String
var source_tray_id: String
var state: String = STATE_TRAY
var belt_slot: int = -1
var receiver_id: String = ""
var special_flags: Dictionary = {}

func _init(token_id: String = "", color: String = "", tray_id: String = "") -> void:
	id = token_id
	color_id = color
	source_tray_id = tray_id

func to_dict() -> Dictionary:
	return {
		"id": id,
		"color_id": color_id,
		"source_tray_id": source_tray_id,
		"state": state,
		"belt_slot": belt_slot,
		"receiver_id": receiver_id,
		"special_flags": special_flags.duplicate(true)
	}

func from_dict(d: Dictionary) -> void:
	id = d.get("id", "")
	color_id = d.get("color_id", "")
	source_tray_id = d.get("source_tray_id", "")
	state = d.get("state", STATE_TRAY)
	belt_slot = d.get("belt_slot", -1)
	receiver_id = d.get("receiver_id", "")
	special_flags = d.get("special_flags", {})
