extends SceneTree

var game: Node2D
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	game.set_process(false)
	for x in game.COLS:
		for y in game.ROWS:
			game._clear_building(Vector2i(x, y))
	var directions := [game.Dir.UP, game.Dir.DOWN, game.Dir.LEFT, game.Dir.RIGHT]
	var index := 0
	for incoming in directions:
		for outgoing in directions:
			var iv: Vector2 = game._dir_to_vector(incoming)
			var ov: Vector2 = game._dir_to_vector(outgoing)
			if iv.dot(ov) != 0:
				continue
			var pos := Vector2i(1 + (index % 4) * 3, 1 + (index / 4) * 4)
			game._place_belt_path([
				{"pos": pos + Vector2i(iv), "dir": game._opposite_dir(incoming)},
				{"pos": pos, "dir": outgoing},
				{"pos": pos + Vector2i(ov), "dir": outgoing},
			])
			var info: Dictionary = game._corner_info(pos)
			check(info.is_corner and info.in_dir == incoming, "Corner classification %d" % index)
			var sprite: Sprite2D = game.buildings[pos.x][pos.y].node.get_node("CornerRing/RingSprite")
			var expected := Vector2.ONE * 32.0 + (iv + ov) * 32.0
			check(sprite.position.is_equal_approx(expected), "Pivot %d" % index)
			var center := (Vector2(pos) + Vector2.ONE * 0.5) * 64.0
			check(game._belt_path_position(pos, 0.0).is_equal_approx(center + iv * 32.0), "Entry %d" % index)
			check(game._belt_path_position(pos, 1.0).is_equal_approx(center + ov * 32.0), "Exit %d" % index)
			var a: Vector2 = game._item_draw_position({"prev_pos": pos + Vector2i(iv), "pos": pos, "progress": 0.49999})
			var b: Vector2 = game._item_draw_position({"prev_pos": pos + Vector2i(iv), "pos": pos, "progress": 0.50001})
			check(a.distance_to(b) < 0.01, "Entry continuity %d" % index)
			a = game._item_draw_position({"prev_pos": pos, "pos": pos + Vector2i(ov), "progress": 0.49999})
			b = game._item_draw_position({"prev_pos": pos, "pos": pos + Vector2i(ov), "progress": 0.50001})
			check(a.distance_to(b) < 0.01, "Exit continuity %d" % index)
			index += 1
	check(index == 8, "All eight directions covered")
	await process_frame
	if "--preview" in OS.get_cmdline_user_args():
		game.get_node("DecorationLayer").hide()
		game.get_node("UI").hide()
		game.get_node("Camera2D").position = Vector2(384, 256)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/corners-preview.png")
	# Face-to-face is not a corner; rotating/deleting must rebuild neighbours.
	var p := Vector2i(5, 3)
	game._place_belt_path([{"pos": p, "dir": game.Dir.RIGHT}, {"pos": p + Vector2i.RIGHT, "dir": game.Dir.LEFT}])
	check(not game._corner_info(p).is_corner, "Face-to-face rejected")
	check(game._next_dir(game.Dir.RIGHT) == game.Dir.DOWN, "Clockwise rotation")
	game._clear_building(p + Vector2i.RIGHT)
	check(not game._corner_info(p).is_corner, "Neighbour deletion")
	game._clear_building(p)
	game._place_belt_path([{"pos": p + Vector2i.LEFT, "dir": game.Dir.RIGHT}, {"pos": p, "dir": game.Dir.DOWN}])
	check(game.buildings[p.x][p.y].node.has_node("CornerRing"), "Corner created")
	game._rotate_belt(p + Vector2i.LEFT)
	check(not game.buildings[p.x][p.y].node.has_node("CornerRing"), "Rotated upstream refreshes corner")
	game._set_building(p + Vector2i.LEFT, game.Building.BELT, game.Dir.RIGHT)
	check(game.buildings[p.x][p.y].node.has_node("CornerRing"), "Restored upstream refreshes corner")
	game._clear_building(p + Vector2i.LEFT)
	check(not game.buildings[p.x][p.y].node.has_node("CornerRing"), "Deleted upstream refreshes corner")
	print("Corner checks: 8 orientations, endpoints, continuity, opposing belts, rotation, deletion; failures=", failures)
	quit(1 if failures else 0)

