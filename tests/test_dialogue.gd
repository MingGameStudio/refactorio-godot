extends SceneTree

var failures: int = 0
var finished_count: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("_run")

func space(pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = pressed
	event.echo = echo
	root.push_input(event)

func _run() -> void:
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var ui = main.dialogue_ui
	var worker = main.get_node("Worker")
	ui.dialogue_finished.connect(func(): finished_count += 1)
	check(not ui.visible and not worker.dialogue_locked, "Initially hidden and unlocked")
	check(not ui.start_dialogue([]), "Empty input does not lock gameplay")
	worker.move_to(worker.global_position + Vector2(0, 64))
	main.play_test_dialogue()
	check(ui.visible and ui.is_active and worker.dialogue_locked, "Dialogue locks player")
	var portrait: TextureRect = ui.get_node("Root/Portrait")
	check(portrait.texture == ui.idle_frames.get_frame_texture(&"default", 0), "Dialogue starts idle")
	ui._process(1.0)
	check(portrait.texture == ui.idle_frames.get_frame_texture(&"default", 12), "Dialogue idle advances")
	ui._process(49.0)
	check(portrait.texture == ui.idle_frames.get_frame_texture(&"default", 12), "Dialogue idle loops")
	check(not paused and main.can_process(), "Scene tree keeps running")
	check(worker._path.is_empty(), "Pending navigation is cancelled")
	check(not worker.move_to(worker.global_position + Vector2(0, 64)), "Navigation blocked")
	check(not main.welding_interaction.operate(), "Interaction blocked")
	var before: Vector2 = worker.position
	Input.action_press("move_right")
	worker._physics_process(0.1)
	check(worker.position == before, "Held movement cannot bypass lock")
	Input.action_release("move_right")
	check(not ui.start_dialogue([{"text": "replacement"}]), "Active dialogue cannot be overwritten")
	space(true)
	check(ui.get_node("Root/Panel/Body").text.begins_with("刚好"), "Space advances to second line")
	check(portrait.texture == ui.idle_frames.get_frame_texture(&"default", 12), "Next line preserves idle playback")
	space(true, true)
	space(true)
	check(ui.is_active and finished_count == 0, "Holding space cannot skip more lines")
	space(false)
	space(true)
	check(not ui.visible and not worker.dialogue_locked, "Last line hides and unlocks")
	check(finished_count == 1, "Finished signal fires once")
	var hidden_texture := portrait.texture
	ui._process(1.0)
	check(portrait.texture == hidden_texture, "Hidden dialogue stops animation")
	space(false)
	ui.finish_dialogue()
	check(finished_count == 1, "Finish is idempotent")
	main.play_test_dialogue()
	if "--preview" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/dialogue-preview.png")
	ui.finish_dialogue()
	check(not worker.dialogue_locked, "Replay restores controls")
	var welder = main.get_welding_machines()[0]
	welder.accept_cell()
	welder.accept_cell()
	worker.position = welder.to_global(Vector2(32, -32))
	check(main.welding_interaction.operate(), "Interaction restored after dialogue")
	main._drag_active = true
	main.play_test_dialogue()
	check(welder.processing and welder.cells == 2, "Dialogue does not cancel autonomous welding")
	check(not main._drag_active, "Opening cancels unfinished mouse gesture")
	ui.finish_dialogue()
	for window_size in [Vector2i(800, 600), Vector2i(1600, 900)]:
		root.size = window_size
		await process_frame
		await process_frame
		var panel: Control = ui.get_node("Root/Panel")
		var bounds: Rect2 = panel.get_global_transform() * Rect2(Vector2.ZERO, panel.size)
		var viewport_size := root.get_visible_rect().size
		check(is_equal_approx(panel.scale.x, panel.scale.y), "Uniform background scaling")
		check(bounds.position.x >= 0 and bounds.end.x <= viewport_size.x + 1, "Panel stays within resized viewport")
		check(absf(bounds.end.y - (viewport_size.y - 16)) < 1, "Panel stays bottom anchored")
	main.queue_free()
	await process_frame
	print("Dialogue tests: %d failures" % failures)
	quit(1 if failures else 0)
