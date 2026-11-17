extends SceneTree

const PuzzleSimulation = preload("res://scripts/core/PuzzleSimulation.gd")
const ReceiverLaneModel = preload("res://scripts/core/ReceiverLaneModel.gd")

func _initialize() -> void:
	assert(ProjectSettings.get_setting("application/run/main_scene", "") == "res://scenes/app/GameRoot.tscn")
	var modal = load("res://scenes/ui/ModalDialog.tscn").instantiate()
	root.add_child(modal)
	assert(modal.get_node_or_null("Panel/Frame/Content/Title") != null)
	assert(modal.get_node_or_null("Panel/Frame/Content/Buttons/btn_a") != null)
	modal.free()

	var lane = ReceiverLaneModel.new()
	lane.setup(0, [{"id": "r1", "color": "red", "capacity": 3}])
	assert(lane.fill_current(1) == 1)
	assert(lane.front().get("current_count", -1) == 1)

	var simulation = PuzzleSimulation.new()
	simulation.load_level({
		"id": "overflow_test",
		"belt_capacity": 1,
		"lane_count": 4,
		"tray_marble_count": 2,
		"moves_limit": null,
		"trays": [{"id": "t1", "grid_x": 0, "grid_y": 0, "marbles": ["red", "red"]}],
		"lanes": [[], [], [], []]
	})
	var result: Dictionary = simulation.release_tray("t1")
	assert(result.get("result", "") == "jammed")
	for event in result.get("events", []):
		assert(event.get("type", "") != "marble_released")
		assert(event.get("type", "") != "marble_to_belt")
	assert(simulation.belt.count_used() == 0)
	assert(not simulation.trays["t1"].is_consumed())
	for token in simulation.trays["t1"].marbles:
		assert(token.state == "TRAY")
	print("P0 self-check passed")
	quit(0)
