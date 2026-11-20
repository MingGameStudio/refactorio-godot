extends SceneTree
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func inspect_controls(node: Node) -> void:
	if node is Control:
		check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD does not intercept mouse: " + str(node.name))
	if node is TextureRect:
		check(node.texture is AtlasTexture and node.texture.filter_clip, "Independent clipped atlas texture")
	for child in node.get_children():
		inspect_controls(child)

func state(hud: Control, delivery: String, packing: int) -> void:
	check(hud.get_node("Panel/DeliveryCount").text == delivery, "Delivery count " + delivery)
	check(hud.get_node("Panel/PackingCount").text == "%d/5" % packing, "Packing count %d" % packing)
	for i in 5:
		check(hud.get_node("Panel/ProgressBar/Fill%d" % (i + 1)).visible == (i < packing), "Fill segment %d" % i)

func capture(tag: String) -> void:
	if "--preview" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/order-hud-%s.png" % tag)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	var worker = game.get_node("Worker")
	worker.set_physics_process(false)
	var hud: Control = game.get_node("UI/OrderHUD")
	await process_frame
	inspect_controls(hud)
	check(not game.get_node("UI/ScoreLabel").visible, "Old status replaced")
	state(hud, "0/1", 0)
	await capture("initial")
	var welder = game.get_welding_machines()[0]
	welder.accept_cell()
	welder.accept_cell()
	welder.begin_operation(worker)
	welder.advance_operation(3.0, worker, true)
	game._update_score_label()
	state(hud, "0/1", 0) # 点焊完成不等于进入装箱台。
	welder.confirm_output()
	for i in 5:
		var before: Vector2i = game.SINK_POS + Vector2i.LEFT
		game.items.append({"kind": "battery_set", "pos": before, "prev_pos": before, "progress": 1.0})
		game._on_tick()
		state(hud, "0/1", i)
		game._on_tick()
		state(hud, "0/1", i + 1)
		if i == 0 or i == 2:
			await capture(str(i + 1))
	check(game._packing_machine.battery_count == 0 and game.packed_boxes.size() == 1, "Existing packing consumes batch normally")
	check(hud.get_node("Panel/PackingTitle").text == "装箱完成", "Packed crate retains completed presentation")
	await capture("packed")
	worker.global_position = game.get_node("WorkshopWalls/OutletApproach").global_position
	await physics_frame
	check(worker.pickup_box(game.packed_boxes[0]), "Pickup succeeds")
	game._update_score_label()
	state(hud, "0/1", 5)
	worker.sprite.flip_h = false
	check(game.welding_interaction.operate(), "Existing shipping interaction succeeds")
	state(hud, "1/1", 5)
	check(game.dialogue_ui.is_active and game.score == 1, "First-order story and scoring still work")
	game.dialogue_ui.finish_dialogue()
	await capture("delivered")
	var position_before: Vector2 = hud.get_node("Panel").global_position
	game.get_node("Camera2D").position += Vector2(100, 80)
	await process_frame
	check(hud.get_node("Panel").global_position == position_before, "HUD is independent of camera")
	for window_size in [Vector2i(800, 600), Vector2i(1920, 1080)]:
		root.size = window_size
		await process_frame
		await process_frame
		var panel: Control = hud.get_node("Panel")
		var bounds := panel.get_global_transform() * Rect2(Vector2.ZERO, hud.DESIGN_SIZE)
		check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(bounds), "HUD fits resized viewport")
		check(is_equal_approx(panel.scale.x, panel.scale.y), "Uniform HUD scaling")
	hud.target_boxes = 2
	hud.refresh(game)
	state(hud, "1/2", 0)
	check(hud.get_node("Panel/Description").text == "生产并交付 2 箱电池组", "Future multi-box target is configurable")
	print("Order HUD checks; failures=", failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
