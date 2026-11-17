class_name Lobby
extends Control

var _selected_level_id := "level_001"
var _selected_number := 1
var _selected_button: Button
var _popup: Control
var player_progress
var scene_router
var asset_catalog
var audio_director

@onready var level_nodes: Control = $SafeArea/Layout/LevelsScroll/Map/LevelNodes
@onready var scroll: ScrollContainer = $SafeArea/Layout/LevelsScroll

func _ready() -> void:
	player_progress = get_node_or_null("/root/PlayerProgress")
	scene_router = get_node_or_null("/root/SceneRouter")
	asset_catalog = get_node_or_null("/root/AssetCatalog")
	audio_director = get_node_or_null("/root/AudioDirector")
	$SafeArea/Layout/Header/AvatarButton.pressed.connect(self._show_avatar_picker)
	$SafeArea/Layout/Header/PlayerName.pressed.connect(self._show_avatar_picker)
	$SafeArea/Layout/Header/ShopPlus.pressed.connect(self._show_shop)
	$SafeArea/Layout/PlayButton.pressed.connect(self._play)
	$SafeArea/Layout/BottomTabs/PlayTab.pressed.connect(self._focus_current_level)
	$SafeArea/Layout/BottomTabs/ShopTab.pressed.connect(self._show_shop)
	$SafeArea/Layout/BottomTabs/SettingsTab.pressed.connect(self._show_settings)
	_a11y($SafeArea/Layout/Header/AvatarButton, "Change avatar")
	_a11y($SafeArea/Layout/Header/PlayerName, "Edit profile")
	_a11y($SafeArea/Layout/Header/ShopPlus, "Open booster shop")
	_a11y($SafeArea/Layout/PlayButton, "Play selected level")
	_apply_scene_art()
	player_progress.hearts_changed.connect(self._on_wallet_changed)
	player_progress.coins_changed.connect(self._on_coins_changed)
	player_progress.profile_changed.connect(self._refresh_header)
	_build_levels()
	_refresh_header()
	call_deferred("_focus_current_level")
	call_deferred("_focus_primary_action")
	if audio_director != null:
		audio_director.play_music("lobby_music")

func _a11y(control: Control, label: String) -> void:
	if control == null:
		return
	control.tooltip_text = label
	if "accessibility_name" in control:
		control.set("accessibility_name", label)

func _apply_scene_art() -> void:
	if asset_catalog == null:
		return
	$SafeArea/Layout/Header/HeartIcon.texture = asset_catalog.get_ui_texture("heart")
	$SafeArea/Layout/Header/CoinIcon.texture = asset_catalog.get_ui_texture("coins_stack")
	$SafeArea/Layout/Header/PlayerName.icon = asset_catalog.get_ui_icon("edit", 24)
	$SafeArea/Layout/Header/ShopPlus.texture_normal = asset_catalog.get_ui_texture("plus")
	$SafeArea/Layout/PlayButton.icon = asset_catalog.get_ui_texture("play")
	$SafeArea/Layout/BottomTabs/PlayTab.icon = asset_catalog.get_ui_icon("play", 36)
	$SafeArea/Layout/BottomTabs/ShopTab.icon = asset_catalog.get_ui_icon("store", 30)
	$SafeArea/Layout/BottomTabs/SettingsTab.icon = asset_catalog.get_ui_icon("settings", 30)

func _refresh_header() -> void:
	$SafeArea/Layout/Header/PlayerName.text = player_progress.profile.get("player_name", "Player") as String
	$SafeArea/Layout/Header/HeartsLabel.text = str(player_progress.get_hearts())
	$SafeArea/Layout/Header/CoinsLabel.text = str(player_progress.get_coins())
	var avatar_id: String = player_progress.profile.get("avatar_id", "avatar_01_panda_king") as String
	$SafeArea/Layout/Header/AvatarButton.texture_normal = asset_catalog.get_texture(avatar_id)
	var streak: int = player_progress.get_win_streak()
	var marks := ""
	for i in range(5):
		marks += "● " if i < streak else "○ "
	$SafeArea/Layout/Streak/StreakLabel.text = "Level %d  •  Win streak: %s" % [_selected_number, marks.strip_edges()]

