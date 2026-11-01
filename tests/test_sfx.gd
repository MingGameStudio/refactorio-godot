extends SceneTree
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	game.set_process(false)
	game.welding_interaction.set_physics_process(false)
	var worker = game.get_node("Worker")
	worker.set_physics_process(false)
	var source = game.get_node("BuildingLayer/SourceMachine")
	source.set_process(false)
	var machine = game.get_welding_machines()[0]
	var pickup: AudioStreamPlayer = worker.get_node("PickupSound")
	var insert: AudioStreamPlayer = source.get_node("InsertSound")
	var pulse: AudioStreamPlayer = machine.get_node("PulseSound")
	var complete: AudioStreamPlayer = machine.get_node("CompleteSound")
	var shipment: AudioStreamPlayer = game.get_node("ShipmentSound")
	check(AudioServer.get_bus_index("SFX") >= 0, "SFX bus exists")
	for sound in [pickup, insert, pulse, complete, shipment]:
		check(sound.stream != null and not sound.playing and sound.bus == &"SFX" and sound.max_polyphony == 1, "Sound configured without autoplay or overlapping voices")
		check(sound.stream is AudioStreamWAV and sound.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Effects are one-shot WAVs")
	check(not source.accept_box(worker) and not insert.playing, "Empty-handed delivery is silent")
	worker.global_position = game.get_node("Box").global_position + Vector2(0, 32)
	await physics_frame
	await process_frame
	check(worker.pickup_box(game.get_node("Box")) and pickup.playing, "Successful pickup plays sound")
	pickup.stop()
	check(not worker.pickup_box(game.get_node("Box")) and not pickup.playing, "Repeated pickup does not replay")
	worker.global_position = source.delivery_position()
	worker.sprite.flip_h = false
	check(source.accept_box(worker) and insert.playing, "Successful insertion plays sound")
	insert.stop()
	check(not source.accept_box(worker) and not insert.playing, "Rejected insertion is silent")
	check(not machine.begin_operation(worker) and not pulse.playing, "Missing materials is silent")
	machine.accept_cell()
	machine.accept_cell()
	check(machine.begin_operation(worker) and pulse.playing, "First sparks play pulse")
	pulse.stop()
	check(not machine.begin_operation(worker) and not pulse.playing, "Repeated start during operation is silent")
	machine.advance_operation(0.29, worker, true)
	check(not pulse.playing, "No pulse between bursts")
	machine.advance_operation(0.02, worker, true)
	check(pulse.playing, "Periodic sparks play pulse")
	machine.cancel_operation()
	pulse.stop()
	machine.advance_operation(1.0, worker, true)
	check(not pulse.playing and not complete.playing, "Cancelled operation does not trigger sounds")
	machine.begin_operation(worker)
	pulse.stop()
	machine.advance_operation(0.4, worker, false)
	check(not pulse.playing and not complete.playing, "Leaving range cancels before a new pulse")
	machine.begin_operation(worker)
	machine.advance_operation(2.0, worker, true)
	check(complete.playing and machine.output_pending, "Completion plays sound")
	complete.stop()
	machine.advance_operation(2.0, worker, true)
	check(not machine.begin_operation(worker) and not complete.playing, "Finished progress does not replay completion")
	machine.confirm_output()
	machine.accept_cell()
	machine.accept_cell()
	machine.begin_operation(worker)
	machine.advance_operation(2.0, worker, true)
	check(complete.playing, "Next production cycle plays completion again")
	machine.confirm_output()
	var before: Vector2i = game.SINK_POS + Vector2i.LEFT
	game.items = [{"kind": "battery_set", "pos": before, "prev_pos": before, "progress": 1.0}]
	game._on_tick()
	check(game.score == 0 and not shipment.playing, "Entering shipping cell is not settlement")
	game._on_tick()
	check(game.score == 1 and game.items.is_empty() and shipment.playing, "Settlement plays success once")
	shipment.stop()
	game._on_tick()
	check(game.score == 1 and not shipment.playing, "Settled product cannot play again")
	for sound in [pickup, insert, pulse, complete, shipment, game.get_node("BackgroundMusic")]:
		sound.stop()
	# 给音频线程时间释放播放实例，再退出无界面测试。
	await create_timer(0.1).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("SFX checks completed: %d failures" % failures)
	quit(1 if failures else 0)
