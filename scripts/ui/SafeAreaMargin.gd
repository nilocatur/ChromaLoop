class_name SafeAreaMargin
extends MarginContainer

@export var minimum_margin: int = 16

func _ready() -> void:
	get_viewport().size_changed.connect(self._apply_safe_area)
	_apply_safe_area()

func _apply_safe_area() -> void:
	var window_size := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if window_size.x <= 0 or window_size.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		_set_margins(minimum_margin, minimum_margin, minimum_margin, minimum_margin)
		return
	var viewport_size := get_viewport_rect().size
	var scale := viewport_size / Vector2(window_size)
	var left := maxi(minimum_margin, roundi(safe.position.x * scale.x))
	var top := maxi(minimum_margin, roundi(safe.position.y * scale.y))
	var right := maxi(minimum_margin, roundi((window_size.x - safe.end.x) * scale.x))
	var bottom := maxi(minimum_margin, roundi((window_size.y - safe.end.y) * scale.y))
	_set_margins(left, top, right, bottom)

func _set_margins(left: int, top: int, right: int, bottom: int) -> void:
	add_theme_constant_override("margin_left", left)
	add_theme_constant_override("margin_top", top)
	add_theme_constant_override("margin_right", right)
	add_theme_constant_override("margin_bottom", bottom)
