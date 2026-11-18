extends Sprite2D
## 沿用 Worker 的拾取和持箱表现，只为带面上的箱子提供邻格取货接口。
func pickup_approaches() -> Array[Vector2]:
	var game := get_parent()
	var cell: Vector2i = game.world_to_cell(global_position)
	var points: Array[Vector2] = []
	for offset in [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]:
		var adjacent: Vector2i = cell + offset
		if game.is_cell_walkable(adjacent):
			points.append(game.to_global((Vector2(adjacent) + Vector2.ONE * 0.5) * game.CELL))
	return points

func can_pickup_from(worker: Node2D) -> bool:
	var game := get_parent()
	var cell: Vector2i = game.world_to_cell(global_position)
	var worker_cell: Vector2i = game.world_to_cell(worker.global_position)
	var delta := worker_cell - cell
	if absi(delta.x) + absi(delta.y) != 1 or not game.is_cell_walkable(worker_cell):
		return false
	if worker.global_position.distance_to(global_position) > 80.0:
		return false
	# 射线止于带面外缘，不忽略其他设施或地图边界。
	var edge: Vector2 = global_position + Vector2(delta) * (game.CELL * 0.5 + 1.0)
	var ray := PhysicsRayQueryParameters2D.create(worker.global_position, edge, 1)
	ray.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
