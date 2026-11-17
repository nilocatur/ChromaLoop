extends SceneTree

const FORBIDDEN := ["home", "lobby", "exit", "quit", "backlobby", "backtolobby", "menu_main"]

func _initialize() -> void:
	await process_frame
	var scene_router = get_root().get_node("SceneRouter")
	var audio = get_root().get_node_or_null("AudioDirector")
	if audio != null:
		audio.stop_music()
		audio.set_music_volume(0.0)
		audio.set_sfx_volume(0.0)
	var before_scene: Variant = scene_router.current_scene
	scene_router.change_to_paused()
	assert(scene_router.current_scene == before_scene)

	var gameplay = load("res://scenes/gameplay/Gameplay.tscn").instantiate()
	get_root().add_child(gameplay)
	await process_frame
	await process_frame

	var offenders: Array = []
	_collect_forbidden(gameplay, offenders)
	assert(offenders.is_empty(), "forbidden navigation controls in gameplay: " + str(offenders))

	# Pause and failure modals must not introduce a Home/Lobby/Exit route.
	gameplay.show_pause()
	await process_frame
	_collect_forbidden(gameplay, offenders)
	assert(offenders.is_empty(), "forbidden controls during pause: " + str(offenders))
	assert(gameplay._modal_visible)
	var restart_button: Button = gameplay.modal_dialog.get_node("Panel/Frame/Content/Buttons/btn_b") as Button
	assert(restart_button.text == "Restart −1")
	gameplay._on_modal_result(1)
	assert(gameplay._modal_visible)
	assert(gameplay._modal_handler == gameplay._handle_restart_confirm)
	assert((gameplay.modal_dialog.get_node("Panel/Frame/Content/Title") as Label).text == "Restart Level?")
	gameplay._on_modal_result(1)  # Cancel paid restart
	assert(not gameplay._modal_visible)
	assert(not gameplay._restart_pending)

	gameplay.show_pause()
	gameplay._on_modal_result(0)  # Resume
	assert(not gameplay._modal_visible)

	gameplay.queue_free()
	if gameplay.player_progress != null:
		gameplay.player_progress.clear_run()
	await process_frame
	await process_frame
	if audio != null:
		audio.stop_music()
		for child in audio.get_children():
			if child is AudioStreamPlayer2D and child != audio._music_player:
				child.stop()
				child.stream = null
				child.free()
	gameplay = null
	await process_frame

	print("Navigation rule checks passed")
	quit()

func _collect_forbidden(node: Node, offenders: Array) -> void:
	var lowered := node.name.to_lower()
	for token in FORBIDDEN:
		if lowered.contains(token):
			offenders.append(node.name)
			break
	for child in node.get_children():
		_collect_forbidden(child, offenders)
