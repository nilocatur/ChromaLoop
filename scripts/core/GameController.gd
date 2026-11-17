extends Node

# §8.4 / §20.4 — orchestrates simulation + view + modals.
# Restart/retry costs exactly 1 heart via PlayerProgress (atomic, idempotent, §4.3 / §21.4).
signal level_won(level_id: String)
signal level_failed(level_id: String, reason: String)
signal state_committed(result: String)
signal tray_tapped(tray_id: String)

const RET_OK := 0
const RET_NO_HEARTS := 1
const RET_OP_DUPLICATE := 2
const RET_ERROR := 3

const LANE_SPACING := 110.0
const TRAY_SPACING := 130.0
const TRAY_VARIANT_BY_COLOR := {
	"red": "pink", "blue": "blue", "green": "green", "yellow": "yellow",
	"purple": "purple", "orange": "beige", "pink": "pink", "cyan": "blue",
	"navy": "purple", "lime": "green", "silver": "beige", "brown": "beige",
	"rainbow": "purple", "black": "purple", "diamond": "blue", "": "beige"
}
const MECHANIC_ICONS := {
	"mystery": "mystery_box", "locked": "lock_gold",
	"crate": "wooden_crate", "ice": "ice_block"
}
const BOOSTER_ICONS := {
	"sweep": ["actions", "fast_forward"],
	"picker": ["portals_boosters", "magnet"],
	"reorder": ["actions", "shuffle"]
}

var simulation
var tray_container
var conveyor_view
var receiver_container
var overlay
var asset_catalog
var scene_router
var level_repo
var player_progress
var audio_director

var modal_dialog

var current_level_id: String = ""
var current_level_data: Dictionary = {}
var tray_tiles: Dictionary = {}
var marble_sprites: Dictionary = {}
var belt_visual_tokens: Dictionary = {}
var receiver_views: Dictionary = {}

var _input_locked: bool = false
var _modal_handler: Callable = Callable()
var _modal_visible: bool = false
var _tutorial_hint: Label
var _tutorial_root: Control
var _tray_reveal_textures: Dictionary = {}
var _restart_op_id: int = 0
var _restart_pending: bool = false
var _restarts_this_level: int = 0
var _modal_generation: int = 0
var booster_buttons: Dictionary = {}

func _ready() -> void:
	var ac = get_node_or_null("/root/AssetCatalog")
	asset_catalog = ac if ac != null else null
	var pr = get_node_or_null("/root/PlayerProgress")
	player_progress = pr if pr != null else null
	var lr = get_node_or_null("/root/LevelRepository")
	level_repo = lr if lr != null else null
	var sr = get_node_or_null("/root/SceneRouter")
	scene_router = sr if sr != null else null
	audio_director = get_node_or_null("/root/AudioDirector")

	var sim_scr = load("res://scripts/core/PuzzleSimulation.gd")
	simulation = sim_scr.new()

	tray_container = get_node_or_null("World/Trays")
	conveyor_view = get_node_or_null("World/Conveyor")
	if conveyor_view != null:
		conveyor_view.set_capacity(simulation.belt_capacity)
	receiver_container = get_node_or_null("World/ReceiverLanes")
	overlay = get_node_or_null("UI/OverlayLayer")

	level_won.connect(self._on_level_won)
	level_failed.connect(self._on_level_failed)

	# build reusable modal (single result connection, dispatched to current handler)
	var modal_sc = load("res://scenes/ui/ModalDialog.tscn")
	modal_dialog = modal_sc.instantiate()
	modal_dialog.result.connect(self._on_modal_result)
	if overlay != null:
		overlay.add_child(modal_dialog)

	# load pending level (set by lobby) or default level_001
	var pending = ""
	if scene_router != null:
		pending = scene_router.pending_level_id
	var level_data = {}
	if pending != "" and level_repo != null:
		level_data = level_repo.get_level(pending)
	if level_data == null or level_data.size() == 0:
		level_data = level_repo.get_level("level_001") if level_repo != null else {}
	if level_data != null and level_data.size() > 0:
		load_level(level_data)

	_apply_scene_art()
	if player_progress != null:
		player_progress.hearts_changed.connect(self._on_hearts_changed)
		_update_hearts_label()

	if audio_director != null:
		audio_director.play_music("gameplay_music")

	# pause button
	var pause_btn = get_node_or_null("UI/SafeArea/Content/TopHUD/PauseButton")
	if pause_btn != null:
		pause_btn.pressed.connect(self.show_pause)
		pause_btn.call_deferred("grab_focus")
	var restart_btn = get_node_or_null("UI/SafeArea/Content/TopHUD/RestartButton")
	if restart_btn != null:
		restart_btn.pressed.connect(self._request_restart)
	_build_booster_bar()
	set_process(true)

