class_name UITheme
extends Node

# Builds a project-wide Theme in code from the shipped UI art so default Godot
# controls (buttons, panels, text fields, labels) stop looking stock.
# Applied to the root Window, so it cascades to every Control in every scene.

const BUTTON_TEXTURE := "panel_pill"
const PANEL_TEXTURE := "panel_dialog"
const FIELD_TEXTURE := "panel_info"
const APP_FONT := preload("res://assets/ui/fonts/ChangaOne-Regular.ttf")

var theme: Theme


func _ready() -> void:
	var catalog = get_node_or_null("/root/AssetCatalog")
	if catalog == null:
		return
	theme = _build(catalog)
	get_tree().root.theme = theme


func _build(catalog) -> Theme:
	var t := Theme.new()
	t.default_font = APP_FONT
	t.default_font_size = 18

	# ── Buttons ────────────────────────────────────────────────────────────
	var button_tex: Texture2D = catalog.get_ui_texture(BUTTON_TEXTURE)
	if button_tex != null:
		var normal := _style(button_tex, 30, 24)
		var hover := _style(button_tex, 30, 24)
		hover.modulate_color = Color(1.08, 1.08, 1.08)
		var pressed := _style(button_tex, 30, 24)
		pressed.modulate_color = Color(0.86, 0.88, 0.95)
		var disabled := _style(button_tex, 30, 24)
		disabled.modulate_color = Color(0.6, 0.6, 0.66, 0.6)
		t.set_stylebox("normal", "Button", normal)
		t.set_stylebox("hover", "Button", hover)
		t.set_stylebox("pressed", "Button", pressed)
		t.set_stylebox("focus", "Button", hover)
		t.set_stylebox("disabled", "Button", disabled)
		t.set_stylebox("normal", "OptionButton", normal)
		t.set_stylebox("hover", "OptionButton", hover)
		t.set_stylebox("pressed", "OptionButton", pressed)
		t.set_stylebox("disabled", "OptionButton", disabled)

	# ── Panels ─────────────────────────────────────────────────────────────
	var panel_tex: Texture2D = catalog.get_ui_texture(PANEL_TEXTURE)
	if panel_tex != null:
		var panel_style := _style(panel_tex, 46, 40)
		t.set_stylebox("panel", "Panel", panel_style)
		t.set_stylebox("panel", "PanelContainer", panel_style)

	# ── Text fields ────────────────────────────────────────────────────────
	var field_tex: Texture2D = catalog.get_ui_texture(FIELD_TEXTURE)
	if field_tex != null:
		var field_style := _style(field_tex, 26, 20)
		t.set_stylebox("normal", "LineEdit", field_style)
		var focus := _style(field_tex, 26, 20)
		focus.modulate_color = Color(1.0, 0.96, 0.68)
		t.set_stylebox("focus", "LineEdit", focus)

	# ── Readable text over busy art ────────────────────────────────────────
	t.set_color("font_color", "Label", Color(0.97, 0.98, 1.0))
	t.set_color("font_outline_color", "Label", Color(0.05, 0.07, 0.14))
	t.set_constant("outline_size", "Label", 5)
	t.set_color("font_color", "Button", Color(0.99, 0.99, 1.0))
	t.set_color("font_outline_color", "Button", Color(0.06, 0.08, 0.16))
	t.set_constant("outline_size", "Button", 5)
	t.set_font_size("font_size", "Button", 18)
	t.set_color("font_color", "CheckButton", Color(0.97, 0.98, 1.0))
	t.set_color("font_outline_color", "CheckButton", Color(0.06, 0.08, 0.16))
	t.set_constant("outline_size", "CheckButton", 5)
	return t


func _style(texture: Texture2D, margin_x: int, margin_y: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = texture
	# Keep the outer frame crisp: scale the 9-slice borders with the texture.
	var w := float(texture.get_width())
	var h := float(texture.get_height())
	sb.texture_margin_left = clampf(w * 0.35, 4.0, w * 0.5)
	sb.texture_margin_right = clampf(w * 0.35, 4.0, w * 0.5)
	sb.texture_margin_top = clampf(h * 0.40, 4.0, h * 0.5)
	sb.texture_margin_bottom = clampf(h * 0.40, 4.0, h * 0.5)
	sb.set_content_margin(SIDE_LEFT, margin_x)
	sb.set_content_margin(SIDE_RIGHT, margin_x)
	sb.set_content_margin(SIDE_TOP, margin_y)
	sb.set_content_margin(SIDE_BOTTOM, margin_y)
	return sb
