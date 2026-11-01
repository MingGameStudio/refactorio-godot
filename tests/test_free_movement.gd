extends SceneTree
const PhysicsSteps = preload("res://tests/physics_steps.gd")
var failures := 0
var worker: CharacterBody2D
var game: Node2D

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func release_keys() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)

func drive(direction: Vector2, ticks: int) -> void:
	release_keys()
	if direction.x != 0:
		Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y != 0:
		Input.action_press("move_down" if direction.y > 0 else "move_up")
	for i in ticks:
		await physics_frame
		worker._physics_process(worker.get_physics_process_delta_time())
	release_keys()

func reset_position(point: Vector2) -> void:
	release_keys()
	worker.global_position = point
	worker.cancel_navigation()
	worker.velocity = Vector2.ZERO

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
	game.welding_interaction.set_physics_process(false)
	check(worker.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "Top-down floating motion")
	check(worker.collision_layer == 2 and worker.collision_mask == 1, "Worker uses dedicated physical layers")
	check(not worker.input_pickable and not game.grid_collision._body.input_pickable, "Colliders do not intercept mouse input")
	var up_key: InputEventKey = InputMap.action_get_events("move_up")[0]
	check(up_key.physical_keycode == KEY_W, "Physical W is mapped to upward movement")
	var before_count: int = game.get_welding_machines().size()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	game._input(key)
	check(game.get_welding_machines().size() == before_count, "W no longer places welding machines")
	await physics_frame
	reset_position(Vector2(200, 96))
	await drive(Vector2.RIGHT, 12)
	var horizontal := worker.global_position.distance_to(Vector2(200, 96))
	reset_position(Vector2(200, 96))
	await drive(Vector2(1, 1), 12)
	var diagonal := worker.global_position.distance_to(Vector2(200, 96))
	check(absf(horizontal - diagonal) < 0.1, "Diagonal and axial speeds match")
	var arbitrary := worker.global_position
	await drive(Vector2.ZERO, 3)
	check(worker.global_position == arbitrary and fmod(arbitrary.x, 64.0) != 32.0, "Can stop at arbitrary coordinates without snapping")
	check(worker.sprite.animation == &"idle", "Release returns to idle")
	# 机器/输入带/直线带同样阻挡，碰撞体只占逻辑格。
	for cell in [game.SOURCE_POS, game._input_cell, Vector2i(4, 4), Vector2i(6, 4)]:
		reset_position((Vector2(cell) + Vector2(0.5, -0.5)) * 64.0)
		await drive(Vector2.DOWN, 20)
		check(worker.global_position.y <= cell.y * 64.0 - 9.5, "Facility prevents penetration")
	# 斜向按住墙面时仍可沿平直边缘滑动。
	reset_position(Vector2(224, 246.3))
	await drive(Vector2(1, 1), 12)
	check(worker.global_position.x > 260 and worker.global_position.y < 247, "Slides along obstacle edge")
	reset_position(Vector2(32, 32))
	await drive(Vector2(-1, -1), 20)
	check(worker.global_position.x >= 9.5 and worker.global_position.y >= 9.5, "Map boundary blocks departure")
	# 从任意坐标点击寻路，再用手动输入接管；松手不继续旧路线。
	reset_position(Vector2(201, 101))
	check(worker.move_to(Vector2(480, 224)), "Click path accepts arbitrary starting position")
	await drive(Vector2.RIGHT, 3)
	check(worker._path.is_empty(), "WASD cancels click path")
	var stopped := worker.global_position
	await drive(Vector2.ZERO, 3)
	check(worker.global_position == stopped, "Old path stays cancelled after key release")
	worker.move_to(Vector2(480, 224))
	await PhysicsSteps.advance(worker, 10.0)
	check(worker.global_position.is_equal_approx(Vector2(480, 224)), "Mouse path works again after manual control")
	# 物理碰撞跟随增删，同一轮更新即可用于下一物理步。
	reset_position(Vector2(288, 160))
	game._set_building(Vector2i(5, 2), game.Building.BELT)
	await drive(Vector2.RIGHT, 18)
	check(worker.global_position.x < 311, "New belt immediately blocks movement")
	game._clear_building(Vector2i(5, 2))
	await drive(Vector2.RIGHT, 18)
	check(worker.global_position.x > 350, "Removed belt releases physical space")
	reset_position(Vector2(317, 96))
	game._set_building(Vector2i(5, 1), game.Building.BELT)
	check(game.is_cell_walkable(Vector2i(5, 1)), "Cannot build overlapping worker radius in adjacent cell")
	# 点焊机移动同步旧/新碰撞格。
	var welder = game.get_welding_machines()[0]
	game.move_welder(welder, Vector2i(8, 6))
	check(not game.grid_collision._cells.has(Vector2i(6, 4)) and game.grid_collision._cells.has(Vector2i(8, 6)), "Moving machine moves collision")
	# 手动接管取消待执行拾取；已拿到箱子仍播放持箱行走。
	worker.request_pickup(game.get_node("Box"))
	await drive(Vector2.LEFT, 1)
	check(worker._pickup_target == null and worker._delivery_target == null, "Manual control cancels queued interaction")
	worker.carrying_box = true
	await drive(Vector2.LEFT, 2)
	check(worker.sprite.animation == &"hold_walk" and worker.sprite.flip_h, "Carried walk animation and facing reused")
	await drive(Vector2.ZERO, 1)
	check(worker.sprite.animation == &"hold_idle", "Carried idle restored")
	release_keys()
	game.queue_free()
	await process_frame
	print("Free movement checks completed: %d failures" % failures)
	quit(1 if failures else 0)
