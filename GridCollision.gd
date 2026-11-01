extends Node2D
## 物理碰撞是占用表的镜像，不从图片外框推导。
var _body: StaticBody2D
var _cells: Dictionary = {}
var _tile_shape: RectangleShape2D

func configure(grid_size: Vector2i, cell_size: int) -> void:
	_body = StaticBody2D.new()
	_body.name = "Facilities"
	_body.collision_layer = 1
	_body.collision_mask = 0
	_body.input_pickable = false
	add_child(_body)
	_tile_shape = RectangleShape2D.new()
	_tile_shape.size = Vector2.ONE * cell_size
	var extent := Vector2(grid_size) * cell_size
	for rect in [Rect2(-64, -64, extent.x + 128, 64), Rect2(-64, extent.y, extent.x + 128, 64), Rect2(-64, 0, 64, extent.y), Rect2(extent.x, 0, 64, extent.y)]:
		var boundary := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		boundary.shape = shape
		boundary.position = rect.get_center()
		_body.add_child(boundary)

func sync(occupancy: RefCounted) -> void:
	for cell in _cells.keys():
		if not occupancy.is_blocked(cell):
			var obsolete: CollisionShape2D = _cells[cell]
			_body.remove_child(obsolete) # 立即退出物理世界，不等 queue_free。
			obsolete.queue_free()
			_cells.erase(cell)
	for cell in occupancy.get_occupied_cells():
		if _cells.has(cell):
			continue
		var collider := CollisionShape2D.new()
		collider.shape = _tile_shape
		collider.position = (Vector2(cell) + Vector2.ONE * 0.5) * occupancy.cell_size
		_body.add_child(collider)
		_cells[cell] = collider
