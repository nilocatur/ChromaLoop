class_name AssetCatalog
extends Node

# §8.1 / §7.4 / §19.4 — logical ID → Texture2D cache. Never assemble paths from user input.
var manifest: Dictionary = {}
var texture_cache: Dictionary = {}

func _ready() -> void:
	_load_manifest()

func _load_manifest() -> void:
	var file := FileAccess.open("res://data/asset_manifest.json", FileAccess.READ)
	if file == null:
		push_warning("AssetCatalog: asset_manifest.json not found")
		return
	var json := JSON.parse_string(file.get_as_text()) as Dictionary
	file.close()
	if json == null:
		push_error("AssetCatalog: failed to parse asset_manifest.json")
		return
	manifest = json

func has_section(section: String) -> bool:
	return manifest.get(section, null) is Dictionary

func section_keys(section: String) -> Array:
	var value: Variant = manifest.get(section, {})
	if value is Dictionary:
		return (value as Dictionary).keys()
	return []

func resolve_path(logical_key: String) -> String:
	# search all sections for logical_key (first match wins, in manifest order)
	for section in manifest.keys():
		var value: Variant = manifest.get(section, {})
		if not value is Dictionary:
			continue
		var entries: Dictionary = value as Dictionary
		if entries.has(logical_key):
			return entries.get(logical_key, "") as String
	return ""

func resolve_path_in(section: String, logical_key: String) -> String:
	# deterministic section-scoped lookup — "red" exists in marbles AND receivers
	var value: Variant = manifest.get(section, {})
	if not value is Dictionary:
		return ""
	return (value as Dictionary).get(logical_key, "") as String

func _load_texture(cache_key: String, path: String) -> Texture2D:
	if path == "":
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("AssetCatalog: failed to load " + path)
		return null
	texture_cache[cache_key] = tex
	return tex

func get_texture(logical_key: String) -> Texture2D:
	var cache_key := "any/" + logical_key
	if texture_cache.has(cache_key):
		return texture_cache.get(cache_key) as Texture2D
	return _load_texture(cache_key, resolve_path(logical_key))

func get_section_texture(section: String, logical_key: String) -> Texture2D:
	var cache_key := section + "/" + logical_key
	if texture_cache.has(cache_key):
		return texture_cache.get(cache_key) as Texture2D
	return _load_texture(cache_key, resolve_path_in(section, logical_key))

func get_marble_texture(color_id: String) -> Texture2D:
	return get_section_texture("marbles", color_id)

func get_receiver_texture(color_id: String) -> Texture2D:
	return get_section_texture("receivers", color_id)

func get_tray_texture(name: String) -> Texture2D:
	return get_section_texture("trays", name)

func get_conveyor_texture(name: String) -> Texture2D:
	return get_section_texture("conveyor", name)

func get_obstacle_texture(name: String) -> Texture2D:
	return get_section_texture("obstacles", name)

func get_ui_texture(id: String) -> Texture2D:
	# UI texture ids are unique per file name; search UI sections only.
	for section in ["ui_buttons", "ui_panels", "ui_backgrounds", "ui_level_nodes",
			"celebration", "economy", "ui_tutorial", "ui_results", "ui_brand", "avatars"]:
		var tex := get_section_texture(section, id)
		if tex != null:
			return tex
	return null

func cache_all_marbles() -> void:
	for key in section_keys("marbles"):
		get_marble_texture(String(key))

func marble_map() -> Dictionary:
	var out: Dictionary = {}
	for key in section_keys("marbles"):
		out[String(key)] = get_marble_texture(String(key))
	return out

# ── Downscaled icons ───────────────────────────────────────────────────
# Button.icon draws at the texture's natural size, and the shipped art is large
# (e.g. button_play.png is 1091px wide), so icons are resized once and cached.

func get_ui_icon(id: String, max_dim: int = 64) -> Texture2D:
	var source := get_ui_texture(id)
	return _scaled(source, "icon/any/%s/%d" % [id, max_dim], max_dim)

func get_section_icon(section: String, id: String, max_dim: int = 64) -> Texture2D:
	var source := get_section_texture(section, id)
	return _scaled(source, "icon/%s/%s/%d" % [section, id, max_dim], max_dim)

func _scaled(source: Texture2D, cache_key: String, max_dim: int) -> Texture2D:
	if source == null:
		return null
	if texture_cache.has(cache_key):
		return texture_cache.get(cache_key) as Texture2D
	var size := source.get_size()
	var longest := maxf(size.x, size.y)
	if longest <= float(max_dim):
		texture_cache[cache_key] = source
		return source
	var factor := float(max_dim) / longest
	var img := source.get_image()
	if img == null:
		return source
	if img.is_compressed():
		img.decompress()
	img.resize(maxi(1, int(round(size.x * factor))), maxi(1, int(round(size.y * factor))), Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	texture_cache[cache_key] = tex
	return tex
