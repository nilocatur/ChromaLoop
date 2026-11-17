class_name PuzzleSimulation
extends RefCounted

const BeltModel = preload("res://scripts/core/BeltModel.gd")
const MarbleToken = preload("res://scripts/core/MarbleToken.gd")
const TrayModel = preload("res://scripts/core/TrayModel.gd")
const ReceiverLaneModel = preload("res://scripts/core/ReceiverLaneModel.gd")

# §21.2 Atomic action pipeline — deterministic, no Node/Tween/Audio references.
# Emits signals for the view layer to animate; outcomes never depend on animation timing.

signal marble_released(token_id: String, color_id: String)
signal marble_absorbed(token_id: String, receiver_id: String, lane_index: int)
signal receiver_completed(receiver_id: String, lane_index: int)
signal belt_warning(occupancy: int)
signal simulation_finished(result: String)
signal booster_used(booster_id: String)

var status: String = "playing"  # playing / won / jammed / no_moves
var belt_capacity: int = 22
var lane_count: int = 4
var tray_marble_count: int = 9
var moves_limit: Variant = null
var moves_remaining: int = 0
var seed: int = 0
var rules_version: int = 1

var trays: Dictionary = {}          # id -> TrayModel
var tray_order: Array = []          # stable tap order
var lanes: Array = []               # Array[ReceiverLaneModel]
var belt = BeltModel.new()
var tokens: Dictionary = {}         # token_id -> MarbleToken

var committed_action_count: int = 0
var last_state_checksum: String = ""
var allowed_boosters: Array = []
var rescued_token_ids: Array = []

var event_stream: Array = []        # time-ordered visual events from last action

func load_level(level_data: Dictionary) -> void:
	# §9 schema validation (light) + initialization
	status = "playing"
	committed_action_count = 0
	last_state_checksum = ""
	event_stream = []

	belt_capacity = level_data.get("belt_capacity", 22)
	lane_count = level_data.get("lane_count", 4)
	tray_marble_count = level_data.get("tray_marble_count", 9)
	moves_limit = level_data.get("moves_limit", null)
	moves_remaining = moves_limit if moves_limit != null else -1
	seed = level_data.get("seed", 0)
	rules_version = level_data.get("rules_version", 1)
	allowed_boosters = (level_data.get("allowed_boosters", []) as Array).duplicate()
	rescued_token_ids = []

	belt.setup(belt_capacity)
	trays = {}
	tray_order = []
	lanes = []
	tokens = {}

	var trays_data = level_data.get("trays", [])
	for t in trays_data:
		var tray = TrayModel.new()
		tray.setup(t.get("id", ""), t.get("grid_x", 0), t.get("grid_y", 0),
		           t.get("marbles", []), t.get("type", "standard"))
		tray.configure_mechanic(t)
		trays[tray.id] = tray
		tray_order.push_back(tray.id)

	var lanes_data = level_data.get("lanes", [])
	for i in range(lane_count):
		var lane = ReceiverLaneModel.new()
		var receivers = []
		if i < lanes_data.size():
			receivers = lanes_data[i]
		lane.setup(i, receivers)
		lanes.push_back(lane)

	# index tokens by id
	for tray_id in tray_order:
		var tray = trays[tray_id]
		for token in tray.marbles:
			tokens[token.id] = token

func can_release(tray_id: String) -> bool:
	if status != "playing":
		return false
	var tray = trays.get(tray_id)
	if tray == null:
		return false
	if tray.is_consumed():
		return false
	if not tray.is_accessible():
		return false
	if moves_limit != null and moves_remaining <= 0:
		return false
	return true

