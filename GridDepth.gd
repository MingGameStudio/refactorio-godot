extends RefCounted
## 地面保持默认层级；立体物体按脚底/放置格所在行排序。
## 同行依次为机器、地面箱子、工人（含手持箱子）。
const CELL: int = 64
const BASE: int = 10
const ROW_STEP: int = 4
const MACHINE: int = 0
const BOX: int = 1
const WORKER: int = 2

static func at_row(row: int, order: int = MACHINE) -> int:
	return BASE + row * ROW_STEP + order

static func at_position(floor_position: Vector2, order: int) -> int:
	return at_row(floori(floor_position.y / CELL), order)
