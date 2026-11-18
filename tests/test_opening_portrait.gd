extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://Game.tscn").instantiate()
	root.add_child(game)
	var worker = game.get_node("Main/Worker")
	var initial_position: Vector2 = worker.position
	check(paused and not worker.can_process(), "Player stays frozen during entrance")
	check(not game.has_node("OpeningPortrait"), "Portrait waits for assistant")
	var start_x: float = game.assistant.position.x
	check((game.assistant.get_global_transform_with_canvas() * Vector2.ZERO).x < 0.0, "Assistant starts offscreen left")
	game._process(0.5)
	check(game.assistant.position.x > start_x, "Assistant walks right")
	var ignored_click := InputEventMouseButton.new()
	ignored_click.button_index = MOUSE_BUTTON_LEFT
	ignored_click.pressed = true
	root.push_input(ignored_click)
	check(paused and not game.has_node("OpeningPortrait"), "Click cannot skip approach")
	game._process(10.0)
	check(worker.position == initial_position, "Entrance preserves player position")
	check(game.assistant.position.is_equal_approx(initial_position + Vector2(-52, 0)), "Assistant stops next to player")
	check(game.assistant.texture == game.IDLE_TEXTURE, "Scene assistant switches from walk to idle")
	var idle_rect: Rect2 = game.assistant.get_rect()
	var walk_scale: float = game.assistant_height / 464.0
	check(is_equal_approx(idle_rect.size.y * game.assistant.scale.y, 450.0 * walk_scale), "Idle matches walk standing height")
	check(is_equal_approx(idle_rect.end.y * game.assistant.scale.y, -12.0 * walk_scale), "Idle preserves walk foot baseline")
	var intro = game.get_node("OpeningPortrait")
	var main = game.get_node("Main")
	check(paused, "Opening pauses gameplay")
	check(intro.can_process() and not main.can_process(), "Only opening runs while paused")
	check(intro.frames.get_frame_count(&"default") == 54, "All 54 frames are included")
	var portrait = intro.get_node("Root/Portrait")
	intro._process(1.0)
	check(portrait.texture == intro.frames.get_frame_texture(&"default", 12), "Animation advances")
	intro._process(3.5)
	check(intro.idle_frames.get_frame_count(&"default") == 49, "All idle frames included")
	check(portrait.texture == intro.idle_frames.get_frame_texture(&"default", 0), "Enter transitions directly into idle")
	intro._process(1.0)
	check(portrait.texture == intro.idle_frames.get_frame_texture(&"default", 12), "Idle advances")
	intro._process(49.0)
	check(portrait.texture == intro.idle_frames.get_frame_texture(&"default", 12), "Idle loops")
	check(paused, "Completion still waits for click")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(400, 300)
	press.pressed = true
	root.push_input(press)
	check(paused, "Mouse press cannot reach gameplay")
	var release := press.duplicate()
	release.pressed = false
	root.push_input(release)
	await process_frame
	check(not paused, "Click restores gameplay")
	check(not is_instance_valid(intro), "Click removes portrait")
	check(not main._drag_active, "Dismiss click does not start a building gesture")
	game.queue_free()
	await process_frame
	# A click also skips the animation before its final frame.
	game = load("res://Game.tscn").instantiate()
	root.add_child(game)
	game._process(10.0)
	root.push_input(press)
	root.push_input(release)
	await process_frame
	check(not paused and not game.has_node("OpeningPortrait"), "Early click skips animation")
	game.queue_free()
	await process_frame
	print("Opening portrait failures: ", failures)
	quit(1 if failures else 0)