# authoritatively restore complete logical simulation state
func restore_from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	belt_capacity = int(data.get("belt_capacity", belt_capacity))
	lane_count = int(data.get("lane_count", lane_count))
	tray_marble_count = int(data.get("tray_marble_count", tray_marble_count))
	moves_limit = data.get("moves_limit", null)
	moves_remaining = int(data.get("moves_remaining", moves_remaining))
	seed = int(data.get("seed", seed))
	rules_version = int(data.get("rules_version", rules_version))
	status = String(data.get("status", status))
	committed_action_count = int(data.get("committed_action_count", committed_action_count))
	last_state_checksum = String(data.get("last_state_checksum", ""))
	allowed_boosters = (data.get("allowed_boosters", []) as Array).duplicate()
	rescued_token_ids = (data.get("rescued_token_ids", []) as Array).duplicate()

	belt.setup(belt_capacity)
	var saved_belt: Array = data.get("belt", []) as Array
	for i in range(mini(saved_belt.size(), belt_capacity)):
		var slot_token = saved_belt[i]
		belt.slots[i] = slot_token if slot_token != null else null

	trays = {}
	tray_order = []
	tokens = {}
	var tray_states: Array = data.get("trays", []) as Array
	for state_var in tray_states:
		var tray_state: Dictionary = state_var as Dictionary
		var tray_id := String(tray_state.get("id", ""))
		var saved_tokens: Array = tray_state.get("marbles", []) as Array
		var token_colors: Array = []
		for token_state in saved_tokens:
			token_colors.push_back(String((token_state as Dictionary).get("color_id", "")))
		var tray := TrayModel.new()
		tray.setup(tray_id,
			int(tray_state.get("grid_x", 0)),
			int(tray_state.get("grid_y", 0)),
			token_colors,
			String(tray_state.get("type", "standard")))
		tray.consumed = bool(tray_state.get("consumed", false))
		tray.revealed = bool(tray_state.get("revealed", true))
		tray.blocked = bool(tray_state.get("blocked", false))
		tray.unlock_predicates = (tray_state.get("unlock_after", []) as Array).duplicate()
		for token_state in saved_tokens:
			var token_state_dict: Dictionary = token_state as Dictionary
			var token: MarbleToken = null
			for candidate in tray.marbles:
				if String(candidate.id) == String(token_state_dict.get("id", "")):
					token = candidate
					break
			if token != null:
				token.from_dict(token_state_dict)
				tokens[token.id] = token
		trays[tray_id] = tray
		tray_order.push_back(tray_id)

	lanes = []
	var saved_lanes: Array = data.get("lanes", []) as Array
	for i in range(lane_count):
		var lane := ReceiverLaneModel.new()
		lane.setup(i, [])
		if i < saved_lanes.size():
			lane.restore_from_dict(saved_lanes[i] as Dictionary)
		lanes.push_back(lane)

