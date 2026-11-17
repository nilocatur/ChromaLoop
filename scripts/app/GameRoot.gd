class_name GameRoot
extends Control

# Boot: enter Lobby; Lobby hands off to Gameplay with a pending level.
@onready var game_content: Node = $GameContent

func _ready() -> void:
	var progress = get_node_or_null("/root/PlayerProgress")
	if progress != null and not progress.is_tutorial_completed():
		var router = get_node_or_null("/root/SceneRouter")
		if router != null:
			router.pending_level_id = "level_001"
		var gameplay = load("res://scenes/gameplay/Gameplay.tscn").instantiate()
		game_content.add_child(gameplay)
	else:
		var lobby = load("res://scenes/app/Lobby.tscn").instantiate()
		game_content.add_child(lobby)