func _build_levels() -> void:
	var highest: int = player_progress.get_highest_unlocked_level()
	var path_x := [625.0, 590.0, 426.0, 235.0, 187.0, 186.0, 336.0, 502.0, 709.0, 751.0]
	var path_y := [1590.0, 1422.0, 1254.0, 1087.0, 919.0, 751.0, 583.0, 416.0, 248.0, 80.0]
	for number in range(1, 31):
		var id := "level_%03d" % number
		var button := Button.new()
		var stars: int = player_progress.get_level_stars(id)
		button.text = str(number) + ("\n" + "★".repeat(stars) if stars > 0 else "")
		button.custom_minimum_size = Vector2(72, 72)
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_constant_override("outline_size", 4)
		button.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.15))
		if asset_catalog != null:
			var node_icon: String = ["level_1", "level_2", "level_3"][(number - 1) % 3]
			if number > 20:
				node_icon = "hard"
			button.icon = asset_catalog.get_ui_icon(node_icon, 48)
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cycle := (number - 1) / 10
		var step := (number - 1) % 10
		button.position = Vector2(path_x[step] * 500.0 / 941.0 - 36.0, (2 - cycle) * 888.0 + path_y[step] * 888.0 / 1672.0 - 36.0)
		button.disabled = number > highest
		button.pressed.connect(self._select_level.bind(number, id, button))
		_a11y(button, "Level %d" % number)
		level_nodes.add_child(button)
		if number == mini(highest, 30):
			_selected_level_id = id
			_selected_number = number
			_selected_button = button
	if _selected_button != null:
		_selected_button.modulate = Color(1.0, 0.85, 0.25)
	_refresh_header()

func _select_level(number: int, id: String, button: Button) -> void:
	if _selected_button != null:
		_selected_button.modulate = Color.WHITE
	_selected_number = number
	_selected_level_id = id
	_selected_button = button
	button.modulate = Color(1.0, 0.85, 0.25)
	_refresh_header()

func _focus_current_level() -> void:
	if _selected_button != null:
		scroll.scroll_vertical = clampi(int(_selected_button.position.y) - int(scroll.size.y * 0.62), 0, maxi(0, int(scroll.get_v_scroll_bar().max_value - scroll.size.y)))

func _focus_primary_action() -> void:
	$SafeArea/Layout/PlayButton.grab_focus()

func _play() -> void:
	scene_router.pending_level_id = _selected_level_id
	scene_router.change_to("res://scenes/gameplay/Gameplay.tscn")

func _save_name(value: String) -> void:
	player_progress.set_player_name(value)

func _on_wallet_changed(_hearts: int, _max_hearts: int) -> void:
	_refresh_header()

func _on_coins_changed(_coins: int) -> void:
	_refresh_header()

func _new_popup(title: String) -> VBoxContainer:
	_close_popup()
	$SafeArea.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	$SafeArea.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	_popup = ColorRect.new()
	_popup.color = Color(0, 0, 0, 0.75)
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$PopupLayer.add_child(_popup)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 16
	center.offset_top = 16
	center.offset_right = -16
	center.offset_bottom = -16
	_popup.add_child(center)
	var frame := TextureRect.new()
	frame.custom_minimum_size = Vector2(470, 620)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	if asset_catalog != null:
		frame.texture = asset_catalog.get_ui_texture("panel_victory")
	center.add_child(frame)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 48
	panel.offset_top = 54
	panel.offset_right = -48
	panel.offset_bottom = -46
	panel.custom_minimum_size = Vector2(374, 0)
	panel.add_theme_constant_override("separation", 10)
	frame.add_child(panel)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(heading)
	return panel

func _add_close(panel: VBoxContainer) -> void:
	var close := TextureButton.new()
	close.custom_minimum_size = Vector2(56, 56)
	close.ignore_texture_size = true
	close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	if asset_catalog != null:
		close.texture_normal = asset_catalog.get_ui_texture("close")
	close.pressed.connect(self._close_popup)
	panel.add_child(close)
	close.call_deferred("grab_focus")

func _close_popup() -> void:
	var had_popup := _popup != null and is_instance_valid(_popup)
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null
	if had_popup:
		$SafeArea.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
		$SafeArea.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
		call_deferred("_focus_primary_action")

func _show_avatar_picker() -> void:
	var panel := _new_popup("Edit Profile")
	var name_row := HBoxContainer.new()
	panel.add_child(name_row)
	var name_field := LineEdit.new()
	name_field.name = "PlayerNameField"
	name_field.custom_minimum_size = Vector2(250, 48)
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_field.max_length = 20
	name_field.text = player_progress.profile.get("player_name", "Player") as String
	name_field.text_submitted.connect(self._save_profile_name.bind(name_field))
	name_row.add_child(name_field)
	var save := TextureButton.new()
	save.custom_minimum_size = Vector2(52, 52)
	save.ignore_texture_size = true
	save.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	save.texture_normal = asset_catalog.get_ui_texture("check")
	save.pressed.connect(self._save_profile_name_from_field.bind(name_field))
	_a11y(save, "Save player name")
	name_row.add_child(save)
	var grid := GridContainer.new()
	grid.columns = 4
	panel.add_child(grid)
	for i in range(1, 13):
		var id := "avatar_%02d_%s" % [i, ["panda_king", "dragon", "pirate_octopus", "astronaut_cat", "friendly_robot", "lion_king", "pilot_penguin", "lucky_leprechaun", "shark", "wizard_owl", "frog_king", "samurai_dog"][i - 1]]
		var button := TextureButton.new()
		button.custom_minimum_size = Vector2(96, 96)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.texture_normal = asset_catalog.get_texture(id)
		button.pressed.connect(self._choose_avatar.bind(id))
		_a11y(button, "Avatar " + str(i))
		grid.add_child(button)
	_add_close(panel)
	name_field.call_deferred("grab_focus")

