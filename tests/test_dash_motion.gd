extends SceneTree

var failures := 0
var worker: CharacterBody2D

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func release_keys() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "dash"]:
		Input.action_release(action)

func tick() -> void:
	await physics_frame
	worker._physics_process(worker.get_physics_process_delta_time())

func start_dash(direction: Vector2) -> void:
	await process_frame
	if direction.x != 0:
		Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y != 0:
		Input.action_press("move_down" if direction.y > 0 else "move_up")
	Input.action_press("dash")
	await tick()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.physics_ticks_per_second = 60
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		worker = load("res://Worker.tscn").instantiate()
		root.add_child(worker)
		worker.set_physics_process(false)
		worker.pathfinder = func(_from: Vector2, to: Vector2) -> PackedVector2Array: return PackedVector2Array([to])
		worker.move_to(Vector2(500, 500))
		await start_dash(direction)
		check(worker._path.is_empty(), "Dash cancels previous navigation")
		check(not worker.move_to(Vector2(-500, -500)), "Click navigation cannot override Dash")
		release_keys()
		Input.action_press("move_right" if direction.x <= 0 else "move_left")
		for i in 11:
			await tick()
		check(worker.global_position.is_equal_approx(direction.normalized() * 96.0), "Eight-way distance is 96 pixels with direction locked: %s" % direction)
		release_keys()
		await tick()
		check(worker.sprite.animation == &"idle" and worker.velocity == Vector2.ZERO, "Movement and pose end together")
		check(is_equal_approx(worker._dash_cooldown_remaining, 0.35), "Cooldown begins after Dash ends")
		check(worker.move_to(Vector2(500, 500)), "Navigation works after Dash")
		worker.queue_free()
		await process_frame
	# 实体墙体阻挡高速位移；只用真实物理帧验证 move_and_slide。
	worker = load("res://Worker.tscn").instantiate()
	root.add_child(worker)
	worker.set_physics_process(false)
	var wall := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8, 200)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector2(50, 0)
	root.add_child(wall)
	await physics_frame
	await start_dash(Vector2.RIGHT)
	release_keys()
	for i in 11:
		await tick()
	check(worker.global_position.x > 0 and worker.global_position.x < 37, "Dash cannot penetrate wall")
	worker.set_dialogue_locked(true)
	check(worker._dash_remaining == 0 and worker.velocity == Vector2.ZERO, "Dialogue safely terminates active Dash")
	worker.set_dialogue_locked(false)
	worker._dash_cooldown_remaining = 0.0
	await start_dash(Vector2.LEFT)
	paused = true
	check(worker._dash_remaining == 0 and worker.velocity == Vector2.ZERO and worker.sprite.animation != &"dash", "Pause immediately terminates active Dash")
	paused = false
	release_keys()
	worker.queue_free()
	wall.queue_free()
	await process_frame
	print("Dash motion checks completed: %d failures" % failures)
	quit(1 if failures else 0)
