class_name PlayerProgress
extends Node

# §13 / §21.4 / §21.5 — save to user://save_v1.json, atomic temp-write + rename,
# idempotent restart heart charge with operation journal.
signal hearts_changed(hearts: int, max_hearts: int)
signal coins_changed(coins: int)
signal level_unlocked(level_id: String)
signal settings_changed()
signal profile_changed()
signal save_loaded()
signal save_error(message: String)

const SAVE_PATH := "user://save_v1.json"
const BACKUP_PATH := "user://save_v1.bak.json"
const SAVE_SCHEMA := 3
const MAX_LEVEL := 30

const RET_OK := 0
const RET_NO_HEARTS := 1
const RET_OP_DUPLICATE := 2
const RET_ERROR := 3
const BOOSTER_PRICES := {"sweep": 60, "picker": 80, "reorder": 70}
const AVATAR_IDS := [
	"avatar_01_panda_king", "avatar_02_dragon", "avatar_03_pirate_octopus",
	"avatar_04_astronaut_cat", "avatar_05_friendly_robot", "avatar_06_lion_king",
	"avatar_07_pilot_penguin", "avatar_08_lucky_leprechaun", "avatar_09_shark",
	"avatar_10_wizard_owl", "avatar_11_frog_king", "avatar_12_samurai_dog"
]

var profile: Dictionary = {}
var run: Dictionary = {}
var wallet_transaction: Dictionary = {}
var settings: Dictionary = {}

var _is_saving: bool = false
var _balance: Dictionary = {
	"max_hearts": 5,
	"heart_regen_minutes": 20,
	"hearts_cost_restart": 1,
	"hearts_cost_retry": 1
}

func _ready() -> void:
	_load_balance()
	_load_or_migrate()

func _load_balance() -> void:
	var file := FileAccess.open("res://data/game_balance.json", FileAccess.READ)
	if file == null:
		push_warning("PlayerProgress: game_balance.json missing; using defaults")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_warning("PlayerProgress: game_balance.json invalid; using defaults")
		return
	var data: Dictionary = parsed
	_balance["max_hearts"] = maxi(1, int(data.get("max_hearts", 5)))
	_balance["heart_regen_minutes"] = maxi(1, int(data.get("heart_regen_minutes", 20)))
	_balance["hearts_cost_restart"] = maxi(1, int(data.get("hearts_cost_restart", 1)))
	_balance["hearts_cost_retry"] = maxi(1, int(data.get("hearts_cost_retry", 1)))

func _load_or_migrate() -> void:
	var data := _read_file(SAVE_PATH)
	if data.size() == 0:
		data = _read_file(BACKUP_PATH)
		if data.size() > 0:
			push_warning("PlayerProgress: recovered from backup")
	if data.size() == 0:
		profile = _default_profile()
		run = _default_run()
		wallet_transaction = _default_wallet()
		settings = _default_settings()
		_save()
		save_loaded.emit()
		return

	var schema := data.get("save_schema", 0) as int
	data = _migrate(data, schema)

	var loaded_profile: Variant = data.get("profile", null)
	profile = loaded_profile if loaded_profile is Dictionary else _default_profile()
	var loaded_run: Variant = data.get("run", null)
	run = loaded_run if loaded_run is Dictionary else _default_run()
	var loaded_wallet: Variant = data.get("wallet_transaction", null)
	wallet_transaction = loaded_wallet if loaded_wallet is Dictionary else _default_wallet()
	var loaded_settings: Variant = data.get("settings", null)
	settings = loaded_settings if loaded_settings is Dictionary else _default_settings()
	if not profile.has("hearts") or not profile.has("max_hearts"):
		profile["hearts"] = _balance.get("max_hearts", 5)
		profile["max_hearts"] = _balance.get("max_hearts", 5)
	if not wallet_transaction.has("next_operation_id"):
		wallet_transaction["next_operation_id"] = wallet_transaction.get("last_applied_operation_id", 0)
	_regen_hearts()
	save_loaded.emit()

