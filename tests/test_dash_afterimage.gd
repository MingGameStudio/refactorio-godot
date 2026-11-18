extends SceneTree

var failures := 0
var worker: CharacterBody2D

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func tick() -> void:
	await physics_frame
	worker._physics_process(worker.get_physics_process_delta_time())

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.physics_ticks_per_second = 60
	var world := Node2D.new()
	world.position = Vector2(30, 40)
	world.scale = Vector2(1.3, 1.3)
	root.add_child(world)
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		worker = load("res://Worker.tscn").instantiate()
		world.add_child(worker)
		worker.set_physics_process(false)
		worker.position = Vector2(100, 65)
		# 设置冲刺状态后运行真实物理帧，输入触发由 test_dash 覆盖。
		worker._dash_direction = direction.normalized()
		worker._dash_remaining = worker.dash_duration
		for i in 2:
			await tick()
		check(worker._afterimages.is_empty(), "No ghost before 0.05 seconds")
		await tick()
		check(worker._afterimages.size() == 1, "One ghost at 0.05 seconds")
		var ghost: Sprite2D = worker._afterimages[0]
		check(ghost.get_parent() == world and ghost.get_child_count() == 0 and ghost.get_script() == null, "Ghost is a visual-only world sibling")
		check(ghost.texture == worker.sprite.sprite_frames.get_frame_texture("dash", 0), "Ghost uses current Dash frame")
		check(ghost.global_transform.is_equal_approx(worker.sprite.global_transform), "World position, scale and visual center match in every direction")
		check(ghost.flip_h == worker.sprite.flip_h and ghost.offset == worker.sprite.offset, "Facing and offset match")
		check(is_equal_approx(ghost.modulate.a, 0.55), "Initial opacity is 0.55")
		var snapshot := ghost.global_transform
		for i in 3:
			await tick()
		check(worker._afterimages.size() == 2, "Next ghost after another 0.05 seconds")
		check(ghost.global_transform.is_equal_approx(snapshot), "Ghost remains fixed while worker moves")
		check(ghost.z_index < worker.z_index, "Ghost remains behind worker when crossing rows")
		check(ghost.modulate.a < 0.55 and ghost.modulate.a > 0.0, "Tween progressively fades ghost")
		worker.set_dialogue_locked(true)
		var count: int = world.get_child_count()
		await tick()
		check(world.get_child_count() <= count, "Dialogue stops emission")
		# 删除角色后，世界内残影仍由自身 Tween 清理。
		worker.queue_free()
		await create_timer(0.28).timeout
		check(world.get_child_count() == 0, "All ghosts clean up after their fade even without worker")
	worker = load("res://Worker.tscn").instantiate()
	world.add_child(worker)
	worker.set_physics_process(false)
	worker._dash_direction = Vector2.RIGHT
	worker._dash_remaining = worker.dash_duration
	for i in 13:
		await tick()
	check(worker._dash_remaining == 0, "Dash ends normally")
	var finished_count: int = world.get_child_count()
	for i in 4:
		await tick()
	check(world.get_child_count() <= finished_count, "No emission after natural Dash end")
	await create_timer(0.28).timeout
	check(world.get_child_count() == 1, "Normal completion leaves no ghosts")
	worker.queue_free()
	await process_frame
	# 碰墙时停发残影，保持现有冲刺计时及碰撞行为。
	worker = load("res://Worker.tscn").instantiate()
	world.add_child(worker)
	worker.set_physics_process(false)
	var wall := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8, 200)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector2(50, 0)
	world.add_child(wall)
	await physics_frame
	worker._dash_direction = Vector2.RIGHT
	worker._dash_remaining = worker.dash_duration
	for i in 6:
		await tick()
	check(worker._afterimage_blocked and worker._dash_remaining > 0, "Collision stops emission without changing Dash state")
	var collision_count: int = world.get_child_count()
	for i in 3:
		await tick()
	check(world.get_child_count() <= collision_count, "No new ghosts after collision")
	worker._stop_dash()
	paused = true
	await create_timer(0.28, true).timeout
	check(world.get_child_count() == 2, "Existing ghosts clean up even while paused")
	paused = false
	world.queue_free()
	await process_frame
	print("Dash afterimage checks completed: %d failures" % failures)
	quit(1 if failures else 0)