# §21.2 — pre-simulate whole release; if overflow after all cascades, fail atomically (no half commit).
func release_tray(tray_id: String, check_future_actions: bool = true) -> Dictionary:
	if not can_release(tray_id):
		return {"ok": false, "reason": "not_accessible"}

	var tray = trays[tray_id]
	event_stream = []

	# snapshot for atomic rollback on jam
	var snapshot = _snapshot()

	# deduct move
	if moves_limit != null and moves_remaining > 0:
		moves_remaining -= 1

	tray.mark_consumed()

	# materialize 9 tokens in deterministic order (§21.2 step 3)
	var tokens_to_place: Array = []
	for token in tray.marbles:
		if token.state == MarbleToken.STATE_CLEARED:
			continue
		token.state = MarbleToken.STATE_IN_FLIGHT
		event_stream.push_back({
			"type": "marble_released", "token_id": token.id,
			"color_id": token.color_id, "source_tray_id": tray_id
		})
		tokens_to_place.push_back(token)

	# Process each token. Tokens that cannot fit are retried after cascades.
	var pending_overflow: Array = []
	for token in tokens_to_place:
		if not _place_token(token):
			pending_overflow.push_back(token)

	# run cascades until no progress (§21.2 step 5)
	var safety_cap = 1000
	var iterations = 0
	while _run_cascade_pass() and iterations < safety_cap:
		iterations += 1

	# A later token may promote a receiver and free belt space for an earlier overflow.
	var retry_progress = true
	while pending_overflow.size() > 0 and retry_progress and iterations < safety_cap:
		retry_progress = false
		var still_pending: Array = []
		for token in pending_overflow:
			if _place_token(token):
				retry_progress = true
			else:
				still_pending.push_back(token)
		pending_overflow = still_pending
		while _run_cascade_pass() and iterations < safety_cap:
			retry_progress = true
			iterations += 1
		iterations += 1

	# §21.2: release and cascades resolve before obstacle/unlock triggers.
	_resolve_tray_mechanics()

	# Overflow rolls back atomically. A legal release that exactly fills the belt
	# is different: commit that board, then fail because no action can progress.
	var overflowed := pending_overflow.size() > 0
	var result = "jammed" if overflowed else _check_result(check_future_actions)
	status = result

	committed_action_count += 1
	last_state_checksum = _compute_checksum()

	event_stream.push_back({"type": "action_committed", "result": result})

	if overflowed:
		# Roll back every logical mutation. Preserve only terminal result/action index.
		_restore(snapshot)
		status = "jammed"
		committed_action_count = (snapshot.get("committed_action_count", 0) as int) + 1
		last_state_checksum = _compute_checksum()
		# Do not animate mutations that were rolled back.
		event_stream = [{"type": "action_committed", "result": "jammed"}]
		if pending_overflow.size() > 0:
			event_stream.push_back({"type": "release_overflow", "count": pending_overflow.size()})
		event_stream.push_back({"type": "level_failed", "reason": "jam"})
	elif result == "jammed":
		event_stream.push_back({"type": "level_failed", "reason": "jam"})

	simulation_finished.emit(result)
	return {
		"ok": true, "result": result, "overflowed": overflowed,
		"events": event_stream.duplicate()
	}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Boosters (§4.5) — deterministic, event-emitting simulation-level APIs
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func can_use_booster(booster_id: String, target_id: String = "") -> Dictionary:
	if status != "playing":
		return {"ok": false, "reason": "not_playing"}
	if not allowed_boosters.has(booster_id):
		return {"ok": false, "reason": "not_allowed"}
	if booster_id == "sweep":
		if belt.count_used() == 0:
			return {"ok": false, "reason": "no_target"}
		return {"ok": true, "reason": ""}
	if booster_id == "picker":
		if target_id == "" or not trays.has(target_id):
			return {"ok": false, "reason": "no_target"}
		var tray = trays[target_id]
		if tray.is_consumed() or tray.is_accessible():
			return {"ok": false, "reason": "invalid_target"}
		return {"ok": true, "reason": ""}
	if booster_id == "reorder":
		var reorderable := 0
		for lane in lanes:
			if lane.queue.size() > 1:
				reorderable += 1
		if reorderable == 0:
			return {"ok": false, "reason": "no_target"}
		return {"ok": true, "reason": ""}
	return {"ok": false, "reason": "unknown_booster"}

func apply_booster(booster_id: String, target_id: String = "") -> Dictionary:
	var usable := can_use_booster(booster_id, target_id)
	if not usable.get("ok", false):
		return {"ok": false, "reason": usable.get("reason", "invalid"), "events": []}

	event_stream = []
	if booster_id == "sweep":
		_apply_sweep()
	elif booster_id == "picker":
		_apply_picker(target_id)
	elif booster_id == "reorder":
		_apply_reorder()

	status = _check_result()
	committed_action_count += 1
	last_state_checksum = _compute_checksum()
	event_stream.push_back({"type": "action_committed", "result": status})
	booster_used.emit(booster_id)
	return {"ok": true, "reason": "", "events": event_stream.duplicate()}

func _apply_sweep() -> void:
	event_stream.push_back({"type": "booster_applied", "booster": "sweep"})
	for i in range(belt.capacity):
		var token_id = belt.slots[i]
		if token_id == null:
			continue
		var token = tokens.get(token_id)
		if token == null:
			continue
		belt.remove(i)
		token.state = MarbleToken.STATE_CLEARED
		token.belt_slot = -1
		rescued_token_ids.push_back(token.id)
		event_stream.push_back({"type": "marble_rescued", "token_id": token.id, "color_id": token.color_id, "slot": i})
	status = _check_result()

func _apply_picker(target_id: String) -> void:
	var tray = trays[target_id]
	tray.blocked = false
	tray.revealed = true
	var event_type := "tray_unlocked"
	if tray.type == "mystery":
		event_type = "tray_revealed"
	elif tray.type == "crate" or tray.type == "ice":
		event_type = "obstacle_cleared"
	event_stream.push_back({"type": "booster_applied", "booster": "picker"})
	event_stream.push_back({"type": event_type, "tray_id": target_id, "mechanic": tray.type})

