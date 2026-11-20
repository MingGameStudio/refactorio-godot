extends SceneTree
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func key(interaction: Node, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	event.echo = echo
	interaction._unhandled_key_input(event)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 4.0
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	var worker = game.get_node("Worker")
	var machine = game.get_welding_machines()[0]
	var interaction = game.welding_interaction
	worker.position = Vector2(416, 224)
	interaction._physics_process(0.0)
	check(not machine.get_node("Prompt").visible, "Insufficient input has no E prompt")
	key(interaction, true)
	check(not machine.processing, "Insufficient input cannot start")
	machine.accept_cell()
	machine.accept_cell()
	await physics_frame
	check(not machine.processing, "Old held key does not arm a future batch")
	interaction._physics_process(0.0)
	check(machine.get_node("Prompt").visible and machine.get_node("Prompt").text == "E 点焊", "Ready prompt")
	key(interaction, false)
	key(interaction, true)
	key(interaction, false)
	check(machine.processing and not worker.operating and machine.get_node("PulseSound").playing, "Tap starts autonomous cycle and leaves player free")
	check(not machine.get_node("Prompt").visible, "Processing hides prompt")
	for i in 8:
		key(interaction, true)
		key(interaction, true, true)
		key(interaction, false)
	check(machine.cells == 2 and machine.elapsed == 0.0, "Repeated E neither resets nor consumes twice")
	Input.action_press("move_left")
	var before: Vector2 = worker.position
	await create_timer(0.25).timeout
	Input.action_release("move_left")
	check(worker.position.x < before.x and machine.processing and machine.elapsed > 0.0, "Actual physics advances machine while WASD moves player")
	worker.global_position = game._box.pickup_approach()
	await physics_frame
	key(interaction, true)
	key(interaction, false)
	check(worker.carrying_box and machine.processing, "Can pick up a box while welder runs")
	worker.position = Vector2(320, 160)
	worker.sprite.flip_h = false
	check(game.drop_carried_box(), "Can drop box while welder runs")
	var output: Vector2i = game.world_to_cell(machine.position) + Vector2i.RIGHT
	game._clear_building(output)
	await create_timer(3.1).timeout
	check(not machine.processing and machine.cells == 0 and machine.output_pending and machine.elapsed == 3.0, "Autonomous three-second cycle creates exactly one product after leaving")
	check(not machine.get_node("SparkOrigin/WeldingSparks").emitting, "Regular sparks stop at completion")
	for i in 3:
		game._on_tick()
	check(machine.output_pending and game.items.is_empty(), "Blocked output preserves product")
	game._set_building(output, game.Building.BELT)
	game._on_tick()
	check(not machine.output_pending and game.items.size() == 1, "Unblocked output emits once")
	for i in 6:
		game._on_tick()
	check(game._packing_machine.battery_count == 1, "Product enters existing packing flow")
	# 后四次周期用机器自身的物理入口推进，精确验证 3 秒边界。
	machine.set_physics_process(false)
	for cycle in 4:
		machine.accept_cell()
		machine.accept_cell()
		worker.position = Vector2(416, 224)
		interaction._physics_process(0.1)
		check(not machine.processing, "Next batch requires a fresh press")
		key(interaction, true)
		key(interaction, false)
		game.play_test_dialogue()
		check(machine.processing, "Dialogue does not cancel an already started machine")
		game.dialogue_ui.finish_dialogue()
		machine._physics_process(2.99)
		check(machine.processing and machine.cells == 2, "No early completion")
		machine._physics_process(0.01)
		check(machine.output_pending and machine.cells == 0 and machine.get_node("CompleteSound").playing, "Exactly one completion with existing sound")
		machine._physics_process(3.0)
		for i in 7:
			game._on_tick()
	check(game.packed_boxes.size() == 1 and game.score == 0, "Five manual starts produce one unshipped crate")
	check(game.get_node("UI/OrderHUD/Panel/PackingCount").text == "5/5" and game.get_node("UI/OrderHUD/Panel/DeliveryCount").text == "0/1", "Order HUD remains correct")
	print("Automatic welding checks; failures=", failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
