extends SceneTree

# §8.1 / §19.4 — regression check that shipped art is actually wired into the
# gameplay and lobby scenes (not left as default/empty Godot controls).

func _initialize() -> void:
	await process_frame
	var audio = get_root().get_node_or_null("AudioDirector")
	if audio != null:
		audio.stop_music()
		audio.set_music_volume(0.0)
		audio.set_sfx_volume(0.0)

	var gameplay: Node = load("res://scenes/gameplay/Gameplay.tscn").instantiate()
	root.add_child(gameplay)
	for i in range(4):
		await process_frame

	var bg: TextureRect = gameplay.get_node_or_null("Background") as TextureRect
	assert(bg != null and bg.texture != null)
	for path in ["PauseButton", "RestartButton"]:
		var button: Button = gameplay.get_node_or_null("UI/SafeArea/Content/TopHUD/" + path) as Button
		assert(button != null and button.icon != null)
	var heart: TextureRect = gameplay.get_node_or_null("UI/SafeArea/Content/TopHUD/HeartIcon") as TextureRect
	assert(heart != null and heart.texture != null)

	var trays: Node = gameplay.get_node("World/Trays")
	assert(trays.get_child_count() > 0)
	for tile in trays.get_children():
		assert((tile as Sprite2D).texture != null)
		var marbles := 0
		for child in tile.get_children():
			if child is Sprite2D and (child as Sprite2D).texture != null and child != tile:
				marbles += 1
		assert(marbles > 0)

	var lanes: Node = gameplay.get_node("World/ReceiverLanes")
	assert(lanes.get_child_count() > 0)
	for view in lanes.get_children():
		var column_ok := false
		for child in view.get_children():
			if child is Sprite2D and (child as Sprite2D).texture != null and (child as Sprite2D).scale.x > 0.5:
				column_ok = true
		assert(column_ok)

	var conveyor: Node = gameplay.get_node_or_null("World/Conveyor")
	var funnel: Sprite2D = gameplay.get_node_or_null("World/Funnel") as Sprite2D
	assert(funnel != null and funnel.texture != null)
	var belt_sprites := 0
	for child in conveyor.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			belt_sprites += 1
	assert(belt_sprites > 0)

	var modal: Node = gameplay.get_node_or_null("UI/OverlayLayer/ModalDialog")
	assert(modal != null and modal.get_node_or_null("Panel/Frame/Content/Buttons/btn_a") != null)
	modal.configure("Level Complete!", "Coins: +10", ["Next Level", "Replay"])
	var catalog = get_root().get_node_or_null("AssetCatalog")
	modal.set_art(catalog.get_ui_texture("victory"))
	modal.set_stars(3)
	var art: TextureRect = modal.get_node_or_null("Panel/Frame/Content/Art") as TextureRect
	var frame: TextureRect = modal.get_node_or_null("Panel/Frame") as TextureRect
	var stars: HBoxContainer = modal.get_node_or_null("Panel/Frame/Content/Stars") as HBoxContainer
	assert(art != null and art.texture != null)
	assert(frame != null and frame.texture != null and frame.texture.resource_path.ends_with("panel_victory_large.png"))
	assert(stars != null and stars.visible)
	modal.hide()

	# tapping a tray releases textured marble sprites
	var first_tray = trays.get_child(0)
	gameplay.on_tray_tap(first_tray.tray_id)
	for i in range(3):
		await process_frame
	var spawned := 0
	for child in gameplay.get_node("World").get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			spawned += 1
	assert(spawned > 0)

	# lobby header / navigation icons
	var lobby: Node = load("res://scenes/app/Lobby.tscn").instantiate()
	root.add_child(lobby)
	for i in range(4):
		await process_frame
	var play := lobby.get_node_or_null("SafeArea/Layout/PlayButton") as Button
	assert(play.icon != null and play.icon.resource_path.ends_with("button_play.png"))
	assert((lobby.get_node_or_null("SafeArea/Layout/Header/HeartIcon") as TextureRect).texture != null)
	assert((lobby.get_node_or_null("SafeArea/Layout/Header/CoinIcon") as TextureRect).texture != null)
	assert((lobby.get_node_or_null("SafeArea/Layout/Header/ShopPlus") as TextureButton).texture_normal != null)
	assert(lobby.get_node_or_null("SafeArea/Layout/Header/PlayerName") is Button)
	assert(lobby.get_node_or_null("SafeArea/Layout/LevelsScroll/Map/PathTop") != null)
	lobby._show_avatar_picker()
	assert(lobby._popup.find_child("PlayerNameField", true, false) is LineEdit)
	lobby._close_popup()
	var level_nodes: Node = lobby.get_node_or_null("SafeArea/Layout/LevelsScroll/Map/LevelNodes")
	var icon_nodes := 0
	for node in level_nodes.get_children():
		if node is Button and (node as Button).icon != null:
			icon_nodes += 1
	assert(icon_nodes > 0)
	var first_level: Button = level_nodes.get_child(0) as Button
	var last_level: Button = level_nodes.get_child(29) as Button
	assert(first_level.position.y > last_level.position.y)
	var theme = get_root().get_node_or_null("UITheme")
	assert(theme != null and theme.theme != null and theme.theme.default_font != null)

	print("Asset wiring check passed")
	quit(0)