func _apply_reorder() -> void:
	event_stream.push_back({"type": "booster_applied", "booster": "reorder"})
	for lane in lanes:
		if lane.queue.size() <= 1:
			continue
		var front: Dictionary = lane.current_receiver.duplicate(true)
		var rest: Array = lane.queue.slice(1)
		rest.sort_custom(func(a, b): return _receiver_sort_key(a) < _receiver_sort_key(b))
		lane.queue = [front]
		lane.queue.append_array(rest)
		event_stream.push_back({"type": "receivers_reordered", "lane_index": lane.lane_index, "queue": lane.queue.duplicate(true)})

func _receiver_sort_key(receiver: Dictionary) -> String:
	return "%s:%s" % [String(receiver.get("color", "")), String(receiver.get("id", ""))]

func _resolve_tray_mechanics() -> void:
	var consumed_ids: Dictionary = {}
	for tray_id in tray_order:
		if trays[tray_id].is_consumed():
			consumed_ids[tray_id] = true
	for tray_id in tray_order:
		var candidate = trays[tray_id]
		if not candidate.try_unlock(consumed_ids):
			continue
		var event_type := "tray_unlocked"
		if candidate.type == "mystery":
			event_type = "tray_revealed"
		elif candidate.type == "crate" or candidate.type == "ice":
			event_type = "obstacle_cleared"
		event_stream.push_back({"type": event_type, "tray_id": tray_id, "mechanic": candidate.type})

func _place_token(token: MarbleToken) -> bool:
	# find eligible ACTIVE receiver with room, lowest lane_index (§21.3 rule 3)
	var target_lane = -1
	var target_color = token.color_id
	for i in range(lane_count):
		var lane = lanes[i]
		if lane.has_color_open(target_color):
			target_lane = i
			break

	if target_lane >= 0:
		var lane = lanes[target_lane]
		var receiver_id: String = lane.current_id()
		var receiver_color: String = lane.current_color()
		var capacity := int(lane.current_receiver.get("capacity", 3))
		lane.fill_current(1)
		token.state = MarbleToken.STATE_RECEIVER
		token.receiver_id = receiver_id
		event_stream.push_back({
			"type": "marble_absorbed", "token_id": token.id,
			"receiver_id": receiver_id, "lane_index": target_lane,
			"receiver_color": receiver_color,
			"fill_count": int(lane.current_receiver.get("current_count", 0)),
			"capacity": capacity
		})

		if lane.is_current_complete():
			var completed_id: String = lane.current_id()
			lane.pop_current()
			event_stream.push_back({
				"type": "receiver_completed", "receiver_id": completed_id,
				"lane_index": target_lane, "next_receiver": lane.front()
			})
			# §21.3: older belt tokens get first chance at a newly promoted
			# receiver before later tokens from this tray are processed.
			_drain_belt_to_stability()
		return true
	else:
		# place on belt in lowest free slot
		var free = belt.free_slots()
		if free.size() > 0:
			var slot = free[0]
			belt.place(token.id, slot)
			token.state = MarbleToken.STATE_BELT
			token.belt_slot = slot
			event_stream.push_back({"type": "marble_to_belt", "token_id": token.id, "slot": slot})
			return true
	return false

func _run_cascade_pass() -> bool:
	var progress = false
	# drain belt tokens in ascending logical slot order (§21.3 rule 5)
	for i in range(belt.capacity):
		var token_id = belt.slots[i]
		if token_id == null:
			continue
		var token = tokens.get(token_id)
		if token == null:
			continue
		if token.state != MarbleToken.STATE_BELT:
			continue

		var target_lane = -1
		for j in range(lane_count):
			var lane = lanes[j]
			if lane.has_color_open(token.color_id):
				target_lane = j
				break

		if target_lane >= 0:
			var lane = lanes[target_lane]
			var receiver_id: String = lane.current_id()
			var receiver_color: String = lane.current_color()
			var capacity := int(lane.current_receiver.get("capacity", 3))
			lane.fill_current(1)
			belt.remove(i)
			token.state = MarbleToken.STATE_RECEIVER
			token.receiver_id = receiver_id
			token.belt_slot = -1
			event_stream.push_back({
				"type": "marble_absorbed", "token_id": token.id,
				"receiver_id": receiver_id, "lane_index": target_lane,
				"receiver_color": receiver_color,
				"fill_count": int(lane.current_receiver.get("current_count", 0)),
				"capacity": capacity
			})
			progress = true

			if lane.is_current_complete():
				var completed_id: String = lane.current_id()
				lane.pop_current()
				event_stream.push_back({
					"type": "receiver_completed", "receiver_id": completed_id,
					"lane_index": target_lane, "next_receiver": lane.front()
				})

	return progress