func _process(_delta: float) -> void:
	if conveyor_view == null:
		return
	for token_id in belt_visual_tokens.keys():
		var marble = marble_sprites.get(token_id)
		var token = simulation.tokens.get(token_id) if simulation != null else null
		if marble == null or token == null or token.state != "BELT":
			belt_visual_tokens.erase(token_id)
			continue
		marble.position = conveyor_view.position_for_slot(token.belt_slot) if _reduced_motion() \
			else conveyor_view.moving_position_for_slot(token.belt_slot)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Art wiring (§8.1) — everything below comes from data/asset_manifest.json
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _apply_scene_art() -> void:
	if asset_catalog == null:
		return
	var pause_btn = get_node_or_null("UI/SafeArea/Content/TopHUD/PauseButton")
	if pause_btn != null:
		pause_btn.icon = asset_catalog.get_ui_icon("pause", 38)
	var restart_btn = get_node_or_null("UI/SafeArea/Content/TopHUD/RestartButton")
	if restart_btn != null:
		restart_btn.icon = asset_catalog.get_ui_icon("restart_ic", 38)
	var heart_icon = get_node_or_null("UI/SafeArea/Content/TopHUD/HeartIcon")
	if heart_icon != null:
		heart_icon.texture = asset_catalog.get_ui_texture("heart")
	var bg = get_node_or_null("Background")
	if bg != null and bg is TextureRect and (bg as TextureRect).texture == null:
		(bg as TextureRect).texture = asset_catalog.get_ui_texture("bg_gameplay")

func _on_hearts_changed(_hearts: int, _max_hearts: int) -> void:
	_update_hearts_label()

func _update_hearts_label() -> void:
	var label = get_node_or_null("UI/SafeArea/Content/TopHUD/HeartsLabel")
	if label == null:
		return
	var hearts := 0
	if player_progress != null:
		hearts = player_progress.get_hearts()
	label.text = str(hearts)

func _tray_texture_for(hint_color: String) -> Texture2D:
	if asset_catalog == null:
		return null
	var variant: String = TRAY_VARIANT_BY_COLOR.get(hint_color, "beige")
	var tex: Texture2D = asset_catalog.get_tray_texture(variant)
	if tex == null:
		tex = asset_catalog.get_tray_texture("beige")
	return tex

func load_level(level_data: Dictionary, allow_restore: bool = true, reset_restart_count: bool = true) -> void:
	current_level_data = level_data
	current_level_id = level_data.get("id", "") as String
	if reset_restart_count:
		_restarts_this_level = 0
	_clear_board()
	simulation.load_level(level_data)
	var restored_status := "playing"
	var restored_run := false
	if allow_restore and player_progress != null:
		var saved_run: Dictionary = player_progress.get_run()
		var saved_state: Variant = saved_run.get("serialized_simulation_state", null)
		if String(saved_run.get("level_id", "")) == current_level_id \
				and ["playing", "jammed", "no_moves"].has(String(saved_run.get("status", ""))) \
				and saved_state is Dictionary \
				and int((saved_state as Dictionary).get("rules_version", -1)) == simulation.rules_version:
			simulation.restore_from_dict(saved_state as Dictionary)
			restored_status = simulation.get_status()
			restored_run = true
	if conveyor_view != null:
		conveyor_view.set_capacity(simulation.belt_capacity)
	_build_trays()
	_build_receivers()
	_refresh_receiver_views()
	_sync_board_from_simulation()
	_refresh_booster_bar()
	_show_tutorial_hint(level_data)
	var level_label = get_node_or_null("UI/SafeArea/Content/TopHUD/LevelLabel")
	if level_label != null:
		level_label.text = "LEVEL " + str(int(level_data.get("number", 1)))
	var moves_label = get_node_or_null("UI/SafeArea/Content/TopHUD/MovesLabel")
	if moves_label != null:
		moves_label.text = "MOVES " + str(simulation.moves_remaining) if simulation.moves_limit != null else ""
	if scene_router != null:
		scene_router.pending_level_id = ""
	if not restored_run and simulation.get_status() == "playing":
		_persist_run_state()
	if restored_status == "jammed" or restored_status == "no_moves":
		call_deferred("_show_restored_failure", restored_status)

