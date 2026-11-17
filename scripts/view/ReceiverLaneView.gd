class_name ReceiverLaneView
extends Node2D

# §11 / §8.3 — one receiver lane: shipped column art + filled-hole marbles.
# The simulation owns receiver state; this view only renders the front receiver.
const COLUMN_SCALE := 0.8
const MARBLE_SCALE := 0.33
const QUEUE_PREVIEW_SCALE := 0.38
const MAX_QUEUE_PREVIEWS := 2
# Hole centres in column-texture pixels (measured from the shipped 88x216 art).
const HOLE_OFFSET_Y := [48.0, 8.0, -32.0]  # bottom hole first: tube fills upward

var lane_index: int = -1
var receiver_id: String = ""
var color_id: String = ""
var _column_texture: Texture2D
var _marble_texture: Texture2D
var _holes_filled: int = 0
var _total_holes: int = 3
var _queue: Array = []
var _label: Label
var _nodes: Array[Node2D] = []

func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(-34, 96)
	_label.size = Vector2(68, 22)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 15)
	add_child(_label)
	_refresh()

func queue_receivers(receivers: Array) -> void:
	_queue = receivers.duplicate(true)
	if not _queue.is_empty():
		var front: Dictionary = _queue[0] as Dictionary
		receiver_id = String(front.get("id", ""))
		color_id = String(front.get("color", ""))
		_holes_filled = int(front.get("current_count", 0))
		_total_holes = int(front.get("capacity", 3))
	else:
		receiver_id = ""
		color_id = ""
		_holes_filled = 0
		_column_texture = null
		_marble_texture = null
	_refresh()

func set_front(color: String, holes_filled: int, total_holes: int,
		column_texture: Texture2D, marble_texture: Texture2D = null) -> void:
	color_id = color
	_holes_filled = holes_filled
	_total_holes = total_holes
	_column_texture = column_texture
	_marble_texture = marble_texture
	_refresh()

func hole_global_position(fill_count: int) -> Vector2:
	var index := clampi(fill_count - 1, 0, HOLE_OFFSET_Y.size() - 1)
	return to_global(Vector2(0, float(HOLE_OFFSET_Y[index]) * COLUMN_SCALE))

# legacy signature kept for compatibility
func set_fill(holes_filled: int, total_holes: int, texture: Texture2D = null) -> void:
	_holes_filled = holes_filled
	_total_holes = total_holes
	if texture != null:
		_column_texture = texture
	_refresh()

func _refresh() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()
	if _column_texture == null:
		# no receiver assigned to this lane (e.g. a completed queue) — render nothing
		if _label != null:
			_label.text = ""
		return
	var catalog = get_node_or_null("/root/AssetCatalog")
	for depth in range(1, mini(_queue.size(), MAX_QUEUE_PREVIEWS + 1)):
		var queued: Dictionary = _queue[depth] as Dictionary
		var preview := Sprite2D.new()
		if catalog != null:
			preview.texture = catalog.get_receiver_texture(String(queued.get("color", "")))
		preview.centered = true
		preview.scale = Vector2.ONE * QUEUE_PREVIEW_SCALE
		preview.position = Vector2(float(depth * 7), float(depth * 27))
		preview.z_index = -depth
		preview.modulate = Color(1, 1, 1, 0.78)
		add_child(preview)
		_nodes.append(preview)
	var base := Sprite2D.new()
	base.texture = _column_texture
	base.centered = true
	base.scale = Vector2.ONE * COLUMN_SCALE
	base.position = Vector2.ZERO
	add_child(base)
	_nodes.append(base)
	var marble_tex := _marble_texture
	if marble_tex == null:
		if catalog != null:
			marble_tex = catalog.get_marble_texture(color_id)
	for i in range(_total_holes):
		if i >= HOLE_OFFSET_Y.size():
			break
		var hole := Sprite2D.new()
		hole.centered = true
		hole.position = Vector2(0, float(HOLE_OFFSET_Y[i]) * COLUMN_SCALE)
		if i < _holes_filled and marble_tex != null:
			hole.texture = marble_tex
			hole.scale = Vector2.ONE * MARBLE_SCALE
		else:
			hole.texture = _hole_ring()
			hole.scale = Vector2.ONE * (18.0 * COLUMN_SCALE)
		add_child(hole)
		_nodes.append(hole)
	if _label != null:
		var queued_count := maxi(_queue.size() - 1, 0)
		_label.text = "%s  %d/%d%s" % [
			color_id.left(1).to_upper(), _holes_filled, _total_holes,
			"  +%d" % queued_count if queued_count > 0 else ""
		]

func _hole_ring() -> Texture2D:
	# 1x1 dark texture tinted by scale to hint an empty hole without new art
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.07, 0.09, 0.16, 0.85))
	var tex := ImageTexture.create_from_image(img)
	return tex
