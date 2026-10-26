extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func gesture(game: Node, start: Vector2, finish: Vector2) -> void:
	game._drag_start = game.world_to_cell(start)
	game._press_world = start
	game._drag_active = true
	game._drag_can_build = true
	game._pointer_dragged = false
	game._finish_left_gesture(finish)

func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	var worker = game.get_node("Worker")
	worker.set_physics_process(false)
	assert(worker.sprite.animation == &"idle")
	assert(worker.sprite.is_playing())
	assert(worker.sprite.sprite_frames.get_frame_count(&"idle") >= 1)
	var start: Vector2 = worker.global_position
	var destination := Vector2(480, 224)
	gesture(game, destination, destination)
	assert(worker.target_position == destination)
	assert(game.buildings[7][3].type == game.Building.EMPTY)
	worker._physics_process(0.1)
	assert(worker.global_position.x > start.x)
	assert(worker.sprite.animation == &"walk")
	assert(worker.sprite.is_playing())
	worker._physics_process(10.0)
	assert(worker.global_position == destination)
	assert(worker.sprite.is_playing())
	assert(worker.sprite.animation == &"idle")
	worker.sprite.set_frame_and_progress(0, 0.5)
	worker._physics_process(0.1)
	assert(is_equal_approx(worker.sprite.frame_progress, 0.5)) # 静止时不每帧重置 Idle
	worker.move_to(start)
	assert(worker.sprite.flip_h)
	worker._physics_process(10.0)
	assert(worker.global_position == start)
	var target: Vector2 = worker.target_position
	gesture(game, Vector2(32, 32), Vector2(224, 32))
	assert(worker.target_position == target)
	assert(game.buildings[0][0].type == game.Building.BELT)
	assert(game.buildings[3][0].type == game.Building.BELT)
	gesture(game, Vector2(32, 32), Vector2(32, 32))
	assert(worker.target_position == target) # 点击阻挡格不改变行动。
	assert(game.buildings[0][0].dir == game.Dir.RIGHT)
	# 拖出地图时取消，不能误触人物移动。
	target = worker.target_position
	gesture(game, Vector2(32, 96), Vector2(-20, 96))
	assert(worker.target_position == target)
	var box: Sprite2D = game.get_node("Box")
	var click_position := box.global_position + Vector2(0, -15)
	assert(game._box_contains(click_position))
	gesture(game, click_position, click_position)
	assert(worker.target_position.distance_to(box.global_position) == 32.0)
	assert(not worker.carrying_box)
	assert(box.visible)
	# 到达前重新指定移动目标必须取消拾取。
	worker.move_to(worker.global_position)
	worker._physics_process(0.1)
	assert(not worker.carrying_box and box.visible)
	gesture(game, click_position, click_position)
	worker._physics_process(0.1)
	assert(box.visible)
	worker._physics_process(10.0)
	assert(worker.carrying_box and not box.visible)
	assert(worker.carried_box.visible)
	assert(worker.sprite.animation == &"hold_idle")
	assert(not game._box_contains(click_position))
	worker.move_to(worker.global_position + Vector2(-80, 0))
	worker._physics_process(0.1)
	assert(worker.sprite.animation == &"hold_walk")
	assert(worker.sprite.flip_h and worker.carried_box.position.x < 0)
	worker._physics_process(10.0)
	assert(worker.sprite.animation == &"hold_idle")
	print("Pickup checks passed: click hit, approach, cancel, pickup, carried animations and facing.")
	print("Worker checks passed: click, drag, bounds, movement, facing, arrival, animation.")
	if "--preview" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/worker-preview.png")
	quit()
