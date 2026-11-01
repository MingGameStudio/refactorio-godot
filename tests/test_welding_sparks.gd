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
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	game.set_process(false)
	var worker = game.get_node("Worker")
	worker.set_physics_process(false)
	worker.position = Vector2(416, 224)
	var machine = game.get_welding_machines()[0]
	var interaction = game.welding_interaction
	interaction.set_physics_process(false)
	var normal: GPUParticles2D = machine.get_node("SparkOrigin/WeldingSparks")
	var complete: GPUParticles2D = machine.get_node("SparkOrigin/CompletionSparks")
	var progress: ProgressBar = machine.get_node("ProgressBar")
	check(not progress.visible and progress.step == 0.0 and not progress.show_percentage, "Idle progress hidden and continuous without percentage")
	var normal_id := normal.get_instance_id()
	var complete_id := complete.get_instance_id()
	check(normal.one_shot and complete.one_shot and normal.explosiveness == 1.0 and complete.explosiveness == 1.0, "One-shot bursts rather than continuous emission")
	check(normal.amount == 8 and complete.amount == 18, "Separate regular and completion particle counts")
	check(normal.process_material is ParticleProcessMaterial and complete.process_material is ParticleProcessMaterial, "Built-in process materials")
	check(normal.texture is GradientTexture2D and normal.texture.resource_path.begins_with("res://WeldingMachine.tscn::"), "Square generated inside scene, no external art")
	check(not normal.emitting and not complete.emitting, "Idle produces no sparks")
	key(interaction, true)
	check(not normal.emitting, "Missing materials produces no sparks")
	machine.accept_cell()
	machine.accept_cell()
	key(interaction, true)
	check(machine.processing and normal.emitting and not complete.emitting, "Start immediately emits regular sparks")
	check(progress.visible and progress.value == 0.0, "Progress appears at start")
	if "--preview" in OS.get_cmdline_user_args():
		interaction._physics_process(1.0)
		await create_timer(0.08).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/welding-sparks-preview.png")
		interaction._physics_process(1.0)
		await create_timer(0.08).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/welding-completion-preview.png")
		game.queue_free()
		await process_frame
		await create_timer(0.2).timeout
		quit()
		return
	# 清除 emitting 标志仅用于观察下一次触发；正式取消逻辑不清空已有粒子。
	normal.emitting = false
	interaction._physics_process(0.29)
	check(is_equal_approx(progress.value, 0.145), "Progress tracks actual processing without quantization")
	check(not normal.emitting, "No early periodic burst")
	interaction._physics_process(0.02)
	check(normal.emitting, "Burst follows elapsed processing at roughly 0.3 seconds")
	key(interaction, false)
	check(not progress.visible and progress.value == 0.0, "Release hides and resets progress with operation")
	check(not machine.processing and machine.cells == 2 and normal.emitting, "Release cancels processing without clearing already emitted particles")
	normal.emitting = false
	interaction._physics_process(1.0)
	check(not normal.emitting and not complete.emitting, "Cancelled operation cannot emit new bursts")
	key(interaction, true)
	normal.emitting = false
	worker.position = Vector2(32, 32)
	interaction._physics_process(0.4)
	check(not machine.processing and not normal.emitting and not complete.emitting, "Leaving cancels before overdue burst")
	worker.position = Vector2(416, 224)
	key(interaction, true)
	normal.emitting = false
	interaction._physics_process(2.0)
	check(machine.output_pending and machine.cells == 0 and complete.emitting and not normal.emitting, "Successful completion emits only larger completion burst")
	check(progress.visible and progress.value == 1.0, "Completion shows full bar for flash")
	await create_timer(0.2).timeout
	check(not progress.visible and progress.modulate == Color.WHITE, "Completion flash restores brightness and hides")
	complete.emitting = false
	interaction._physics_process(1.0)
	key(interaction, true)
	check(not normal.emitting and not complete.emitting, "Waiting output does not repeat completion or start sparks")
	check(normal.get_instance_id() == normal_id and complete.get_instance_id() == complete_id, "Emitter nodes reused throughout all operations")
	game.queue_free()
	await process_frame
	print("Welding spark checks completed: %d failures" % failures)
	# 等待音频线程释放刚删除场景的播放实例。
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
