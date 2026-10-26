extends RefCounted
## 统一地板占用表。坐标均为主场景的地板网格坐标；装饰不注册。
signal changed

var size: Vector2i
var cell_size: int
var _cells: Dictionary = {}

func _init(grid_size: Vector2i, grid_cell_size: int) -> void:
	size = grid_size
	cell_size = grid_cell_size

func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y

func is_blocked(cell: Vector2i) -> bool:
	return not contains(cell) or _cells.has(cell)

func is_walkable(cell: Vector2i) -> bool:
	return contains(cell) and not _cells.has(cell)

func get_occupied_cells() -> Array:
	return _cells.keys()

func get_occupants(cell: Vector2i) -> Array:
	return _cells.get(cell, []).duplicate(true)

## 一次提交完整快照；多个建筑覆盖同一格时保存全部来源。
func rebuild(footprints: Array) -> void:
	_cells.clear()
	for footprint in footprints:
		var rect: Rect2 = footprint.rect
		var first := Vector2i(floori(rect.position.x / cell_size), floori(rect.position.y / cell_size))
		var end := Vector2i(ceili(rect.end.x / cell_size), ceili(rect.end.y / cell_size))
		for x in range(maxi(first.x, 0), mini(end.x, size.x)):
			for y in range(maxi(first.y, 0), mini(end.y, size.y)):
				var cell := Vector2i(x, y)
				if not _cells.has(cell):
					_cells[cell] = []
				_cells[cell].append({"anchor": footprint.anchor, "type": footprint.type})
	changed.emit()
