extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	game.set_process(false)
	var worker = game.get_node("Worker")
	worker.set_physics_process(false)
	for anchor in [game.SOURCE_POS, game.SINK_POS]:
		var machine: Node2D = game.buildings[anchor.x][anchor.y].node
		worker.position = (Vector2(anchor) + Vector2(0.5, -0.5)) * game.CELL
		worker._physics_process(0.0)
		check(worker.z_index < machine.z_index, "Worker behind machine is obscured")
		worker.position = (Vector2(anchor) + Vector2(0.5, 1.5)) * game.CELL
		worker._physics_process(0.0)
		check(worker.z_index > machine.z_index, "Worker in front covers machine")
	check(worker.carried_box.z_as_relative and worker.carried_box.z_index == 0, "Carried box inherits worker depth")
	check(worker.sprite.z_as_relative and worker.sprite.z_index == 0, "All animation frames inherit worker depth")
	game._set_building(Vector2i(5, 6), game.Building.SOURCE)
	check(game.buildings[5][6].node.z_index > game.buildings[game.SOURCE_POS.x][game.SOURCE_POS.y].node.z_index, "New machines use their placement row")
	worker.position = Vector2(352, 224)
	worker.move_to(Vector2(352, 96))
	var old_depth: int = worker.z_index
	worker._physics_process(0.5)
	check(worker.z_index < old_depth, "Depth updates while walking across rows")
	check(game.get_node("Box").z_index > game.get_node("FloorLayer").z_index, "Ground box remains above floor")
	game.queue_free()
	await process_frame
	print("Depth checks completed: %d failures" % failures)
	quit(1 if failures else 0)