func _migrate(data: Dictionary, from_schema: int) -> Dictionary:
	if from_schema >= SAVE_SCHEMA:
		return data
	if from_schema < 2:
		if not data.has("wallet_transaction"):
			data["wallet_transaction"] = _default_wallet()
	if from_schema < 3:
		var migrated_profile: Dictionary = data.get("profile", {}) as Dictionary
		if not migrated_profile.has("completed_levels"):
			migrated_profile["completed_levels"] = {}
		if not migrated_profile.has("tutorial_completed"):
			migrated_profile["tutorial_completed"] = false
		data["profile"] = migrated_profile
	data["save_schema"] = SAVE_SCHEMA
	return data

func _default_profile() -> Dictionary:
	return {
		"player_name": "Player",
		"avatar_id": "avatar_01_panda_king",
		"coins": 0,
		"hearts": _balance.get("max_hearts", 5),
		"max_hearts": _balance.get("max_hearts", 5),
		"next_regen_utc": null,
		"highest_unlocked_level": 1,
		"completed_levels": {},
		"tutorial_completed": false,
		"win_streak": 0,
		"inventory": {"sweep": 0, "picker": 0, "reorder": 0}
	}

func _default_run() -> Dictionary:
	return {
		"level_id": "",
		"seed": 0,
		"rules_version": 1,
		"status": "RUNNING",
		"committed_action_count": 0,
		"last_state_checksum": "",
		"serialized_simulation_state": null
	}

func _default_wallet() -> Dictionary:
	return {"last_applied_operation_id": 0, "next_operation_id": 0, "pending_restart_operation": null}

func _default_settings() -> Dictionary:
	return {"music_volume": 0.8, "sfx_volume": 0.8, "haptics": true, "reduced_motion": false}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Atomic restart heart charge (§21.4)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Monotonic operation IDs survive scene reloads and app restarts.
func allocate_operation_id() -> int:
	var last := int(wallet_transaction.get("last_applied_operation_id", 0))
	var next := int(wallet_transaction.get("next_operation_id", 0))
	var allocated: int = maxi(next, last) + 1
	wallet_transaction["next_operation_id"] = allocated
	_save()
	return allocated

func try_spend_life_for_restart(operation_id: int) -> int:
	if _is_saving:
		return RET_ERROR
	if operation_id <= 0:
		return RET_ERROR
	var last_applied := int(wallet_transaction.get("last_applied_operation_id", 0))
	if operation_id <= last_applied:
		return RET_OP_DUPLICATE
	if wallet_transaction.get("pending_restart_operation") == operation_id:
		return RET_OP_DUPLICATE

	_regen_hearts()
	var hearts := profile.get("hearts", 0) as int
	if hearts <= 0:
		return RET_NO_HEARTS

	var previous_hearts := hearts
	var previous_regen: Variant = profile.get("next_regen_utc", null)

	profile["hearts"] = hearts - 1
	if int(profile.get("hearts", 0)) < get_max_hearts() and profile.get("next_regen_utc", null) == null:
		profile["next_regen_utc"] = _utc_now() + _regen_interval_seconds()
	wallet_transaction["pending_restart_operation"] = operation_id
	wallet_transaction["last_applied_operation_id"] = operation_id
	wallet_transaction["next_operation_id"] = maxi(int(wallet_transaction.get("next_operation_id", 0)), operation_id)
	_emit_wallet_signals()

	if not _save():
		profile["hearts"] = previous_hearts
		profile["next_regen_utc"] = previous_regen
		wallet_transaction["pending_restart_operation"] = null
		wallet_transaction["last_applied_operation_id"] = last_applied
		_emit_wallet_signals()
		return RET_ERROR

	wallet_transaction["pending_restart_operation"] = null
	_save()
	return RET_OK

func _regen_interval_seconds() -> int:
	return maxi(1, int(_balance.get("heart_regen_minutes", 20))) * 60

