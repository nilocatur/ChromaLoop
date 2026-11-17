class_name TrayTile
extends Sprite2D

# §20.3 / §8.3 — one-tap tray, indicates blocked/locked. Emits tray_tapped(tray_id).
signal tray_tapped(tray_id: String)

var tray_id: String = ""
var accessible: bool = true
var color_hint: String = ""
var mechanic_type: String = "standard"
var _marble_nodes: Array[Sprite2D] = []
var _marble_colors: Array[String] = []
var _marble_textures: Dictionary = {}
var _marker: Label
var _mechanic_icon: Sprite2D

func _ready() -> void:
	set_process_unhandled_input(true)
	modulate = Color(1, 1, 1, 1 if accessible else 0.5)
	_marker = Label.new()
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.z_index = 3
	_marker.position = Vector2(-30, -30)
	_marker.size = Vector2(60, 24)
	_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_marker.add_theme_font_size_override("font_size", 18)
	_marker.add_theme_constant_override("outline_size", 6)
	_marker.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.15))
	add_child(_marker)
	_refresh_marker()

func set_tray_texture(frame: Texture2D) -> void:
	texture = frame
	if frame != null:
		# Fit the tray art to the ~120px logical tray cell, keeping aspect.
		scale = Vector2.ONE * (120.0 / maxf(1.0, float(frame.get_width())))
	_refresh_marbles()
	_refresh_marker()

func set_mechanic_icon(icon: Texture2D) -> void:
	if icon == null:
		return
	if _mechanic_icon == null:
		_mechanic_icon = Sprite2D.new()
		_mechanic_icon.z_index = 2
		add_child(_mechanic_icon)
	_mechanic_icon.texture = icon
	_mechanic_icon.scale = Vector2.ONE
	_mechanic_icon.visible = not accessible

func set_marbles(colors: Array, marble_textures: Dictionary = {}) -> void:
	_marble_colors.clear()
	for color in colors:
		_marble_colors.append(String(color))
	_marble_textures = marble_textures
	if _marble_colors.size() > 0:
		color_hint = _marble_colors[0]
	_refresh_marbles()
	_refresh_marker()

func _refresh_marbles() -> void:
	for child in _marble_nodes:
		child.queue_free()
	_marble_nodes.clear()
	var cols := 3
	var count := _marble_colors.size()
	for i in range(count):
		var color := _marble_colors[i]
		var marble := Sprite2D.new()
		marble.texture = _marble_textures.get(color, null)
		marble.centered = true
		marble.scale = Vector2.ONE * 0.5
		marble.position = Vector2(float(i % cols - 1) * 40.0, float(i / cols - 1) * 40.0)
		marble.z_index = 1
		marble.visible = _marble_visible()
		add_child(marble)
		_marble_nodes.append(marble)

func _marble_visible() -> bool:
	return not (mechanic_type == "mystery" and not accessible)

func _unhandled_input(event: InputEvent) -> void:
	if not accessible or texture == null:
		return
	var pressed = false
	var viewport_position = Vector2.ZERO
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		viewport_position = event.position
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		viewport_position = event.position
	if not pressed:
		return
	var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * viewport_position
	var texture_size: Vector2 = texture.get_size()
	var top_left = -texture_size * 0.5 if centered else Vector2.ZERO
	if Rect2(top_left, texture_size).has_point(local_position):
		tray_tapped.emit(tray_id)
		get_viewport().set_input_as_handled()

func set_accessible(value: bool) -> void:
	accessible = value
	modulate = Color(1, 1, 1, 1 if value else 0.5)
	for marble in _marble_nodes:
		marble.visible = value or mechanic_type != "mystery"
	if _mechanic_icon != null:
		_mechanic_icon.visible = not value
	_refresh_marker()

func set_color_hint(color: String) -> void:
	color_hint = color
	_refresh_marker()

func set_mechanic(value: String) -> void:
	mechanic_type = value
	_refresh_marker()

func _refresh_marker() -> void:
	if _marker == null:
		return
	_marker.text = "?" if (not accessible and mechanic_type == "mystery") else ""
