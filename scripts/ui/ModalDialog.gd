class_name ModalDialog
extends Control

# Reusable modal dialog (§20.4), styled from the shipped UI panel art by UITheme.
# Buttons are wired by name to avoid callable/funcref parsing limits.
signal result(index: int)

const CONTENT_PATH := "Panel/Frame/Content/"

var button_labels: Array = []
var _previous_focus: Control

func _ready() -> void:
	self.mouse_filter = Control.MOUSE_FILTER_STOP
	var names = ["btn_a", "btn_b", "btn_c"]
	var handlers = [self._on_btn_a, self._on_btn_b, self._on_btn_c]
	for i in range(3):
		var b = get_node_or_null(CONTENT_PATH + "Buttons/" + names[i])
		if b != null:
			b.pressed.connect(handlers[i])
	hide()

func configure(title: String, message: String, button_labels: Array) -> void:
	_previous_focus = get_viewport().gui_get_focus_owner()
	var title_l = get_node_or_null(CONTENT_PATH + "Title")
	var msg_l = get_node_or_null(CONTENT_PATH + "Message")
	if title_l != null:
		title_l.text = title
	if msg_l != null:
		msg_l.text = message
	clear_art()
	self.button_labels = button_labels.duplicate()
	var names = ["btn_a", "btn_b", "btn_c"]
	for i in range(3):
		var b = get_node_or_null(CONTENT_PATH + "Buttons/" + names[i])
		if b != null:
			b.disabled = false
			if i < button_labels.size():
				b.text = button_labels[i] as String
				b.visible = true
				_apply_button_art(b, b.text)
			else:
				b.visible = false
	show()
	_configure_focus_loop()

func _apply_button_art(button: Button, label: String) -> void:
	button.icon = null
	button.custom_minimum_size = Vector2(112, 54)
	button.remove_theme_font_size_override("font_size")
	button.remove_theme_color_override("font_color")
	button.remove_theme_color_override("font_hover_color")
	button.remove_theme_color_override("font_pressed_color")
	var catalog = get_node_or_null("/root/AssetCatalog")
	if catalog == null:
		return
	var art_id := "retry" if label.begins_with("Retry") else ("restart" if label.begins_with("Restart") else "")
	if art_id == "":
		return
	button.icon = catalog.get_ui_texture(art_id)
	button.expand_icon = true
	button.custom_minimum_size = Vector2(260, 64) if art_id == "retry" else Vector2(180, 58)
	button.add_theme_font_size_override("font_size", 1)
	var hidden := Color(1, 1, 1, 0)
	button.add_theme_color_override("font_color", hidden)
	button.add_theme_color_override("font_hover_color", hidden)
	button.add_theme_color_override("font_pressed_color", hidden)

func set_art(texture: Texture2D) -> void:
	var art = get_node_or_null(CONTENT_PATH + "Art")
	if art == null:
		return
	art.texture = texture
	art.visible = texture != null
	art.custom_minimum_size = Vector2(0, 130) if texture != null else Vector2.ZERO

func set_stars(count: int) -> void:
	var stars_root = get_node_or_null(CONTENT_PATH + "Stars")
	if stars_root == null:
		return
	var catalog = get_node_or_null("/root/AssetCatalog")
	var gold: Texture2D = catalog.get_ui_texture("star_gold_3") if catalog != null else null
	var silver: Texture2D = catalog.get_ui_texture("star_silver") if catalog != null else null
	var names := ["star_a", "star_b", "star_c"]
	var any := false
	for i in range(names.size()):
		var node = stars_root.get_node_or_null(names[i])
		if node == null:
			continue
		if i < count:
			node.texture = gold
			node.modulate = Color(1, 1, 1, 1)
			node.visible = gold != null
			any = any or gold != null
		else:
			node.texture = silver
			node.modulate = Color(1, 1, 1, 0.28)
			node.visible = silver != null
			any = any or silver != null
	stars_root.visible = any

func set_message(message: String) -> void:
	var label = get_node_or_null(CONTENT_PATH + "Message")
	if label != null:
		label.text = message

func set_button_disabled(index: int, disabled: bool) -> void:
	var names := ["btn_a", "btn_b", "btn_c"]
	if index < 0 or index >= names.size():
		return
	var button := get_node_or_null(CONTENT_PATH + "Buttons/" + names[index]) as Button
	if button == null:
		return
	button.disabled = disabled
	if not disabled and button.visible:
		button.call_deferred("grab_focus")

func clear_art() -> void:
	var art = get_node_or_null(CONTENT_PATH + "Art")
	if art != null:
		art.texture = null
		art.visible = false
	var stars_root = get_node_or_null(CONTENT_PATH + "Stars")
	if stars_root != null:
		stars_root.visible = false

func _configure_focus_loop() -> void:
	var visible_buttons: Array[Button] = []
	for name in ["btn_a", "btn_b", "btn_c"]:
		var button := get_node_or_null(CONTENT_PATH + "Buttons/" + name) as Button
		if button != null and button.visible:
			visible_buttons.push_back(button)
	if visible_buttons.is_empty():
		return
	for i in range(visible_buttons.size()):
		var button := visible_buttons[i]
		var previous := visible_buttons[posmod(i - 1, visible_buttons.size())].get_path()
		var next := visible_buttons[(i + 1) % visible_buttons.size()].get_path()
		button.focus_neighbor_left = previous
		button.focus_neighbor_top = previous
		button.focus_neighbor_right = next
		button.focus_neighbor_bottom = next
		button.focus_previous = previous
		button.focus_next = next
	visible_buttons[0].call_deferred("grab_focus")

func _finish(index: int) -> void:
	hide()
	result.emit(index)
	if _previous_focus != null and is_instance_valid(_previous_focus):
		_previous_focus.call_deferred("grab_focus")

func _on_btn_a() -> void:
	_finish(0)

func _on_btn_b() -> void:
	_finish(1)

func _on_btn_c() -> void:
	_finish(2)