func _regen_hearts() -> void:
	var max_hearts := get_max_hearts()
	var interval := _regen_interval_seconds()
	var hearts := get_hearts()
	var now := _utc_now()

	if hearts >= max_hearts:
		profile["hearts"] = max_hearts
		profile["next_regen_utc"] = null
		return

	var next_regen: Variant = profile.get("next_regen_utc", null)
	if next_regen == null or not (next_regen is int or next_regen is float):
		profile["next_regen_utc"] = now + interval
		return
	var next_value := int(next_regen)

	# Wall clock moved backwards: restart the timer instead of granting hearts.
	if now + 60 < next_value:
		profile["next_regen_utc"] = now + interval
		return

	var regenerated := 0
	while now >= next_value and hearts < max_hearts:
		hearts += 1
		next_value += interval
		regenerated += 1

	profile["hearts"] = hearts
	profile["next_regen_utc"] = next_value if hearts < max_hearts else null
	if regenerated > 0:
		_emit_wallet_signals()

func seconds_to_next_heart() -> int:
	_regen_hearts()
	if get_hearts() >= get_max_hearts():
		return 0
	var next_regen: Variant = profile.get("next_regen_utc", null)
	if next_regen == null:
		return _regen_interval_seconds()
	return clampi(int(next_regen) - _utc_now(), 0, _regen_interval_seconds())

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Queries
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_hearts() -> int:
	return profile.get("hearts", 0) as int

func get_max_hearts() -> int:
	return profile.get("max_hearts", _balance.get("max_hearts", 5)) as int

func get_coins() -> int:
	return profile.get("coins", 0) as int

func get_inventory() -> Dictionary:
	return profile.get("inventory", {}) as Dictionary

func get_booster_count(booster_id: String) -> int:
	return profile.get("inventory", {}).get(booster_id, 0) as int

func get_highest_unlocked_level() -> int:
	return profile.get("highest_unlocked_level", 1) as int

func get_settings() -> Dictionary:
	return settings.duplicate()

func can_restart() -> bool:
	return get_hearts() > 0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Mutations
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func add_coins(amount: int) -> void:
	profile["coins"] = profile.get("coins", 0) as int + amount
	_emit_wallet_signals()
	_save()

func set_level_unlocked(level_id: String, level_number: int) -> void:
	var current := profile.get("highest_unlocked_level", 1) as int
	if level_number > current:
		profile["highest_unlocked_level"] = level_number
		level_unlocked.emit(level_id)
		_save()

func complete_level(level_id: String, level_number: int, stars: int, coins: int) -> bool:
	var completed: Dictionary = profile.get("completed_levels", {}) as Dictionary
	var first_completion := not completed.has(level_id)
	var previous_stars: int = completed.get(level_id, 0) as int
	completed[level_id] = maxi(previous_stars, clampi(stars, 0, 3))
	profile["completed_levels"] = completed
	if first_completion:
		profile["coins"] = profile.get("coins", 0) as int + maxi(coins, 0)
	if level_number == 1:
		profile["tutorial_completed"] = true
	profile["win_streak"] = mini(get_win_streak() + 1, 5)
	var next_number := level_number + 1
	if next_number <= MAX_LEVEL and next_number > profile.get("highest_unlocked_level", 1) as int:
		profile["highest_unlocked_level"] = next_number
		level_unlocked.emit("level_%03d" % next_number)
	_emit_wallet_signals()
	profile_changed.emit()
	_save()
	return first_completion

func break_win_streak() -> void:
	if get_win_streak() == 0:
		return
	profile["win_streak"] = 0
	profile_changed.emit()
	_save()

func get_level_stars(level_id: String) -> int:
	return (profile.get("completed_levels", {}) as Dictionary).get(level_id, 0) as int

func is_tutorial_completed() -> bool:
	return profile.get("tutorial_completed", false) as bool

func set_player_name(value: String) -> void:
	var cleaned := value.strip_edges().substr(0, 20)
	profile["player_name"] = cleaned if cleaned != "" else "Player"
	profile_changed.emit()
	_save()

func set_avatar(avatar_id: String) -> void:
	if not AVATAR_IDS.has(avatar_id):
		return
	profile["avatar_id"] = avatar_id
	profile_changed.emit()
	_save()

func get_win_streak() -> int:
	return profile.get("win_streak", 0) as int

