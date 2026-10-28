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
	var machine = game.get_node("BuildingLayer/SourceMachine")
	machine.set_process(false)
	var worker = game.get_node("Worker")
	worker.set_physics_process(false)
	var input: Vector2i = game._input_cell
	check(game.SOURCE_POS == Vector2i(2, 4) and input == Vector2i(1, 4), "Machine and input moved right")
	check(game.is_cell_walkable(Vector2i(0, 4)), "Leftmost cell accessible")
	game._clear_building(input)
	game._set_building(input, game.Building.BELT)
	game._place_belt_path([{"pos": input, "dir": game.Dir.UP}])
	check(game.buildings[input.x][input.y].type == game.Building.INPUT, "Input remains protected")
	for i in 20:
		game._on_tick()
	check(game.items.is_empty() and machine.capacity == 0, "Empty machine cannot produce")
	worker.request_pickup(game.get_node("Box"))
	worker._physics_process(10.0)
	check(worker.carrying_box, "Box picked up")
	var original_position: Vector2 = worker.global_position
	for offset in [Vector2(0, -64), Vector2(0, 64), Vector2(64, 0)]:
		worker.global_position = machine.input_position() + offset
		worker.sprite.flip_h = false
		check(not machine.accept_box(worker) and worker.carrying_box, "Other sides cannot deliver")
	worker.global_position = machine.delivery_position()
	worker.sprite.flip_h = true
	check(not machine.accept_box(worker) and worker.carrying_box, "Facing left cannot deliver")
	worker.global_position = original_position
	game._set_building(input + Vector2i.LEFT, game.Building.BELT)
	game._request_box_delivery()
	worker._physics_process(0.1)
	check(worker.carrying_box and not machine.feeding, "Blocked left side does not fall back to another side")
	game._clear_building(input + Vector2i.LEFT)
	game._request_box_delivery()
	check(worker.target_position == machine.delivery_position(), "Delivery targets left cell center")
	worker._physics_process(0.1)
	check(worker.carrying_box and not machine.feeding, "Walk before dropping")
	worker.move_to(worker.global_position)
	worker._physics_process(10.0)
	check(worker.carrying_box and not machine.feeding, "Movement cancels delivery")
	game._request_box_delivery()
	for i in 1000:
		worker._physics_process(0.02)
		check(game.is_cell_walkable(game.world_to_cell(worker.global_position)), "Delivery avoids obstacles")
		if machine.feeding:
			break
	check(machine.feeding and not worker.carrying_box and machine.capacity == 0, "Arrival transfers box without early credit")
	check(worker.global_position.is_equal_approx(machine.delivery_position()), "Drop happens only at left side")
	check(not worker.sprite.flip_h, "Worker turns right before dropping")
	var start: Vector2 = machine.get_node("InputBox").position
	machine._process(0.5)
	check(machine.get_node("InputBox").position.x > start.x and machine.capacity == 0, "Box moves before credit")
	check(not machine.accept_box(worker), "Cannot feed twice")
	machine._process(0.5)
	check(machine.capacity == 10 and not machine.get_node("InputBox").visible, "Entry credits ten")
	check(machine.get_node("CapacityLabel").text == "10", "Display shows ten")
	machine._process(10.0)
	check(machine.capacity == 10, "No duplicate credit")
	var output: Vector2i = game.SOURCE_POS + Vector2i.RIGHT
	game._clear_building(output)
	game._on_tick()
	check(machine.capacity == 10 and game.items.is_empty(), "Missing belt preserves capacity")
	game._set_building(output, game.Building.BELT)
	game.items.append({"pos": output, "prev_pos": output, "progress": 1.0})
	game._on_tick()
	check(machine.capacity == 10, "Blocked output preserves capacity")
	game.items.clear()
	game._on_tick()
	check(machine.capacity == 9 and game.items.size() == 1, "Production consumes one")
	for i in 60:
		game._on_tick()
	check(machine.capacity == 0 and game.score == 10 and game.items.is_empty(), "Exactly ten cells produced")
	check(machine.get_node("CapacityLabel").text == "0", "Display shows zero")
	game.queue_free()
	await process_frame
	print("Machine feeding checks completed: %d failures" % failures)
	quit(1 if failures else 0)
