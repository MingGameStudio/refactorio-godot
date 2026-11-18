extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	var walls = game.get_node("WorkshopWalls")
	check(walls.get_node("InletApproach").position.y == (game._input_cell.y + 0.5) * game.CELL, "Inlet follows input row")
	check(walls.get_node("OutletApproach").position.y == (game.SINK_POS.y + 0.5) * game.CELL, "Outlet follows shipping row")
	check(walls.get_node("Outlet").flip_h, "Outlet faces the workshop")
	var original_count: int = walls.get_child_count()
	walls.rebuild()
	check(walls.get_child_count() == original_count, "Rebuild is idempotent")
	for dimensions in [Vector2i(12, 8), Vector2i(7, 5), Vector2i(16, 10)]:
		walls.grid_size = dimensions
		var clipped := false
		for node in walls.get_children():
			if not node is Sprite2D:
				continue
			check(is_equal_approx(node.scale.x, node.scale.y), "Every sprite preserves its aspect ratio")
			var rect: Rect2 = node.get_rect()
			var end: Vector2 = node.position + rect.end * node.scale
			check(end.y <= dimensions.y * walls.cell_size + 0.01, "No wall below floor")
			check(not (end.x > 0.01 and node.position.x < dimensions.x * walls.cell_size - 0.01 and end.y > 0.01), "Walls do not cover usable floor")
			if node.region_enabled:
				clipped = true
				check(Rect2(Vector2.ZERO, node.texture.get_size()).encloses(node.region_rect), "Clipped segment stays inside source texture")
		check(clipped, "Non-integral runs use clipping")
	walls.grid_size = Vector2i(12, 8)
	game._fit_camera_to_window()
	await process_frame
	if "--preview" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/workshop-walls-preview.png")
	print("Workshop walls checks; failures=", failures)
	game.free()
	await process_frame
	quit(1 if failures else 0)