func get_booster_price(booster_id: String) -> int:
	return BOOSTER_PRICES.get(booster_id, -1) as int

func buy_booster(booster_id: String) -> bool:
	var price := get_booster_price(booster_id)
	if price < 0:
		return false
	var coins: int = profile.get("coins", 0) as int
	if coins < price:
		return false
	profile["coins"] = coins - price
	var inventory: Dictionary = profile.get("inventory", {}) as Dictionary
	inventory[booster_id] = inventory.get(booster_id, 0) as int + 1
	profile["inventory"] = inventory
	_emit_wallet_signals()
	profile_changed.emit()
	_save()
	return true

func reset_progress() -> void:
	profile = _default_profile()
	run = _default_run()
	wallet_transaction = _default_wallet()
	settings = _default_settings()
	_emit_wallet_signals()
	profile_changed.emit()
	settings_changed.emit()
	_save()

func add_booster(booster_id: String, amount: int) -> void:
	var inv := profile.get("inventory", {}) as Dictionary
	inv[booster_id] = inv.get(booster_id, 0) as int + amount
	profile["inventory"] = inv
	_emit_wallet_signals()
	_save()

func spend_booster(booster_id: String) -> bool:
	var inv := profile.get("inventory", {}) as Dictionary
	var current := inv.get(booster_id, 0) as int
	if current <= 0:
		return false
	inv[booster_id] = current - 1
	profile["inventory"] = inv
	_emit_wallet_signals()
	_save()
	return true

func set_setting(key: String, value) -> void:
	settings[key] = value
	settings_changed.emit()
	_save()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Authoritative run persistence (§4.4)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func save_run_state(level_id: String, state: Dictionary) -> bool:
	run = {
		"level_id": level_id,
		"seed": int(state.get("seed", 0)),
		"rules_version": int(state.get("rules_version", 1)),
		"status": String(state.get("status", "playing")),
		"committed_action_count": int(state.get("committed_action_count", 0)),
		"last_state_checksum": String(state.get("last_state_checksum", "")),
		"serialized_simulation_state": state.duplicate(true)
	}
	return _save()

func get_run() -> Dictionary:
	return run.duplicate(true)

func clear_run() -> void:
	run = _default_run()
	_save()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Persistence — atomic temp-write + rename (§13)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _save() -> bool:
	if _is_saving:
		return true
	_is_saving = true
	var ok := false
	var data := {
		"save_schema": SAVE_SCHEMA,
		"profile": profile,
		"run": run,
		"wallet_transaction": wallet_transaction,
		"settings": settings
	}
	var json := JSON.stringify(data)
	var temp_path := "user://save_v1.tmp.json"

	var previous_json := ""
	if FileAccess.file_exists(SAVE_PATH):
		var previous_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if previous_file != null:
			previous_json = previous_file.get_as_text()
			previous_file.close()
			if JSON.parse_string(previous_json) == null:
				previous_json = ""

	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file != null:
		file.store_string(json)
		file.close()

		# Backup keeps the last known-valid save, not a copy of the new write.
		var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		if backup != null:
			backup.store_string(previous_json if previous_json != "" else json)
			backup.close()

		var da := DirAccess.open("user://")
		if da != null:
			if da.rename(temp_path, SAVE_PATH) == OK:
				ok = true
			else:
				push_error("PlayerProgress: failed to rename save")
	_is_saving = false
	return ok

func _read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed := JSON.parse_string(text) as Dictionary
	if parsed == null:
		return {}
	return parsed

func _emit_wallet_signals() -> void:
	hearts_changed.emit(profile.get("hearts", 0) as int, profile.get("max_hearts", 5) as int)
	coins_changed.emit(profile.get("coins", 0) as int)

func _utc_now() -> int:
	return int(Time.get_unix_time_from_system())

func _days_from_civil(y: int, m: int, d: int) -> int:
	var yy := y
	var mm := m
	if mm <= 2:
		yy -= 1
	var era := yy / 400
	var yoe := yy - era * 400
	var doy := (153 * (mm + (-3 if mm > 2 else 9)) + 2) / 5 + d - 1
	var doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468