func _clear_board() -> void:
	for marble in marble_sprites.values():
		if marble != null and is_instance_valid(marble):
			marble.free()
	if tray_container != null:
		for child in tray_container.get_children():
			child.free()
	if receiver_container != null:
		for child in receiver_container.get_children():
			child.free()
	tray_tiles = {}
	marble_sprites = {}
	belt_visual_tokens = {}
	receiver_views = {}
	_tray_reveal_textures = {}

func _build_trays() -> void:
	var trays_data = current_level_data.get("trays", [])
	var cols := 1
	for t in trays_data:
		cols = maxi(cols, int(t.get("grid_x", 0)) + 1)
	var start_x := (540.0 - float(cols - 1) * TRAY_SPACING) * 0.5
	for t in trays_data:
		var tile_sc = load("res://scripts/view/TrayTile.gd")
		var tile = tile_sc.new()
		tile.tray_id = t.get("id", "") as String
		var color_ids = t.get("marbles", [])
		var hint_color = color_ids[0] if color_ids.size() > 0 else ""
		tile.set_color_hint(hint_color)
		# base = shipped tray art; blocked trays overlay the mechanic prop
		var tray_type: String = t.get("type", "standard") as String
		var blocked: bool = not (t.get("unlock_after", []) as Array).is_empty()
		var tray_tex: Texture2D = _tray_texture_for("" if tray_type == "mystery" and blocked else String(hint_color))
		_tray_reveal_textures[tile.tray_id] = tray_tex
		if tray_type == "mystery" and blocked:
			_tray_reveal_textures[tile.tray_id] = _tray_texture_for(String(hint_color))
		tile.set_mechanic(tray_type)
		tile.set_tray_texture(tray_tex)
		if asset_catalog != null and MECHANIC_ICONS.has(tray_type):
			tile.set_mechanic_icon(asset_catalog.get_obstacle_texture(MECHANIC_ICONS[tray_type]))
		var texture_map: Dictionary = asset_catalog.marble_map() if asset_catalog != null else {}
		tile.set_marbles(color_ids, texture_map)
		tile.set_accessible(not blocked)
		tile.position = Vector2(
			start_x + float(t.get("grid_x", 0)) * TRAY_SPACING,
			float(t.get("grid_y", 0)) * TRAY_SPACING + 120.0)
		tile.tray_tapped.connect(self.on_tray_tap)
		tray_container.add_child(tile)
		tray_tiles[tile.tray_id] = tile

func _build_receivers() -> void:
	var lanes_data = current_level_data.get("lanes", [])
	var n: int = lanes_data.size()
	var start_x := (540.0 - float(maxi(n - 1, 0)) * LANE_SPACING) * 0.5
	for i in range(n):
		var receivers = lanes_data[i]
		var view_sc = load("res://scripts/view/ReceiverLaneView.gd")
		var view = view_sc.new()
		view.lane_index = i
		view.position = Vector2(start_x + float(i) * LANE_SPACING, 0)
		receiver_container.add_child(view)
		view.queue_receivers(receivers)
		if not receivers.is_empty():
			receiver_views[String((receivers[0] as Dictionary).get("id", ""))] = view

