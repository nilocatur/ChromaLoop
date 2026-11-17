class_name SceneRouter
extends Node

# §8.1 / §20.2 — boot, lobby and game scene transitions. No marble logic.
var current_scene: Node = null
var pending_level_id: String = ""

func change_to(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("SceneRouter: failed to load " + scene_path)
		return
	var error: int = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("SceneRouter: scene change failed: " + str(error))

func change_to_paused() -> void:
	# handled by overlay within gameplay scene per spec — no lobby route during level
	pass