func _save_profile_name(value: String, field: LineEdit) -> void:
	_save_name(field.text if field != null else value)
	if field != null:
		field.text = player_progress.profile.get("player_name", "Player") as String

func _save_profile_name_from_field(field: LineEdit) -> void:
	_save_profile_name(field.text, field)

func _choose_avatar(id: String) -> void:
	player_progress.set_avatar(id)

func _show_shop() -> void:
	var panel := _new_popup("Booster Shop — Coins " + str(player_progress.get_coins()))
	_add_shop_item(panel, "Sweep", "sweep")
	_add_shop_item(panel, "Picker", "picker")
	_add_shop_item(panel, "Reorder", "reorder")
	var status := Label.new()
	status.name = "Status"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(status)
	_add_close(panel)

func _add_shop_item(panel: VBoxContainer, label: String, id: String) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 48)
	var price: int = player_progress.get_booster_price(id)
	button.text = "%s — %d coins  (Owned: %d)" % [label, price, player_progress.get_booster_count(id)]
	if asset_catalog != null:
		var specs: Dictionary = {
			"sweep": ["actions", "fast_forward"],
			"picker": ["portals_boosters", "magnet"],
			"reorder": ["actions", "shuffle"]
		}
		if specs.has(id):
			var spec: Array = specs[id]
			button.icon = asset_catalog.get_section_icon(String(spec[0]), String(spec[1]), 30)
			button.expand_icon = true
	button.pressed.connect(self._buy_booster.bind(id))
	panel.add_child(button)

func _buy_booster(id: String) -> void:
	var success: bool = player_progress.buy_booster(id)
	_close_popup()
	_show_shop()
	var status = _popup.find_child("Status", true, false)
	if status != null:
		status.text = "Purchased" if success else "Not enough coins"

func _show_settings() -> void:
	var panel := _new_popup("Settings")
	var values: Dictionary = player_progress.get_settings()
	_add_slider(panel, "Music", "music_volume", values.get("music_volume", 0.8) as float)
	_add_slider(panel, "SFX", "sfx_volume", values.get("sfx_volume", 0.8) as float)
	_add_toggle(panel, "Haptics", "haptics", values.get("haptics", true) as bool)
	_add_toggle(panel, "Reduced motion", "reduced_motion", values.get("reduced_motion", false) as bool)
	var reset := Button.new()
	reset.text = "Reset Progress"
	reset.custom_minimum_size = Vector2(0, 48)
	reset.pressed.connect(self._confirm_reset)
	panel.add_child(reset)
	var credits := Label.new()
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.text = "ChromaLoop: Color Conveyor\nOffline puzzle game — no ads, no tracking\n\nCredits: original project art and\nlicensed sound effects (see AUDIO_MAPPING.md)\nPrivacy: this game stores progress only on your device."
	panel.add_child(credits)
	_add_close(panel)

func _add_slider(panel: VBoxContainer, label: String, key: String, value: float) -> void:
	var caption := Label.new()
	caption.text = label
	panel.add_child(caption)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(0, 48)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.value_changed.connect(self._setting_changed.bind(key))
	panel.add_child(slider)

func _add_toggle(panel: VBoxContainer, label: String, key: String, value: bool) -> void:
	var toggle := CheckButton.new()
	toggle.text = label
	toggle.custom_minimum_size = Vector2(0, 48)
	toggle.button_pressed = value
	toggle.toggled.connect(self._setting_toggled.bind(key))
	panel.add_child(toggle)

func _setting_changed(value: float, key: String) -> void:
	player_progress.set_setting(key, value)

func _setting_toggled(value: bool, key: String) -> void:
	player_progress.set_setting(key, value)

func _confirm_reset() -> void:
	var panel := _new_popup("Reset all progress?")
	var warning := Label.new()
	warning.text = "This erases your active run, hearts and wallet transactions, level progress, coins, boosters, and settings. This cannot be undone."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(warning)
	var confirm := Button.new()
	confirm.text = "Reset"
	confirm.custom_minimum_size = Vector2(0, 48)
	confirm.pressed.connect(self._reset_progress)
	panel.add_child(confirm)
	_add_close(panel)

func _reset_progress() -> void:
	player_progress.reset_progress()
	get_tree().change_scene_to_file("res://scenes/app/GameRoot.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _popup != null:
		_close_popup()
