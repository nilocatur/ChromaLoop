extends SceneTree

func _initialize() -> void:
	await process_frame
	var progress = get_root().get_node("PlayerProgress")
	var saved_profile: Dictionary = progress.profile.duplicate(true)
	var saved_wallet: Dictionary = progress.wallet_transaction.duplicate(true)
	var saved_run: Dictionary = progress.run.duplicate(true)
	var saved_settings: Dictionary = progress.settings.duplicate(true)

	progress.profile = progress._default_profile()
	progress.wallet_transaction = progress._default_wallet()
	progress.run = progress._default_run()
	progress.profile["hearts"] = 3
	progress.profile["next_regen_utc"] = null

	# Confirm once: 3 -> 2
	var op1: int = progress.allocate_operation_id()
	assert(progress.try_spend_life_for_restart(op1) == 0)
	assert(progress.get_hearts() == 2)

	# Repeated callback with same operation id: no second charge
	assert(progress.try_spend_life_for_restart(op1) == 2)
	assert(progress.get_hearts() == 2)

	# Operation id persists as applied across a scene reload
	assert(progress.try_spend_life_for_restart(op1) == 2)
	assert(progress.get_hearts() == 2)

	# Spend down to zero
	var op2: int = progress.allocate_operation_id()
	assert(progress.try_spend_life_for_restart(op2) == 0)
	assert(progress.get_hearts() == 1)
	var op3: int = progress.allocate_operation_id()
	assert(progress.try_spend_life_for_restart(op3) == 0)
	assert(progress.get_hearts() == 0)

	# Zero hearts blocks further paid actions and never goes negative
	var op4: int = progress.allocate_operation_id()
	assert(progress.try_spend_life_for_restart(op4) == 1)
	assert(progress.get_hearts() == 0)

	# Invalid operation ids are rejected
	assert(progress.try_spend_life_for_restart(0) == 3)

	# Full hearts with a stale timer: regen normalizes, then spending starts a fresh timer
	progress.profile["hearts"] = progress.get_max_hearts()
	progress.profile["next_regen_utc"] = int(Time.get_unix_time_from_system()) - 100000
	var op5: int = progress.allocate_operation_id()
	assert(progress.try_spend_life_for_restart(op5) == 0)
	assert(progress.get_hearts() == progress.get_max_hearts() - 1)
	var next_regen = progress.profile.get("next_regen_utc", null)
	assert(next_regen != null)
	assert(progress.seconds_to_next_heart() > 0)

	# Full hearts report no countdown
	progress.profile["hearts"] = progress.get_max_hearts()
	progress.profile["next_regen_utc"] = null
	assert(progress.seconds_to_next_heart() == 0)

	progress.profile = saved_profile
	progress.wallet_transaction = saved_wallet
	progress.run = saved_run
	progress.settings = saved_settings
	progress._save()

	print("Lives transaction checks passed")
	quit()