func _drain_belt_to_stability() -> void:
	var passes := 0
	while passes < 1000 and _run_cascade_pass():
		passes += 1

func _check_result(check_future_actions: bool = true) -> String:
	# win: all trays consumed/revealed, all lanes empty, belt empty, no unresolved obstacle (§4.3)
	var all_trays_done = true
	for tray_id in tray_order:
		var tray = trays[tray_id]
		if not tray.is_consumed():
			all_trays_done = false
			break
		for token in tray.marbles:
			if token.state != MarbleToken.STATE_CLEARED and token.state != MarbleToken.STATE_RECEIVER:
				all_trays_done = false
				break
		if not all_trays_done:
			break

	var all_lanes_empty = true
	for lane in lanes:
		if not lane.is_empty():
			all_lanes_empty = false
			break

	var belt_empty = belt.count_used() == 0

	if all_trays_done and all_lanes_empty and belt_empty:
		return "won"

	# move failure (§4.3)
	if moves_limit != null and moves_remaining <= 0:
		return "no_moves"

	# jam failure: belt full after cascades, no progressing legal action (§4.3)
	if belt.is_full():
		# check if any belt marble can still be absorbed
		var can_progress = false
		for i in range(belt.capacity):
			var token_id = belt.slots[i]
			if token_id == null:
				continue
			var token = tokens.get(token_id)
			if token == null:
				continue
			for j in range(lane_count):
				if lanes[j].has_color_open(token.color_id):
					can_progress = true
					break
			if can_progress:
				break
		if not can_progress and check_future_actions:
			can_progress = _has_progressing_tray_action()
		if not can_progress:
			return "jammed"

	return "playing"

func _has_progressing_tray_action() -> bool:
	# A full belt is not an immediate jam when an accessible tray can release
	# into receivers and a finite sequence of later trays can make real progress.
	return _can_reach_progress(to_dict(), belt.count_used(), _remaining_receiver_count())

func _can_reach_progress(state: Dictionary, starting_belt_used: int,
		starting_receiver_count: int) -> bool:
	var current := PuzzleSimulation.new()
	current.restore_from_dict(state)
	for tray_id in tray_order:
		if not current.can_release(String(tray_id)):
			continue
		var probe := PuzzleSimulation.new()
		probe.restore_from_dict(current.to_dict())
		var result: Dictionary = probe.release_tray(String(tray_id), false)
		if result.get("ok", false) and not result.get("overflowed", true):
			if probe.get_status() == "won" \
					or probe.belt.count_used() < starting_belt_used \
					or probe._remaining_receiver_count() < starting_receiver_count:
				return true
			if probe.get_status() != "no_moves":
				# release_tray(..., false) reports a provisional full-belt jam.
				# Continue only inside this bounded lookahead; each branch consumes a tray.
				probe.status = "playing"
				if _can_reach_progress(probe.to_dict(), starting_belt_used, starting_receiver_count):
					return true
	return false

func _remaining_receiver_count() -> int:
	var count := 0
	for lane in lanes:
		count += lane.remaining_receivers_count()
	return count

func _snapshot() -> Dictionary:
	# deep copy of full state for atomic rollback
	var state = {}
	state["trays"] = {}
	for key in trays.keys():
		state["trays"][key] = trays[key].to_dict()
	state["lanes"] = []
	for lane in lanes:
		state["lanes"].push_back(lane.to_dict())
	state["belt"] = belt.slots.duplicate()
	state["status"] = status
	state["moves_remaining"] = moves_remaining
	state["committed_action_count"] = committed_action_count
	state["last_state_checksum"] = last_state_checksum
	return state

