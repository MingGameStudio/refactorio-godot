extends SceneTree

var failures := 0
var game: Node2D
var worker: Node2D

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func center(cell: Vector2i) -> Vector2:
	return game.to_global((Vector2(cell) + Vector2.ONE * 0.5) * game.CELL)

func travel(destination: Vector2) -> void:
	for i in 1500:
		var before := worker.global_position
		worker._physics_process(0.02)
		check(game.is_cell_walkable(game.world_to_cell(worker.global_position)), "Worker stays on walkable floor")
		check(before.distance_to(worker.global_position) <= worker.move_speed * 0.02 + 0.001, "Movement respects speed")
		if worker.global_position.is_equal_approx(destination):
			break
	check(worker.global_position.is_equal_approx(destination), "Worker arrives at destination")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	game.set_process(false)
	worker = game.get_node("Worker")
	worker.set_physics_process(false)
	check(game.navigation is AStarGrid2D, "Native AStarGrid2D is used")
	for x in game.COLS:
		for y in game.ROWS:
			var cell := Vector2i(x, y)
			check(game.navigation.is_point_solid(cell) == game.occupancy.is_blocked(cell), "Navigation matches occupancy")
	var destination := center(Vector2i(5, 5))
	check(worker.move_to(destination), "Route around entire initial machine and belt row exists")
	check(worker._path.size() > 3, "Route detours around the blocked row")
	travel(destination)
	check(worker.sprite.animation == &"idle", "Arrival returns to idle")
	var old_target: Vector2 = worker.target_position
	check(not worker.move_to(center(game.SOURCE_POS)), "Machine destination rejected")
	check(not worker.move_to(Vector2(-32, 32)), "Outside destination rejected")
	check(worker.target_position == old_target, "Invalid commands preserve current target")
	# 开始一条直线路径，在行走途中堵住下一格，应自动绕行。
	worker.global_position = center(Vector2i(5, 1))
	destination = center(Vector2i(8, 1))
	check(worker.move_to(destination), "Initial straight route")
	worker._physics_process(0.1)
	game._set_building(Vector2i(6, 1), game.Building.BELT)
	check(game.navigation.is_point_solid(Vector2i(6, 1)), "Build immediately updates AStar")
	travel(destination)
	game._clear_building(Vector2i(6, 1))
	check(not game.navigation.is_point_solid(Vector2i(6, 1)), "Removal immediately updates AStar")
	# 新障碍占用目的地后停止，不沿旧路线穿透。
	worker.move_to(center(Vector2i(5, 1)))
	worker._physics_process(0.1)
	game._set_building(Vector2i(5, 1), game.Building.BELT)
	var stopped: Vector2 = worker.global_position
	worker._physics_process(10.0)
	check(worker.global_position == stopped, "Blocked destination cancels route safely")
	check(worker.sprite.animation == &"idle", "Cancelled route idles")
	# 目标本身为空地，但四周包围，不应接受不可达目标。
	var enclosed := Vector2i(7, 6)
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		game._set_building(enclosed + offset, game.Building.BELT)
	check(not worker.move_to(center(enclosed)), "Unreachable free cell rejected")
	game._clear_building(enclosed + Vector2i.UP)
	check(worker.move_to(center(enclosed)), "Removing obstacle restores reachability")
	travel(center(enclosed))
	# 点击格内任意位置，最终目标为该格中心。
	var click := center(Vector2i(6, 6)) + Vector2(9, 7)
	game._clear_building(Vector2i(6, 6))
	game._press_world = click
	game._drag_start = game.world_to_cell(click)
	game._drag_active = true
	game._pointer_dragged = false
	game._drag_can_build = true
	game._finish_left_gesture(click)
	check(worker.target_position == center(Vector2i(6, 6)), "Click snaps destination to cell center")
	travel(center(Vector2i(6, 6)))
	game.queue_free()
	await process_frame
	print("Navigation checks completed: %d failures" % failures)
	quit(1 if failures else 0)
