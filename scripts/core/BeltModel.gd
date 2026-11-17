class_name BeltModel
extends RefCounted

# §21.1 — Belt: ordered array length belt_capacity, null or marble ID. At most 1 token per slot.
var capacity: int = 22
var slots: Array = []  # Array[String] marble IDs or null

func setup(slot_count: int) -> void:
	capacity = slot_count
	slots.resize(capacity)
	slots.fill(null)

func is_full() -> bool:
	for token_id in slots:
		if token_id == null:
			return false
	return true

func count_used() -> int:
	var total := 0
	for token_id in slots:
		if token_id != null:
			total += 1
	return total

func free_slots() -> Array:
	var result := []
	for i in range(capacity):
		if slots[i] == null:
			result.push_back(i)
	return result

func place(token_id: String, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= capacity:
		return false
	if slots[slot_index] != null:
		return false
	slots[slot_index] = token_id
	return true

func remove(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= capacity:
		return ""
	var token_id = slots[slot_index]
	slots[slot_index] = null
	return token_id
