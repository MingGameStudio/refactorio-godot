extends Sprite2D
## 只为入料口外侧这一格提供取料接口，不扩展地图或人物可行走范围。
@export var port_cell := Vector2i(-1, 4)
@export var cell_size: float = 64.0

func is_port_pickup() -> bool:
	return position.is_equal_approx((Vector2(port_cell) + Vector2.ONE * 0.5) * cell_size)

func pickup_approach() -> Vector2:
	return get_parent().to_global(position + Vector2(cell_size, 0))

func can_pickup_from(worker: Node2D) -> bool:
	var point: Vector2 = get_parent().to_local(worker.global_position)
	var inside := Rect2(Vector2(0, port_cell.y * cell_size), Vector2.ONE * cell_size)
	if not inside.has_point(point) or point.distance_to(position) > cell_size + 8.0:
		return false
	# 只检查车间内部到口沿的遮挡；保留边界碰撞，人物不能走出地图。
	var lip: Vector2 = get_parent().to_global(Vector2(1.0, position.y))
	var ray := PhysicsRayQueryParameters2D.create(worker.global_position, lip, 1)
	ray.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
