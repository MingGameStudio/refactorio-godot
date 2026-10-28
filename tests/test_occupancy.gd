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
	var data = game.occupancy
	# 两台机器、七格输出传送带和机器附属输入带。
	for x in game.COLS:
		for y in game.ROWS:
			var expected: bool = x >= 1 and x <= 10 and y == 4
			check(data.is_blocked(Vector2i(x, y)) == expected, "Initial footprint %s" % Vector2i(x, y))
	check(data.get_occupied_cells().size() == 10, "Union has 10 occupied cells")
	check(game.is_cell_walkable(Vector2i(2, 7)), "Oil decoration remains walkable")
	check(game.is_cell_walkable(Vector2i(4, 6)), "Warning decoration remains walkable")
	check(not game.is_cell_walkable(Vector2i(-1, 0)), "Outside floor is not walkable")
	check(not game.is_cell_walkable(Vector2i(12, 8)), "Far boundary is not walkable")
	check(game.get_node("GridOverlay").occupancy == data, "Overlay shares authoritative data")
	check(is_equal_approx(game.get_node("GridOverlay").C_OCCUPIED.a, 0.2), "Overlay alpha is 20 percent")
	var p := Vector2i(5, 1)
	game._set_building(p, game.Building.BELT)
	check(data.is_blocked(p), "Single placement updates immediately")
	game._rotate_belt(p)
	check(data.get_occupants(p).size() == 1, "Rotation does not duplicate occupancy")
	game._clear_building(p)
	check(data.is_walkable(p), "Deletion frees the cell before queue_free completes")
	game._place_belt_path(game._compute_l_path(Vector2i(4, 0), Vector2i(6, 2)))
	for cell in [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2)]:
		check(data.is_blocked(cell), "Batch placement including corner %s" % cell)
	game._clear_building(Vector2i(4, 2))
	check(data.is_walkable(Vector2i(4, 2)), "Corner deletion frees only its own cell")
	check(data.is_blocked(Vector2i(4, 1)), "Neighbour remains occupied")
	check(data.get_occupants(Vector2i(3, 4)).size() == 1, "Machine graphic does not occupy neighbouring belt cell")
	game._clear_building(Vector2i(3, 4))
	check(data.is_walkable(Vector2i(3, 4)), "Removing belt frees cell beside machine")
	check(data.is_blocked(game.SOURCE_POS), "Neighbour deletion preserves machine cell")
	game._clear_building(game.SOURCE_POS)
	check(data.is_walkable(game.SOURCE_POS), "Removing machine frees its placement cell")
	game._set_building(Vector2i(0, 0), game.Building.SOURCE)
	check(data.is_blocked(Vector2i(0, 0)), "Edge machine registers on floor")
	check(data.is_walkable(Vector2i(1, 0)), "Machine does not block adjacent floor")
	for cell in data.get_occupied_cells():
		check(data.contains(cell), "Footprints clipped to floor")
	var copy: Array = data.get_occupants(Vector2i(0, 0))
	copy.clear()
	check(data.is_blocked(Vector2i(0, 0)), "Queries cannot mutate source data")
	game.queue_free()
	await process_frame
	print("Occupancy checks completed: %d failures" % failures)
	quit(1 if failures else 0)