func _refresh_receiver_views() -> void:
	for i in range(mini(receiver_container.get_child_count(), simulation.lanes.size())):
		var view = receiver_container.get_child(i)
		if view != null and view.has_method("queue_receivers"):
			view.queue_receivers(simulation.lanes[i].queue)
			var front: Dictionary = simulation.lanes[i].front()
			if front.is_empty():
				view.set_front("", 0, 3, null)
			else:
				var color := String(front.get("color", ""))
				view.set_front(color, int(front.get("current_count", 0)), int(front.get("capacity", 3)),
					_receiver_texture_for(color), _marble_texture_for(color))

func _sync_board_from_simulation() -> void:
	for tray_id in tray_tiles.keys():
		var tile = tray_tiles[tray_id]
		var tray = simulation.trays.get(tray_id)
		if tray == null:
			continue
		tile.visible = not tray.is_consumed()
		tile.set_accessible(tray.is_accessible())
	if conveyor_view == null:
		return
	conveyor_view.set_capacity(simulation.belt_capacity)
	conveyor_view.set_belt_slots(simulation.belt.slots)
	if conveyor_view.is_warning():
		_on_belt_warning(conveyor_view.belt_occupancy)
	for token_id in simulation.tokens.keys():
		var token = simulation.tokens[token_id]
		if token.state == "BELT" and token.belt_slot >= 0:
			_spawn_marble(token.id, token.color_id)
			belt_visual_tokens[token.id] = true
			var marble = marble_sprites.get(token.id)
			if marble != null:
				marble.position = conveyor_view.position_for_slot(token.belt_slot)

func on_tray_tap(tray_id: String) -> void:
	if _input_locked or _modal_visible:
		return
	if _tutorial_root != null:
		_tutorial_root.hide()
	elif _tutorial_hint != null:
		_tutorial_hint.hide()
	if audio_director != null:
		audio_director.play_sfx("tray_select")
	tray_tapped.emit(tray_id)
	_input_locked = true
	var result := simulation.release_tray(tray_id) as Dictionary
	if not result.get("ok", false) as bool:
		_input_locked = false
		return
	if String(result.get("result", "")) != "jammed" or not result.get("overflowed", false):
		await _apply_events(result.get("events", []))
	if conveyor_view != null:
		conveyor_view.set_belt_slots(simulation.belt.slots)
	_refresh_receiver_views()
	if not result.get("overflowed", false):
		var released_tile = tray_tiles.get(tray_id)
		if released_tile != null:
			released_tile.visible = false
			released_tile.set_accessible(false)
	var moves_label = get_node_or_null("UI/SafeArea/Content/TopHUD/MovesLabel")
	if moves_label != null and simulation.moves_limit != null:
		moves_label.text = "MOVES " + str(int(simulation.moves_remaining))
	state_committed.emit(simulation.get_status() as String)
	var status := simulation.get_status() as String
	_refresh_booster_bar()
	if conveyor_view != null and conveyor_view.is_warning() and status == "playing":
		_on_belt_warning(conveyor_view.belt_occupancy)
	if status == "won":
		if player_progress != null:
			player_progress.clear_run()
		level_won.emit(current_level_id)
	elif status == "jammed":
		_persist_run_state()
		level_failed.emit(current_level_id, "jam")
	elif status == "no_moves":
		_persist_run_state()
		level_failed.emit(current_level_id, "no_moves")
	else:
		_persist_run_state()
	if status == "playing" and not (audio_director != null and audio_director.reduced_motion):
		await get_tree().create_timer(0.35).timeout
	_input_locked = false

func _apply_events(events: Array) -> void:
	var played_release_sound := false
	for ev in events:
		var etype := ev.get("type", "") as String
		if etype == "marble_released":
			var tray_id := String(ev.get("source_tray_id", ""))
			var tile = tray_tiles.get(tray_id)
			var start: Vector2 = tile.position if tile != null else Vector2(270, 120)
			_spawn_marble(String(ev.get("token_id", "")), String(ev.get("color_id", "")), start)
			await _drop_marble_into_funnel(String(ev.get("token_id", "")))
			if audio_director != null and not played_release_sound:
				audio_director.play_sfx("marble_release")
				played_release_sound = true
		elif etype == "marble_to_belt":
			await _move_marble_to_slot(String(ev.get("token_id", "")), int(ev.get("slot", 0)))
		elif etype == "marble_absorbed":
			await _absorb_marble(ev)
			if audio_director != null:
				audio_director.play_sfx("receiver_fill")
		elif etype == "receiver_completed":
			await _on_receiver_completed(ev)
		elif etype == "marble_rescued":
			_remove_marble(String(ev.get("token_id", "")))
		elif etype in ["tray_revealed", "tray_unlocked", "obstacle_cleared"]:
			_reveal_tray(String(ev.get("tray_id", "")))

