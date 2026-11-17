class_name Marble
extends Sprite2D

# §8.3 / §11 — visual marble animated by ConveyorView/GameController from simulation events.
var token_id: String = ""
var color_id: String = ""
var state: String = "TRAY"

func setup(token_id: String, color_id: String, texture: Texture2D) -> void:
	self.token_id = token_id
	self.color_id = color_id
	self.texture = texture

func move_to(position: Vector2, duration: float = 0.25) -> void:
	var tween := create_tween()
	tween.tween_property(self, "position", position, duration)