func _restore(state: Dictionary) -> void:
	var tray_state: Dictionary = state.get("trays", {}) as Dictionary
	for tray_id in tray_state.keys():
		var tray = trays.get(tray_id)
		if tray == null:
			continue
		var saved_tray: Dictionary = tray_state[tray_id] as Dictionary
		tray.consumed = saved_tray.get("consumed", false) as bool
		tray.revealed = saved_tray.get("revealed", true) as bool
		tray.blocked = saved_tray.get("blocked", false) as bool
		tray.unlock_predicates = (saved_tray.get("unlock_after", []) as Array).duplicate()
		var saved_tokens: Array = saved_tray.get("marbles", []) as Array
		for saved_token in saved_tokens:
			var token_id: String = saved_token.get("id", "") as String
			var token = tokens.get(token_id)
			if token != null:
				token.from_dict(saved_token)
	var saved_lanes: Array = state.get("lanes", []) as Array
	for i in range(mini(lanes.size(), saved_lanes.size())):
		lanes[i].restore_from_dict(saved_lanes[i] as Dictionary)
	belt.slots = (state.get("belt", []) as Array).duplicate()
	status = state.get("status", "playing") as String
	moves_remaining = state.get("moves_remaining", -1) as int
	committed_action_count = state.get("committed_action_count", 0) as int
	last_state_checksum = state.get("last_state_checksum", "") as String

func _compute_checksum() -> String:
	var parts: Array = []
	parts.push_back(str(status))
	parts.push_back(str(moves_remaining))
	parts.push_back(str(committed_action_count))
	for i in range(belt.capacity):
		var slot_text = "." if belt.slots[i] == null else str(belt.slots[i])
		parts.push_back(slot_text)
	for lane in lanes:
		parts.push_back(str(lane.current_receiver))
		parts.push_back(str(lane.queue))
	for tray_id in tray_order:
		var tray = trays[tray_id]
		parts.push_back("%s:%s:%s:%s:%s" % [tray_id, tray.consumed, tray.blocked, tray.revealed, tray.unlock_predicates])
		for token in tray.marbles:
			parts.push_back("%s:%s:%s:%s" % [token.id, token.state, token.belt_slot, token.receiver_id])
	var joined: String = parts[0]
	for i in range(1, parts.size()):
		joined += "|" + str(parts[i])
	return "sim:" + str(hash(joined))

func get_status() -> String:
	return status

func get_event_stream() -> Array:
	return event_stream.duplicate()

# placeholder to_dict / to_dict on models for snapshot compatibility
func to_dict() -> Dictionary:
	var tray_states: Array = []
	for tray_id in tray_order:
		tray_states.push_back((trays[tray_id] as TrayModel).to_dict())
	var lane_states: Array = []
	for lane in lanes:
		lane_states.push_back(lane.to_dict())
	return {
		"schema": SAVE_SCHEMA,
		"rules_version": rules_version,
		"seed": seed,
		"belt_capacity": belt_capacity,
		"lane_count": lane_count,
		"tray_marble_count": tray_marble_count,
		"moves_limit": moves_limit,
		"moves_remaining": moves_remaining,
		"status": status,
		"committed_action_count": committed_action_count,
		"last_state_checksum": last_state_checksum,
		"allowed_boosters": allowed_boosters.duplicate(),
		"rescued_token_ids": rescued_token_ids.duplicate(),
		"belt": belt.slots.duplicate(true),
		"trays": tray_states,
		"lanes": lane_states
	}

const SAVE_SCHEMA := 1

func _to_dict_tray(tray: TrayModel) -> Dictionary:
	var d = {
		"id": tray.id,
		"consumed": tray.consumed,
		"revealed": tray.revealed,
	}
	var marbles_arr = []
	for t in tray.marbles:
		marbles_arr.push_back(t.to_dict())
	d["marbles"] = marbles_arr
	return d

func _to_dict_lane(lane: ReceiverLaneModel) -> Dictionary:
	return {
		"lane_index": lane.lane_index,
		"current": lane.current_receiver,
		"queue": lane.queue
	}