func _reveal_tray(tray_id: String) -> void:
	var tile = tray_tiles.get(tray_id)
	if tile == null:
		return
	var reveal_tex = _tray_reveal_textures.get(tray_id, null)
	if reveal_tex != null:
		tile.set_tray_texture(reveal_tex)
	tile.set_accessible(true)
	if audio_director != null:
		audio_director.play_sfx("mystery_reveal")

func _spawn_marble(token_id: String, color_id: String, start_position: Vector2 = Vector2.INF) -> void:
	if marble_sprites.has(token_id):
		return
	var tex := _marble_texture_for(color_id) as Texture2D
	var marb_sc = load("res://scripts/view/Marble.gd")
	var m = marb_sc.new()
	m.setup(token_id, color_id, tex)
	m.scale = Vector2.ONE * 0.45
	m.position = start_position if start_position != Vector2.INF else (conveyor_view.position_for_slot(0) if conveyor_view != null else Vector2(270, 100))
	get_node("World").add_child(m)
	marble_sprites[token_id] = m

func _move_marble_to_slot(token_id: String, slot_index: int) -> void:
	var m = marble_sprites.get(token_id)
	if m == null or conveyor_view == null:
		return
	var target = conveyor_view.position_for_slot(slot_index)
	if _reduced_motion():
		m.position = target
		belt_visual_tokens[token_id] = true
		return
	var tween := create_tween()
	tween.tween_property(m, "position", target, 0.18)
	await tween.finished
	belt_visual_tokens[token_id] = true

func _drop_marble_into_funnel(token_id: String) -> void:
	var marble = marble_sprites.get(token_id)
	var funnel := get_node_or_null("World/Funnel") as Sprite2D
	if marble == null or funnel == null:
		return
	var target := funnel.position + Vector2(0, -34)
	if _reduced_motion():
		marble.position = target
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(marble, "position", target, 0.2)
	await tween.finished

func _absorb_marble(event: Dictionary) -> void:
	var token_id := String(event.get("token_id", ""))
	var lane_index := int(event.get("lane_index", -1))
	if lane_index >= 0 and lane_index < receiver_container.get_child_count():
		var view = receiver_container.get_child(lane_index)
		var m = marble_sprites.get(token_id)
		if m != null and view.has_method("hole_global_position"):
			var target: Vector2 = view.hole_global_position(int(event.get("fill_count", 1)))
			if _reduced_motion():
				m.position = target
			else:
				var tween := create_tween()
				tween.tween_property(m, "position", target, 0.12)
				await tween.finished
		_remove_marble(token_id)
		if view.has_method("set_front"):
			var color := String(event.get("receiver_color", ""))
			view.set_front(color, int(event.get("fill_count", 0)), int(event.get("capacity", 3)),
				_receiver_texture_for(color), _marble_texture_for(color))

func _remove_marble(token_id: String) -> void:
	var marble = marble_sprites.get(token_id)
	if marble != null:
		marble.queue_free()
		marble_sprites.erase(token_id)
	belt_visual_tokens.erase(token_id)

func _marble_texture_for(color_id: String) -> Texture2D:
	if asset_catalog == null or color_id == "":
		return null
	return asset_catalog.get_marble_texture(color_id)

func _receiver_texture_for(color_id: String) -> Texture2D:
	if asset_catalog == null or color_id == "":
		return null
	var tex: Texture2D = asset_catalog.get_receiver_texture(color_id)
	if tex == null:
		tex = asset_catalog.get_receiver_texture("red")
	return tex

