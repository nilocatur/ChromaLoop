class_name ReceiverLaneModel
extends RefCounted

# §21.1 — ReceiverLane: FIFO queue of receiver records, capacity 3 each, front exposed.
var lane_index: int = 0
var queue: Array = []  # each: {id, color, capacity, current_count, locked}

var current_receiver: Dictionary = {}

func _init(index: int = 0) -> void:
	lane_index = index

func setup(index: int, receivers: Array) -> void:
	lane_index = index
	queue = []
	for source in receivers:
		var receiver: Dictionary = source.duplicate(true)
		receiver["capacity"] = receiver.get("capacity", 3) as int
		receiver["current_count"] = receiver.get("current_count", 0) as int
		receiver["locked"] = receiver.get("locked", false) as bool
		queue.push_back(receiver)
	current_receiver = {}
	if queue.size() > 0:
		current_receiver = queue[0].duplicate(true)

func front() -> Dictionary:
	return current_receiver.duplicate()

func pop_current() -> void:
	# §4.2 — when a box reaches capacity, mark complete and promote next in lane
	if queue.size() > 0:
		queue.remove_at(0)
	if queue.size() > 0:
		current_receiver = queue[0].duplicate(true)
	else:
		current_receiver = {}

func fill_current(amount: int) -> int:
	if current_receiver.size() == 0:
		return 0
	var capacity: int = current_receiver.get("capacity", 3) as int
	var count: int = current_receiver.get("current_count", 0) as int
	var space: int = capacity - count
	var added: int = clampi(amount, 0, space)
	current_receiver["current_count"] = count + added
	# queue[0] and current_receiver describe the same receiver. Keep both copies
	# synchronized so save/restore and Reorder cannot reset a partial fill.
	if not queue.is_empty():
		queue[0] = current_receiver.duplicate(true)
	return added

func is_current_complete() -> bool:
	if current_receiver.size() == 0:
		return false
	return current_receiver["current_count"] >= current_receiver["capacity"]

func current_color() -> String:
	if current_receiver.size() == 0:
		return ""
	return current_receiver.get("color", "")

func current_id() -> String:
	if current_receiver.size() == 0:
		return ""
	return current_receiver.get("id", "")

func remaining_receivers_count() -> int:
	return queue.size()

func has_color_open(color: String) -> bool:
	if current_receiver.size() == 0:
		return false
	if current_receiver.get("color", "") != color:
		return false
	return current_receiver["current_count"] < current_receiver["capacity"]

func is_empty() -> bool:
	return queue.size() == 0 and current_receiver.size() == 0

func to_dict() -> Dictionary:
	return {
		"lane_index": lane_index,
		"current_receiver": current_receiver.duplicate(true),
		"queue": queue.duplicate(true)
	}

func restore_from_dict(data: Dictionary) -> void:
	lane_index = data.get("lane_index", 0) as int
	queue = (data.get("queue", []) as Array).duplicate(true)
	current_receiver = (data.get("current_receiver", {}) as Dictionary).duplicate(true)
