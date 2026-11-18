extends SceneTree
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func press_q(game: Node2D, echo: bool = false) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	key.echo = echo
	game._input(key)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	game.set_process(false) # Score label must update immediately, without _process.
	var worker = game.get_node("Worker")
	worker.set_physics_process(false)
	var sound: AudioStreamPlayer = game.get_node("ShipmentSound")
	var approach: Vector2 = game.get_node("WorkshopWalls/OutletApproach").global_position
	for kind in ["cell", "battery_set"]:
		game.items = [{"kind": kind, "pos": game.SINK_POS, "prev_pos": game.SINK_POS, "progress": 1.0}]
		game._on_tick()
	check(game.score == 0 and not sound.playing and game._packing_machine.battery_count == 1, "Loose cells and batteries do not score; battery still counts for packing")
	# Raw material at the shipping port is rejected and retained in hand.
	worker.global_position = game._box.pickup_approach()
	await physics_frame
	check(worker.pickup_box(game._box), "Pick up original raw material")
	worker.global_position = approach
	worker.sprite.flip_h = false
	press_q(game)
	check(game.score == 0 and worker.carrying_box and worker.carried_box_node == game._box, "Raw crate cannot ship or be lost")
	worker.release_box()
	game._box.show()
	for i in 4:
		game.items = [{"kind": "battery_set", "pos": game.SINK_POS, "prev_pos": game.SINK_POS, "progress": 1.0}]
		game._on_tick()
	check(game.packed_boxes.size() == 1 and game.score == 0, "Packing creates one eligible crate without scoring")
	var box: Sprite2D = game.packed_boxes[0]
	await physics_frame
	check(worker.pickup_box(box), "Pick up machine-produced crate")
	worker.sprite.flip_h = false
	worker.global_position = approach + Vector2(0, -64)
	check(not game._ship_carried_box() and game.score == 0, "Wrong row cannot ship")
	worker.global_position = approach
	worker.sprite.flip_h = true
	check(not game._ship_carried_box(), "Must face the port")
	worker.sprite.flip_h = false
	worker.set_dialogue_locked(true)
	press_q(game)
	check(game.score == 0 and worker.carrying_box, "Dialogue blocks shipping")
	worker.set_dialogue_locked(false)
	game.welding_interaction._physics_process(0.0)
	check(game.welding_interaction._hint.text == "Q 发货（+1）", "Shipping hint identifies valid delivery")
	press_q(game, true)
	check(game.score == 0, "Key repeat cannot ship")
	press_q(game)
	check(game.score == 1 and not worker.carrying_box and game.packed_boxes.is_empty(), "One finished crate scores exactly one")
	check(box.get_parent() == null and box.is_queued_for_deletion(), "Shipped crate immediately leaves scene")
	check(game.get_node("UI/ScoreLabel").text.begins_with("得分: 1"), "HUD updates in same event")
	check(sound.playing, "Only successful shipment plays shipment sound")
	if "--preview" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/shipping-preview.png")
	sound.stop()
	press_q(game)
	check(game.score == 1 and not sound.playing, "Duplicate delivery cannot score or play sound")
	await process_frame
	check(not is_instance_valid(box), "Shipped node is freed")
	# Matching appearance, script and metadata alone do not establish machine provenance.
	var fake := Sprite2D.new()
	fake.set_script(game.PACKED_BOX)
	fake.set_meta("box_kind", "battery_crate")
	fake.set_meta("battery_count", 5)
	game.add_child(fake)
	fake.position = Vector2(672, 288)
	await physics_frame
	check(worker.pickup_box(fake), "Test crate can use normal pickup interface")
	worker.sprite.flip_h = false
	press_q(game)
	check(game.score == 1 and worker.carried_box_node == fake, "Unregistered crate cannot score even with correct tags")
	print("Shipping checks; failures=", failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