func _on_receiver_completed(event: Dictionary) -> void:
	if audio_director != null:
		audio_director.play_sfx("receiver_complete")
		audio_director.vibrate(35)
	var lane_index := int(event.get("lane_index", -1))
	if lane_index >= 0 and lane_index < receiver_container.get_child_count():
		var view = receiver_container.get_child(lane_index)
		if view.has_method("queue_receivers"):
			var next: Dictionary = event.get("next_receiver", {}) as Dictionary
			view.queue_receivers([next] if not next.is_empty() else [])
			if not next.is_empty():
				var color := String(next.get("color", ""))
				view.set_front(color, int(next.get("current_count", 0)), int(next.get("capacity", 3)),
					_receiver_texture_for(color), _marble_texture_for(color))
	if not _reduced_motion():
		await get_tree().create_timer(0.12).timeout

func _reduced_motion() -> bool:
	return audio_director != null and audio_director.reduced_motion

func _on_belt_warning(occupancy: int) -> void:
	if audio_director != null:
		audio_director.play_sfx("belt_warning")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Modals (§20.4)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func show_pause() -> void:
	if audio_director != null:
		audio_director.play_sfx("ui_tap")
	_modal("Paused", ["Resume", "Restart −1"], _handle_pause_result, "Take a break. Opening this menu costs no hearts.")

func _handle_pause_result(index: int) -> void:
	if index == 1:  # Restart
		_request_restart()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not _modal_visible:
			show_pause()
		elif modal_dialog != null and modal_dialog.visible:
			var title: Label = modal_dialog.get_node_or_null("Panel/Frame/Content/Title") as Label
			if title != null and title.text == "Paused":
				modal_dialog._finish(0)
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_persist_run_state()

func show_zero_heart() -> void:
	_modal("Out of Hearts", ["Retry −1"], _handle_zero_heart_result)
	_watch_zero_hearts(_modal_generation)

func _handle_zero_heart_result(index: int) -> void:
	if index == 0 and player_progress != null and player_progress.can_restart():
		_request_restart()
	else:
		show_zero_heart()

func _watch_zero_hearts(generation: int) -> void:
	while generation == _modal_generation and _modal_visible:
		var hearts: int = player_progress.get_hearts() if player_progress != null else 0
		var seconds: int = player_progress.seconds_to_next_heart() if player_progress != null else 0
		if modal_dialog.has_method("set_message"):
			modal_dialog.set_message(
				"Heart available. Retry costs 1 heart." if hearts > 0
				else "Retry is disabled.\nNext heart in %02d:%02d" % [seconds / 60, seconds % 60]
			)
		if modal_dialog.has_method("set_button_disabled"):
			modal_dialog.set_button_disabled(0, hearts <= 0)
		if hearts > 0:
			return
		await get_tree().create_timer(1.0).timeout

func _on_level_won(level_id: String) -> void:
	var stars := clampi(3 - _restarts_this_level, 1, 3)
	if player_progress != null:
		var level_number: int = current_level_data.get("number", 1) as int
		var rewards: Dictionary = current_level_data.get("rewards", {}) as Dictionary
		player_progress.complete_level(level_id, level_number, stars, rewards.get("coins", 0) as int)
	if audio_director != null:
		audio_director.play_sfx("victory")
		audio_director.vibrate(80)
	var buttons := ["Next Level", "Replay"] if current_level_id != "level_030" else ["Replay"]
	_modal("Level Complete!", buttons, _handle_win_result, "Coins: +%d" % current_level_data.get("rewards", {}).get("coins", 0))
	_set_modal_art("victory", stars)

