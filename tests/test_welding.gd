extends SceneTree
const PhysicsSteps = preload("res://tests/physics_steps.gd")

var failures := 0
var game: Node2D
var machine: Node2D
var worker: Node2D
var interaction: Node
const INPUT := Vector2i(5, 4)
const MACHINE := Vector2i(6, 4)
const OUTPUT := Vector2i(7, 4)

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func inject(cell: Vector2i, kind: String = "cell") -> void:
	game.items.append({"kind": kind, "pos": cell, "prev_pos": cell, "progress": 1.0})

func press_e(echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	event.echo = echo
	interaction._unhandled_key_input(event)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.physics_ticks_per_second = 120
	Engine.time_scale = 4.0
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	game.set_process(false)
	worker = game.get_node("Worker")
	worker.set_physics_process(false)
	var frames: SpriteFrames = worker.sprite.sprite_frames
	check(frames.get_frame_count(&"interact") == 5 and frames.get_animation_loop(&"interact"), "Operation animation loops five frames")
	var frame_offsets := [0.0, 168.0, 339.0, 168.0, 0.0]
	for i in 5:
		var texture: AtlasTexture = frames.get_frame_texture(&"interact", i)
		check(texture.region.position.x == frame_offsets[i] and texture.get_size() == Vector2(216, 262), "Operation frames follow A-B-C-B-A with aligned canvases")
	machine = game.buildings[MACHINE.x][MACHINE.y].node
	interaction = game.welding_interaction
	interaction.set_physics_process(false)
	check(game.occupancy.is_blocked(MACHINE) and game.navigation.is_point_solid(MACHINE), "Welder blocks navigation")
	check(is_equal_approx(machine.get_node("Sprite2D").texture.get_height() * machine.get_node("Sprite2D").scale.y, 124.8), "Machine display scale matches existing machines")
	worker.position = Vector2(416, 224)
	interaction._physics_process(0.0)
	check(machine.get_node("Prompt").visible, "Nearby prompt visible")
	press_e()
	check(not machine.processing, "Insufficient materials cannot start")
	inject(INPUT, "battery_set")
	game._on_tick()
	check(machine.cells == 0 and game.items.size() == 1, "Non-cell input is rejected without loss")
	game.items.clear()
	game._set_building(OUTPUT, game.Building.BELT, game.Dir.LEFT)
	inject(OUTPUT)
	game._on_tick()
	check(machine.cells == 0 and game.items.size() == 1, "Right-side input rejected")
	game.items.clear()
	game._set_building(OUTPUT, game.Building.BELT, game.Dir.RIGHT)
	for i in 2:
		inject(INPUT)
		game._on_tick()
	check(machine.cells == 2 and game.items.is_empty(), "Two belt cells transfer into buffer exactly once")
	inject(INPUT)
	game._on_tick()
	check(machine.cells == 2 and game.items.size() == 1, "Full buffer backpressures incoming belt")
	press_e(true)
	check(not machine.processing, "Key repeat cannot start")
	press_e()
	interaction._physics_process(1.0)
	check(worker.sprite.animation == &"interact", "Successful E operation starts interaction animation")
	worker.sprite.set_frame_and_progress(2, 0.4)
	worker._physics_process(0.0)
	interaction._physics_process(0.0)
	check(worker.sprite.frame == 2 and is_equal_approx(worker.sprite.frame_progress, 0.4), "Physics updates do not restart interaction frames")
	press_e()
	check(machine.processing and is_equal_approx(machine.elapsed, 1.0) and machine.cells == 2, "Repeated press does not reset processing or consume early")
	worker.position = Vector2(32, 32)
	interaction._physics_process(1.0)
	check(not machine.processing and machine.cells == 2 and not machine.output_pending, "Leaving cancels without consuming")
	check(not worker.operating and worker.sprite.animation == &"idle", "Cancellation restores idle")
	check(not machine.get_node("Prompt").visible, "Far prompt hidden")
	worker.position = Vector2(416, 224)
	interaction._physics_process(3.0)
	check(not machine.processing, "Returning does not automatically restart")
	press_e()
	interaction._physics_process(1.99)
	check(machine.processing and machine.cells == 2, "Must complete full two seconds")
	interaction._physics_process(0.01)
	check(machine.output_pending and machine.cells == 0 and not machine.processing, "Two cells become exactly one pending product")
	check(not worker.operating and worker.sprite.animation == &"idle", "Completion restores idle")
	game._clear_building(OUTPUT)
	game._on_tick()
	check(machine.output_pending and machine.cells == 1, "Missing output retains product; waiting third cell accepted")
	game._set_building(OUTPUT, game.Building.BELT, game.Dir.LEFT)
	inject(OUTPUT)
	inject(INPUT)
	game._on_tick()
	check(machine.output_pending and machine.cells == 2 and game.items.size() == 1, "Occupied output preserves product and bounded input buffer")
	press_e()
	check(not machine.processing, "Pending product prevents next operation")
	game._clear_building(MACHINE)
	check(game.buildings[MACHINE.x][MACHINE.y].node == machine, "Dismantle cannot lose stored items")
	game._place_belt_path([{"pos": MACHINE, "dir": game.Dir.RIGHT}])
	check(game.buildings[MACHINE.x][MACHINE.y].node == machine, "Belt drag cannot overwrite machine")
	game.items.clear() # 模拟下游释放出口。
	game._set_building(OUTPUT, game.Building.BELT, game.Dir.RIGHT)
	game._on_tick()
	check(not machine.output_pending and game.items.size() == 1 and game.items[0].kind == "battery_set" and game.items[0].pos == OUTPUT, "Free output receives one typed product")
	interaction._physics_process(5.0)
	check(not machine.processing and machine.cells == 2, "No automatic second cycle")
	for i in 6:
		game._on_tick()
	check(game.score == 1 and game.items.is_empty(), "Product travels to sink once")
	press_e()
	interaction._physics_process(0.5)
	check(game.move_welder(machine, Vector2i(8, 6)), "Machine can move with materials")
	check(machine.cells == 2 and not machine.processing and game.occupancy.is_walkable(MACHINE), "Move cancels work and preserves stock")
	check(game.occupancy.is_blocked(Vector2i(8, 6)), "New placement updates occupancy")
	worker.position = Vector2(544, 352)
	press_e()
	interaction._physics_process(2.0)
	check(machine.output_pending, "Moved machine can be operated")
	game._set_building(Vector2i(9, 6), game.Building.BELT)
	game._on_tick()
	check(not machine.output_pending and machine.cells == 0, "Moved output follows machine")
	game._clear_building(Vector2i(8, 6))
	check(game.occupancy.is_walkable(Vector2i(8, 6)), "Empty machine can be dismantled")
	game._set_building(Vector2i(4, 6), game.Building.WELDER)
	check(game.buildings[4][6].node.has_method("begin_operation"), "Runtime placement creates functional machine")
	game.queue_free()
	await process_frame
	# 完整生产线：真实搬箱投料后，逐轮人工操作；每一步检查原料守恒。
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	game.set_process(false)
	worker = game.get_node("Worker")
	worker.set_physics_process(false)
	machine = game.buildings[MACHINE.x][MACHINE.y].node
	interaction = game.welding_interaction
	interaction.set_physics_process(false)
	var source = game.get_node("BuildingLayer/SourceMachine")
	source.set_process(false)
	worker.request_pickup(game.get_node("Box"))
	await PhysicsSteps.advance(worker, 10.0)
	game._request_box_delivery()
	await PhysicsSteps.advance(worker, 10.0)
	source._process(1.0)
	check(source.capacity == 10, "End-to-end: box feeds ten capacity")
	worker.move_to(Vector2(416, 224))
	await PhysicsSteps.advance(worker, 10.0)
	var operations := 0
	for i in 120:
		game._on_tick()
		if machine.cells == 2 and not machine.output_pending and not machine.processing:
			press_e()
			if machine.processing:
				operations += 1
		interaction._physics_process(0.5)
		var units: int = source.capacity + machine.cells + (2 if machine.output_pending else 0) + game.score * 2
		for item in game.items:
			units += 2 if item.get("kind", "cell") == "battery_set" else 1
		check(units == 10, "Material conservation throughout complete production line")
	check(operations == 5 and game.score == 5 and game.items.is_empty() and source.capacity == 0 and machine.cells == 0 and not machine.output_pending, "Ten cells produce five components through five manual operations")
	game.queue_free()
	await process_frame
	print("Welding checks completed: %d failures" % failures)
	# 等待音频线程释放刚删除场景的播放实例。
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
