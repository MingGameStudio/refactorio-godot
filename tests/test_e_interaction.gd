extends SceneTree
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func press_e(interaction: Node, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	event.echo = echo
	interaction._unhandled_key_input(event)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	game.set_process(false)
	var worker = game.get_node("Worker")
	worker.set_physics_process(false)
	var source = game._source_machine
	source.set_process(false)
	var interaction = game.welding_interaction
	interaction.set_physics_process(false)
	var box = game._box
	await physics_frame
	press_e(interaction)
	check(not worker.carrying_box and box.visible, "Distant E does not pick up or walk")
	check(not interaction._frame.visible, "No frame without available interaction")
	game._set_building(Vector2i(8, 3), game.Building.BELT)
	worker.position = Vector2(500, 224)
	await physics_frame
	press_e(interaction)
	check(not worker.carrying_box and box.visible, "E cannot pick up through a facility")
	game._clear_building(Vector2i(8, 3))
	worker.position = box.position + Vector2(-36, -7)
	await physics_frame
	interaction._physics_process(0.0)
	check(interaction._hint.text == "E 拾取箱子", "Nearby pickup prompt")
	check(interaction._frame.visible and interaction._frame.global_position.is_equal_approx(box.to_global(box.get_rect().get_center())), "Frame encloses nearby box including its sprite offset")
	press_e(interaction, true)
	check(not worker.carrying_box, "Key repeat does not pick up")
	worker.move_to(Vector2(480, 160))
	press_e(interaction)
	check(worker.carrying_box and not box.visible and worker.carried_box.visible, "E picks up at arbitrary nearby coordinate")
	check(not interaction._frame.visible, "Picked-up box frame disappears immediately")
	check(worker._path.is_empty() and worker._pickup_target == null, "Pickup cancels queued path")
	press_e(interaction)
	check(worker.carrying_box and not source.feeding, "Repeated distant E does not discard box")
	for offset in [Vector2(0, -64), Vector2(0, 64), Vector2(64, 0)]:
		worker.position = source.input_position() + offset
		press_e(interaction)
		check(worker.carrying_box and not source.feeding, "Wrong side cannot deliver")
	worker.position = source.get_node("InputBelt").to_global(Vector2(-16, 40))
	worker.sprite.flip_h = true
	interaction._physics_process(0.0)
	check(interaction._hint.text == "E 投料", "Left-side delivery prompt away from cell center")
	check(interaction._frame.visible and interaction._frame.global_position.is_equal_approx(source.input_position()), "Delivery frame marks input belt rather than whole machine")
	press_e(interaction)
	check(source.feeding and not worker.carrying_box and not worker.sprite.flip_h, "E turns right and transfers box")
	check(source.capacity == 0 and not worker.carried_box.visible, "No premature capacity credit")
	check(interaction._hint.text.is_empty(), "Prompt cleared after successful transfer")
	check(not interaction._frame.visible, "Delivery frame disappears after transfer")
	press_e(interaction)
	source._process(1.0)
	check(source.capacity == 10, "One E delivery credits exactly ten on arrival")
	source._process(1.0)
	check(source.capacity == 10, "Repeated E does not duplicate supply")
	# 同一按键仍可操作点焊机。
	var welder = game.get_welding_machines()[0]
	worker.position = welder.to_global(Vector2(32, -32))
	interaction._physics_process(0.0)
	check(not interaction._frame.visible, "Unloaded welder is not highlighted as operable")
	welder.accept_cell()
	welder.accept_cell()
	worker.position = welder.to_global(Vector2(32, -32))
	interaction._physics_process(0.0)
	check(interaction._frame.visible, "Ready welder is highlighted")
	press_e(interaction)
	check(welder.processing and worker.operating, "E welding remains available")
	check(not interaction._frame.visible, "Processing welder frame is hidden")
	interaction._physics_process(2.0)
	check(welder.output_pending, "Welding still completes")
	check(not interaction._frame.visible, "Pending output cannot be highlighted for another operation")
	game.queue_free()
	await process_frame
	print("E interaction checks completed: %d failures" % failures)
	quit(1 if failures else 0)