func _show_tutorial_hint(level_data: Dictionary) -> void:
	var tutorial: Dictionary = level_data.get("tutorial", {}) as Dictionary
	var steps: Array = tutorial.get("steps", []) as Array
	var enabled: bool = tutorial.get("enabled", false) as bool or level_data.get("number", 0) as int == 1
	if _tutorial_root == null:
		_tutorial_root = Control.new()
		_tutorial_root.position = Vector2(70, 250)
		_tutorial_root.size = Vector2(400, 76)
		_tutorial_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bubble := TextureRect.new()
		bubble.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bubble.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bubble.stretch_mode = TextureRect.STRETCH_SCALE
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if asset_catalog != null:
			bubble.texture = asset_catalog.get_ui_texture("panel_info")
		_tutorial_root.add_child(bubble)
		_tutorial_hint = Label.new()
		_tutorial_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_tutorial_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tutorial_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tutorial_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tutorial_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tutorial_hint.add_theme_color_override("font_color", Color(0.12, 0.18, 0.38))
		_tutorial_hint.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.7))
		_tutorial_hint.add_theme_constant_override("outline_size", 2)
		_tutorial_root.add_child(_tutorial_hint)
		var ui = get_node_or_null("UI")
		if ui != null:
			ui.add_child(_tutorial_root)
	_tutorial_hint.text = str(steps[0].get("text", "Tap a tray to release its marbles")) if steps.size() > 0 else "Tap a tray to release its marbles"
	_tutorial_root.visible = enabled

func _set_modal_art(kind: String, stars: int) -> void:
	if modal_dialog == null or asset_catalog == null:
		return
	if modal_dialog.has_method("set_art"):
		modal_dialog.set_art(asset_catalog.get_ui_texture(kind))
	if modal_dialog.has_method("set_stars"):
		modal_dialog.set_stars(stars)

func _handle_win_result(index: int) -> void:
	if index == 0 and current_level_id != "level_030":
		_load_next_level()
	else:
		_reload_level()

func _on_level_failed(level_id: String, reason: String) -> void:
	if audio_director != null:
		audio_director.play_sfx("failure")
		audio_director.vibrate(120)
	if player_progress != null and not _modal_visible:
		player_progress.break_win_streak()
	var hearts = player_progress.get_hearts() if player_progress != null else 0
	if hearts <= 0:
		show_zero_heart()
		_set_modal_art("game_over", 0)
	else:
		_modal("Game Over", ["Retry −1"], _handle_fail_result, "%s\nRetrying costs 1 heart." % ("Conveyor blocked" if reason == "jam" else "Out of moves"))
		_set_modal_art("game_over", 0)

func _show_restored_failure(restored_status: String) -> void:
	_on_level_failed(current_level_id, "jam" if restored_status == "jammed" else "no_moves")

func _handle_fail_result(index: int) -> void:
	if index == 0:
		_request_restart()

func _modal(title: String, buttons: Array, handler: Callable, message: String = " ") -> void:
	if modal_dialog == null:
		return
	_modal_generation += 1
	_modal_handler = handler
	_modal_visible = true
	modal_dialog.configure(title, message, buttons)

func _on_modal_result(index: int) -> void:
	if not _modal_visible:
		return
	var handler := _modal_handler
	_modal_handler = Callable()
	_modal_visible = false
	if handler != Callable():
		handler.call(index)

func _request_restart() -> void:
	if _restart_pending:
		return
	_restart_pending = true
	_restart_op_id = player_progress.allocate_operation_id() if player_progress != null else 0
	_modal("Restart Level?", ["Restart −1", "Cancel"], _handle_restart_confirm, "Restarting costs 1 heart. Your current attempt will reset.\nHearts: %d → %d" % [player_progress.get_hearts() if player_progress != null else 0, max(0, (player_progress.get_hearts() if player_progress != null else 1) - 1)])

func _handle_restart_confirm(index: int) -> void:
	if index != 0:
		_restart_pending = false
		return
	if player_progress == null:
		_restart_pending = false
		return
	var ret: int = player_progress.try_spend_life_for_restart(_restart_op_id)
	_restart_pending = false
	if ret == RET_OK or ret == RET_OP_DUPLICATE:
		_restarts_this_level += 1
		_reload_level()
	elif ret == RET_NO_HEARTS:
		show_zero_heart()
	else:
		push_error("GameController: restart failed")

