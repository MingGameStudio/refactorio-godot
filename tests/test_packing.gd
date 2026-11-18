extends SceneTree
const PhysicsSteps = preload("res://tests/physics_steps.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func feed(game: Node2D) -> void:
	var before: Vector2i = game.SINK_POS + Vector2i.LEFT
	game.items.append({"kind": "battery_set", "pos": before, "prev_pos": before, "progress": 1.0})
	game._on_tick()
	game._on_tick()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.physics_ticks_per_second = 120
	Engine.time_scale = 4.0
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	var worker = game.get_node("Worker")
	worker.set_physics_process(false)
	var machine = game._packing_machine
	var output: Vector2i = game.SINK_POS + Vector2i.RIGHT
	await physics_frame
	for i in 4:
		feed(game)
		check(machine.battery_count == i + 1 and game.packed_boxes.is_empty(), "Count each battery exactly once; no early crate")
	feed(game)
	check(machine.battery_count == 0 and game.packed_boxes.size() == 1, "Five batteries create one crate and consume count")
	var box: Sprite2D = game.packed_boxes[0]
	check(game.world_to_cell(box.global_position) == output and box.visible, "Crate occupies right output cell")
	check(box.get_meta("battery_count") == 5, "Crate preserves five batteries")
	check(game.score == 0, "Battery intake and packing do not score")
	for i in 5:
		feed(game)
	check(machine.battery_count == 5 and machine.get_node("PackingProgress").text == "5/5", "Blocked machine retains full batch visibly")
	if "--preview" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/packing-preview.png")
	for i in 12:
		game._on_tick()
	check(game.packed_boxes.size() == 1 and machine.battery_count == 5, "Blocked output cannot duplicate crate")
	feed(game)
	check(game.items.size() == 1 and machine.battery_count == 5 and game.score == 0, "Full machine backpressures next battery without scoring")
	# Clicking output crate walks around facilities to an adjacent accessible cell.
	var click: Vector2 = box.to_global(box.get_rect().get_center())
	game._press_world = click
	game._drag_start = output
	game._pointer_dragged = false
	game._drag_can_build = false
	game._finish_left_gesture(click)
	await PhysicsSteps.advance(worker, 10.0)
	check(worker.carrying_box and worker.carried_box_node == box and not box.visible, "Click pickup reuses carrying state and animation")
	check(worker.carried_box_kind == "battery_crate", "Finished crate is typed")
	check(not game._source_machine.can_accept_box(worker, false), "Finished crate cannot become raw material")
	game._on_tick()
	check(game.packed_boxes.size() == 2 and machine.battery_count == 0, "Clearing output releases exactly one waiting batch")
	game._on_tick()
	check(machine.battery_count == 1 and game.score == 0, "Pending battery counted once after unblock without scoring")
	# Q drops the same object, preserving contents; repeated Q cannot duplicate it.
	worker.position = Vector2(480, 160)
	worker.sprite.flip_h = false
	var score_before: int = game.score
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_Q
	game._input(key)
	check(not worker.carrying_box and box.visible and box.position == Vector2(544, 160), "Q drops at facing adjacent empty cell")
	game._input(key)
	check(game.packed_boxes.size() == 2 and box.get_meta("battery_count") == 5 and game.score == score_before, "Drop neither duplicates nor scores")
	await physics_frame
	key.physical_keycode = KEY_E
	game.welding_interaction._unhandled_key_input(key)
	check(worker.carried_box_node == box and not box.visible, "Dropped crate can be picked up with E")
	worker.set_dialogue_locked(true)
	check(not game.drop_carried_box(), "Dialogue prevents dropping")
	worker.set_dialogue_locked(false)
	worker.position = Vector2(736, 288)
	worker.sprite.flip_h = true
	check(not game.drop_carried_box() and worker.carried_box_node == box, "Occupied output rejects drop without losing carried crate")
	# Output reservations also account for loose belt items and missing belt.
	var second: Sprite2D = game.packed_boxes[1]
	second.hide()
	machine.battery_count = 5
	game.items = [{"pos": output, "prev_pos": output, "progress": 1.0}]
	machine.try_pack(game)
	check(machine.battery_count == 5 and game.packed_boxes.size() == 2, "Loose output item blocks packing")
	game.items.clear()
	game._clear_building(output)
	machine.try_pack(game)
	check(machine.battery_count == 5 and game.packed_boxes.size() == 2, "Missing output belt retains batch")
	print("Packing checks; failures=", failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
