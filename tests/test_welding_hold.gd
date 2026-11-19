extends SceneTree
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func key(interaction: Node, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	interaction._unhandled_key_input(event)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for scenario in ["held", "released", "left", "dialogue", "focus_out"]:
		var game = load("res://Main.tscn").instantiate()
		root.add_child(game)
		game.get_node("TickTimer").stop()
		var worker = game.get_node("Worker")
		worker.set_physics_process(false)
		var interaction = game.welding_interaction
		interaction.set_physics_process(false)
		var machine = game.get_welding_machines()[0]
		worker.position = machine.position + Vector2(32, -32)
		key(interaction, true)
		check(not machine.processing, "Empty machine waits")
		machine.accept_cell()
		interaction._physics_process(0.1)
		check(not machine.processing, "One cell still waits")
		match scenario:
			"released": key(interaction, false)
			"left":
				worker.position = Vector2(32, 32)
				interaction._physics_process(0.1)
				worker.position = machine.position + Vector2(32, -32)
			"dialogue":
				game.play_test_dialogue()
				game.dialogue_ui.finish_dialogue()
			"focus_out": interaction._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		# 真正沿输入带送来第二个电芯。
		var input: Vector2i = game.world_to_cell(machine.global_position) + Vector2i.LEFT
		game.items.append({"pos": input, "prev_pos": input, "progress": 1.0})
		game._on_tick()
		interaction._physics_process(0.016)
		check(machine.processing == (scenario == "held"), "Held start / cancellation: " + scenario)
		if scenario == "held":
			check(worker.operating and machine.elapsed == 0.0, "Automatic start uses existing animation and full duration")
			interaction._physics_process(0.7)
			key(interaction, false)
			check(not machine.processing and machine.cells == 2, "Release cancels without losing cells")
			key(interaction, true)
			interaction._physics_process(2.0)
			machine.confirm_output()
			machine.accept_cell()
			machine.accept_cell()
			interaction._physics_process(0.1)
			check(not machine.processing, "Completed operation does not auto-repeat")
		game.queue_free()
		await process_frame
	print("Welding held-key checks; failures=", failures)
	quit(1 if failures else 0)
