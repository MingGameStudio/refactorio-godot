extends SceneTree
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func advance(ui: Node) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	ui._input(event)
	event.pressed = false
	ui._input(event)

func make_crate(game: Node) -> void:
	for i in 5:
		game.items = [{"kind": "battery_set", "pos": game.SINK_POS, "prev_pos": game.SINK_POS, "progress": 1.0}]
		game._on_tick()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	var ui = game.dialogue_ui
	ui.set_process(false)
	var worker = game.get_node("Worker")
	worker.set_physics_process(false)
	var portrait: TextureRect = ui.get_node("Root/Portrait")
	check(game.HAPPY_FRAMES.get_frame_count(&"default") == 72, "Happy contains all 72 frames")
	check(not game.HAPPY_FRAMES.get_animation_loop(&"default"), "Happy is non-looping")
	for i in 72:
		check(game.HAPPY_FRAMES.get_frame_texture(&"default", i).get_size() == Vector2(720, 1080), "Shared portrait canvas")
	game._try_first_order_dialogue()
	check(not ui.is_active, "Cannot trigger before shipment")
	make_crate(game)
	check(not ui.is_active and game.score == 0, "Packing alone does not trigger story")
	worker.global_position = game.get_node("WorkshopWalls/OutletApproach").global_position
	await physics_frame
	check(worker.pickup_box(game.packed_boxes[0]), "Pick up finished crate")
	worker.sprite.flip_h = false
	check(game.welding_interaction.operate(), "Actual E interaction ships crate")
	check(game.score == 1 and game.packed_boxes.is_empty() and game.get_node("ShipmentSound").playing, "Score, shipment and audio commit before story")
	check(ui.is_active and worker.dialogue_locked and not paused, "Existing dialogue input lock is reused")
	check(ui.get_node("Root/Panel/Body").text == game.FIRST_ORDER_LINES[0].text, "First line appears immediately")
	check(portrait.texture == game.HAPPY_FRAMES.get_frame_texture(&"default", 0), "Happy starts at frame zero with first line")
	var bounds := Rect2(portrait.position, portrait.size)
	var before: Vector2 = worker.position
	Input.action_press("move_left")
	worker._physics_process(0.2)
	Input.action_release("move_left")
	check(worker.position == before and not game.welding_interaction.operate() and not game.drop_carried_box(), "Movement, production interaction and dropping are locked")
	check(not game._ship_carried_box(), "Cannot ship again during dialogue")
	ui._process(0.5)
	advance(ui)
	check(ui.get_node("Root/Panel/Body").text == game.FIRST_ORDER_LINES[1].text, "Second line matches")
	check(portrait.texture == game.HAPPY_FRAMES.get_frame_texture(&"default", 9), "Happy plays at 18 FPS; text advance does not restart it")
	game._try_first_order_dialogue()
	check(ui._index == 1 and is_equal_approx(ui._idle_elapsed, 0.5), "Repeated completion cannot restart story")
	if "--preview" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/first-order-happy-preview.png")
	ui._process(3.5)
	check(ui._index == 1 and portrait.texture == ui.idle_frames.get_frame_texture(&"default", 0), "Happy automatically enters Idle without advancing text")
	check(Rect2(portrait.position, portrait.size) == bounds, "Animation switch preserves portrait geometry")
	ui._process(1.0)
	check(portrait.texture == ui.idle_frames.get_frame_texture(&"default", 12), "Idle continues looping")
	advance(ui)
	check(ui.get_node("Root/Panel/Name").text == "主角" and ui.get_node("Root/Panel/Body").text == "那接下来呢？", "Player line uses existing speaker fields")
	advance(ui)
	check(ui.get_node("Root/Panel/Body").text == game.FIRST_ORDER_LINES[3].text, "Worker introduction line matches")
	advance(ui)
	check(ui.is_active and worker.dialogue_locked and ui.get_node("Root/Panel/Name").text == "主角" and ui.get_node("Root/Panel/Body").text == "那我呢？", "Added player line keeps dialogue active")
	advance(ui)
	check(ui.get_node("Root/Panel/Name").text == "徐知夏" and ui.get_node("Root/Panel/Body").text == "你要先学会观察。", "New final assistant line matches")
	advance(ui)
	check(not ui.is_active and not worker.dialogue_locked and ui._opening_frames == null, "Finish restores controls and clears one-shot animation")
	make_crate(game)
	await physics_frame
	check(worker.pickup_box(game.packed_boxes[0]), "Controls restored for next shipment")
	worker.sprite.flip_h = false
	check(game.welding_interaction.operate() and game.score == 2 and not ui.is_active, "Later shipment scores normally without repeating story")
	# 快速关闭及下一段普通对话也不遗留 Happy 状态。
	ui.start_dialogue(game.FIRST_ORDER_LINES, game.HAPPY_FRAMES)
	for i in game.FIRST_ORDER_LINES.size():
		advance(ui)
	check(not worker.dialogue_locked, "Fast advance releases lock before Happy finishes")
	game.play_test_dialogue()
	check(portrait.texture == ui.idle_frames.get_frame_texture(&"default", 0), "Subsequent ordinary dialogue starts Idle")
	ui.finish_dialogue()
	game.queue_free()
	await process_frame
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.score = 1
	game._try_first_order_dialogue()
	check(not game.dialogue_ui.is_active, "Same game flow survives workshop reinstantiation without replay")
	game.queue_free()
	await process_frame
	print("First order dialogue checks; failures=", failures)
	quit(1 if failures else 0)