func _persist_run_state() -> void:
	if player_progress == null or current_level_id == "":
		return
	player_progress.save_run_state(current_level_id, simulation.to_dict())

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Booster bar (§4.5)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _build_booster_bar() -> void:
	var bar = get_node_or_null("UI/SafeArea/Content/BoosterBar")
	if bar == null:
		return
	for child in bar.get_children():
		child.queue_free()
	booster_buttons = {}
	for booster_id in ["sweep", "picker", "reorder"]:
		var btn := Button.new()
		btn.name = "Booster_" + booster_id
		btn.custom_minimum_size = Vector2(0, 64)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.expand_icon = true
		btn.tooltip_text = booster_id.capitalize()
		btn.add_theme_font_size_override("font_size", 15)
		if asset_catalog != null and BOOSTER_ICONS.has(booster_id):
			var icon_spec: Array = BOOSTER_ICONS[booster_id]
			btn.icon = asset_catalog.get_section_icon(String(icon_spec[0]), String(icon_spec[1]), 34)
		btn.pressed.connect(_on_booster_pressed.bind(booster_id))
		bar.add_child(btn)
		booster_buttons[booster_id] = btn
	_refresh_booster_bar()

func _refresh_booster_bar() -> void:
	for booster_id in booster_buttons.keys():
		var btn: Button = booster_buttons[booster_id]
		if btn == null:
			continue
		var count := 0
		if player_progress != null:
			count = player_progress.get_booster_count(booster_id)
		var allowed: bool = simulation.allowed_boosters.has(booster_id)
		btn.text = "%s\nx%d" % [booster_id.capitalize(), count]
		btn.disabled = count <= 0 or not allowed or simulation.get_status() != "playing"

func _picker_target() -> String:
	# deterministic lowest-id blocked tray
	var candidates: Array = []
	for tray_id in tray_tiles.keys():
		var tray = simulation.trays.get(tray_id)
		if tray != null and not tray.is_consumed() and not tray.is_accessible():
			candidates.append(String(tray_id))
	candidates.sort()
	return String(candidates[0]) if candidates.size() > 0 else ""

func _on_booster_pressed(booster_id: String) -> void:
	if _input_locked or _modal_visible or player_progress == null:
		return
	var target := _picker_target() if booster_id == "picker" else ""
	var usable: Dictionary = simulation.can_use_booster(booster_id, target)
	if not usable.get("ok", false) or player_progress.get_booster_count(booster_id) <= 0:
		if audio_director != null:
			audio_director.play_sfx("booster_locked")
		return
	var preview := "Use %s?" % booster_id.capitalize()
	if booster_id == "picker":
		preview = "Use Picker on %s?" % target
	_modal(preview, ["Use", "Cancel"], _handle_booster_confirm.bind(booster_id, target), "Remaining: %d" % player_progress.get_booster_count(booster_id))

func _handle_booster_confirm(index: int, booster_id: String, target: String) -> void:
	if index != 0:
		return
	if player_progress == null or player_progress.get_booster_count(booster_id) <= 0:
		return
	_input_locked = true
	var result: Dictionary = simulation.apply_booster(booster_id, target)
	if not result.get("ok", false):
		_input_locked = false
		return
	player_progress.spend_booster(booster_id)
	if audio_director != null:
		audio_director.play_sfx("booster_use")
	await _apply_events(result.get("events", []))
	if conveyor_view != null:
		conveyor_view.set_belt_slots(simulation.belt.slots)
	_refresh_booster_bar()
	_refresh_receiver_views()
	_sync_board_from_simulation()
	var status := simulation.get_status() as String
	if status == "won":
		if player_progress != null:
			player_progress.clear_run()
		level_won.emit(current_level_id)
	elif status == "jammed":
		_persist_run_state()
		level_failed.emit(current_level_id, "jam")
	elif status == "no_moves":
		_persist_run_state()
		level_failed.emit(current_level_id, "no_moves")
	else:
		_persist_run_state()
	_input_locked = false

func _reload_level() -> void:
	if player_progress != null:
		player_progress.clear_run()
	if current_level_data.size() > 0:
		load_level(current_level_data, false, false)

func _load_next_level() -> void:
	var current_num := current_level_data.get("number", 1) as int
	if level_repo == null:
		return
	if player_progress != null:
		player_progress.clear_run()
	var next: Dictionary = level_repo.get_level_by_number(current_num + 1)
	if next != null and next.size() > 0:
		load_level(next, false)
	else:
		_modal("All Levels Complete", ["Replay"], _handle_win_result, "You cleared all 30 levels.")

func get_simulation():
	return simulation
