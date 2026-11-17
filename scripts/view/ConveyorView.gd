class_name ConveyorView
extends Node2D

# §11 / §16.4 — belt is drawn from the shipped conveyor art tiled along the Path2D.
# The logical belt slots remain the source of truth; sprites only visualise them.
@onready var track: Path2D = $Track
@onready var marbles_container: Node2D = $Marbles

const BELT_THICKNESS := 42.0
const WARNING_TINT := Color(1.0, 0.72, 0.55)
const FLOW_SPEED := 74.0

var belt_slot_positions: Array = []  # Vector2 (local) per logical slot
var belt_capacity_value: int = 22
var belt_occupancy: int = 0
var belt_slots: Array = []

var _belt_texture: Texture2D
var _belt_sprites: Array[Sprite2D] = []
var _flow_phase: float = 0.0
var _flow_progress: float = 0.0

func _ready() -> void:
	if track.curve == null:
		var _curve: Curve2D = Curve2D.new()
		_curve.add_point(Vector2(70, 0))
		_curve.add_point(Vector2(70, 110))
		_curve.add_point(Vector2(470, 110))
		_curve.add_point(Vector2(470, 0))
		_curve.add_point(Vector2(70, 0))
		track.curve = _curve
	var catalog = get_node_or_null("/root/AssetCatalog")
	if catalog != null:
		_belt_texture = catalog.get_conveyor_texture("ring")
	_build_slot_positions()
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	var audio = get_node_or_null("/root/AudioDirector")
	if audio != null and audio.reduced_motion:
		return
	_flow_phase = fmod(_flow_phase + delta * 4.0, TAU)
	var path_length := track.curve.get_baked_length() if track.curve != null else 0.0
	if path_length > 0.0:
		# Curve points run down left side, then right along bottom: counter-clockwise.
		_flow_progress = fmod(_flow_progress + delta * FLOW_SPEED, path_length)
	queue_redraw()

func _build_slot_positions() -> void:
	belt_slot_positions = []
	var follow := PathFollow2D.new()
	follow.rotates = false
	track.add_child(follow)
	var slots := belt_capacity()
	for i in range(slots):
		follow.progress_ratio = float(i) / float(slots)
		belt_slot_positions.push_back(to_local(follow.global_position))
	track.remove_child(follow)
	follow.queue_free()
	_rebuild_belt()
	queue_redraw()

func _rebuild_belt() -> void:
	for sprite in _belt_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_belt_sprites.clear()
	if _belt_texture == null or belt_slot_positions.size() < 2:
		return
	var tex_size := _belt_texture.get_size()
	var longest := maxf(tex_size.x, tex_size.y)
	if longest <= 0.0:
		return
	for point in belt_slot_positions:
		var sprite := Sprite2D.new()
		sprite.texture = _belt_texture
		sprite.centered = true
		sprite.scale = Vector2.ONE * (BELT_THICKNESS / longest)
		sprite.position = point
		sprite.z_index = -1
		add_child(sprite)
		_belt_sprites.append(sprite)

func belt_capacity() -> int:
	return belt_capacity_value

func set_capacity(value: int) -> void:
	if value > 0 and value != belt_capacity_value:
		belt_capacity_value = value
		if is_inside_tree():
			_build_slot_positions()

func set_occupancy(used: int, capacity: int) -> void:
	belt_occupancy = used
	if capacity > 0:
		set_capacity(capacity)
	_apply_warning_tint()
	queue_redraw()

func set_belt_slots(slots: Array) -> void:
	belt_slots = slots.duplicate()
	belt_occupancy = 0
	for slot in belt_slots:
		if slot != null:
			belt_occupancy += 1
	_apply_warning_tint()
	queue_redraw()

func is_warning() -> bool:
	return belt_capacity() > 0 and belt_occupancy >= int(ceil(belt_capacity() * 0.8))

func _apply_warning_tint() -> void:
	if _belt_sprites.is_empty():
		return
	var tint := WARNING_TINT if is_warning() else Color(1, 1, 1)
	for sprite in _belt_sprites:
		if is_instance_valid(sprite):
			sprite.modulate = tint

func position_for_slot(slot_index: int) -> Vector2:
	if slot_index < 0 or slot_index >= belt_slot_positions.size():
		return Vector2.ZERO
	# callers place marbles under World, which shares this node's parent transform
	return to_global(belt_slot_positions[slot_index])

func moving_position_for_slot(slot_index: int) -> Vector2:
	if slot_index < 0 or slot_index >= belt_slot_positions.size() or track.curve == null:
		return Vector2.ZERO
	var length := track.curve.get_baked_length()
	if length <= 0.0:
		return position_for_slot(slot_index)
	var progress := fmod(float(slot_index) * length / float(belt_capacity()) + _flow_progress, length)
	return track.to_global(track.curve.sample_baked(progress))

func _draw() -> void:
	# Bright moving rollers make counter-clockwise travel readable without changing logical slots.
	if track.curve != null:
		var length := track.curve.get_baked_length()
		if length > 0.0:
			for marker in range(12):
				var progress := fmod(_flow_progress + float(marker) * length / 12.0, length)
				var point := track.curve.sample_baked(progress)
				draw_circle(point, 4.5, Color(0.78, 0.88, 1.0, 0.82))
	# subtle slot markers on top of the belt art so the 22 logical slots stay legible
	for i in range(belt_slot_positions.size()):
		var point: Vector2 = belt_slot_positions[i]
		var occupied: bool = i < belt_slots.size() and belt_slots[i] != null
		if not occupied:
			var wave := 0.5 + 0.5 * sin(_flow_phase - float(i) * 0.75)
			draw_circle(point, 11.0, Color(0.08, 0.11, 0.2, 0.25 + wave * 0.2))
	if is_warning():
		draw_string(ThemeDB.fallback_font, Vector2(160, 150), "BELT NEAR FULL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.82, 0.55))
