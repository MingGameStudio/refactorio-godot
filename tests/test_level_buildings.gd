extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed = load("res://Main.tscn")
	var game = packed.instantiate()
	var layer: Node2D = game.get_node("BuildingLayer")
	check(layer.get_child_count() == 9, "All nine buildings exist before ready")
	var original: Array = layer.get_children()
	var source = layer.get_node("SourceMachine")
	var sink = layer.get_node("SinkMachine")
	check(source.get_child(0).texture != null and sink.get_child(0).texture != null, "Machines have editor-visible textures")
	var belt = layer.get_node("Belt_5_4")
	var surface = belt.get_node("Surface")
	check(surface.texture != null, "Belt is visible without running code")
	root.add_child(game)
	game.get_node("TickTimer").stop()
	check(layer.get_children() == original, "Startup preserves placed nodes without duplicates")
	check(game.buildings[2][4].node == source, "Source registers existing scene node")
	check(game.buildings[5][4].node == belt, "Belt registers existing scene node")
	check(belt.get_node("Surface") == surface, "Startup retains straight belt visuals")
	check(surface.material == game._belt_material, "Existing surface receives scrolling material")
	game._clear_building(Vector2i(5, 4))
	check(game.occupancy.is_walkable(Vector2i(5, 4)), "Scene belt can be removed")
	game._set_building(Vector2i(5, 4), game.Building.BELT)
	check(game.occupancy.is_blocked(Vector2i(5, 4)), "Runtime belt can replace scene belt")
	game.queue_free()
	await process_frame
	# 模拟编辑器改布局：移动机器、删除一格传送带，然后启动。
	game = packed.instantiate()
	layer = game.get_node("BuildingLayer")
	source = layer.get_node("SourceMachine")
	sink = layer.get_node("SinkMachine")
	source.position = Vector2(64, 128)
	sink.position = Vector2(640, 384)
	layer.get_node("Belt_5_4").free()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	check(game.SOURCE_POS == Vector2i(1, 2), "Source position follows editor placement")
	check(game.SINK_POS == Vector2i(10, 6), "Sink position follows editor placement")
	check(game.get_node("ItemLayer").sink_pos == Vector2i(10, 6), "Items use moved sink")
	check(game.occupancy.is_walkable(Vector2i(2, 4)), "Original machine cell stays empty")
	check(game.occupancy.is_blocked(Vector2i(1, 2)), "Moved machine occupies new cell")
	check(game.occupancy.is_walkable(Vector2i(5, 4)), "Deleted scene belt is not recreated")
	check(source.z_index < sink.z_index, "Machine depth follows moved rows")
	game._on_tick()
	check(game.items.is_empty(), "Unfed machine does not produce")
	check(game._input_cell == Vector2i(0, 2), "Input belt follows source placement")
	game.queue_free()
	await process_frame
	print("Level building checks completed: %d failures" % failures)
	quit(1 if failures else 0)
