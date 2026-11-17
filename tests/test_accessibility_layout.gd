extends SceneTree

func _initialize() -> void:
	await process_frame
	var audio = get_root().get_node("AudioDirector")
	audio.stop_music()
	audio.set_music_volume(0.0)
	audio.set_sfx_volume(0.0)
	assert(ProjectSettings.get_setting("display/window/size/viewport_width") == 540)
	assert(ProjectSettings.get_setting("display/window/size/viewport_height") == 960)
	assert(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items")
	assert(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand")

	var lobby = load("res://scenes/app/Lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	await process_frame
	var play: Button = lobby.get_node("SafeArea/Layout/PlayButton")
	var viewport_rect: Rect2 = lobby.get_viewport_rect()
	assert(play.size.y >= 48.0)
	assert(viewport_rect.encloses(play.get_global_rect()))
	assert(lobby.get_node("SafeArea/Layout/Header/AvatarButton").size.y >= 48.0)
	assert(lobby.get_node("SafeArea/Layout/Header/ShopPlus").size.y >= 48.0)
	assert(viewport_rect.encloses(lobby.get_node("SafeArea/Layout/BottomTabs").get_global_rect()))
	assert(root.gui_get_focus_owner() == play)
	lobby._show_settings()
	await process_frame
	var popup_focus := root.gui_get_focus_owner()
	assert(popup_focus != null and lobby._popup.is_ancestor_of(popup_focus))
	assert(viewport_rect.encloses(lobby._popup.get_child(0).get_child(0).get_global_rect()))
	assert(lobby.get_node("SafeArea").focus_behavior_recursive == Control.FOCUS_BEHAVIOR_DISABLED)
	lobby._close_popup()
	await process_frame
	await process_frame
	assert(root.gui_get_focus_owner() == play)
	lobby.free()

	var gameplay = load("res://scenes/gameplay/Gameplay.tscn").instantiate()
	root.add_child(gameplay)
	await process_frame
	var pause: Button = gameplay.get_node("UI/SafeArea/Content/TopHUD/PauseButton")
	var restart: Button = gameplay.get_node("UI/SafeArea/Content/TopHUD/RestartButton")
	assert(pause.size.y >= 48.0)
	assert(restart.size.y >= 48.0)
	assert(gameplay.get_viewport().get_visible_rect().encloses(pause.get_global_rect()))
	assert(gameplay.get_viewport().get_visible_rect().encloses(restart.get_global_rect()))
	assert(root.gui_get_focus_owner() == pause)
	gameplay.show_pause()
	await process_frame
	await process_frame
	assert(gameplay.modal_dialog.visible)
	assert(root.gui_get_focus_owner() is Button)
	gameplay.free()
	audio.stop_music()
	await process_frame
	print("Accessibility/layout self-check passed")
	quit(0)
