extends Node2D
# GridOverlay: 在编辑器和运行时绘制网格线与鼠标悬停高亮
# 由 Main.gd 持有引用并每帧更新 hover_cell，然后 queue_redraw
# 同时承担拖拽铺设预览的绘制（半透明传送带格子 + 方向箭头）

const COLS: int = 12
const ROWS: int = 8
const CELL: int = 64

const C_GRID    := Color(0.22, 0.22, 0.26)
const C_GRID_HI := Color(0.35, 0.35, 0.40)

# 预览颜色（半透明，与 belt 底色同系但更亮以区分）
const C_PREVIEW_FILL := Color(0.40, 0.40, 0.55, 0.45)
const C_PREVIEW_EDGE := Color(0.70, 0.70, 0.85, 0.80)
const C_PREVIEW_ARROW := Color(0.95, 0.95, 1.00, 0.90)

# 方向枚举需与 Main.gd 的 Dir 一致
enum Dir { UP, DOWN, LEFT, RIGHT }

var hover_cell: Vector2i = Vector2i(-1, -1)
# 拖拽预览路径：元素为 {pos: Vector2i, dir: int}，空数组表示无预览
var preview_path: Array = []
var occupancy: RefCounted
@export var show_occupancy: bool = true
const C_OCCUPIED := Color(1.0, 0.0, 0.0, 0.2)

func _draw() -> void:
	if show_occupancy and occupancy != null:
		for cell in occupancy.get_occupied_cells():
			draw_rect(Rect2(Vector2(cell) * CELL, Vector2.ONE * CELL), C_OCCUPIED)
	# 网格线
	for x in range(COLS + 1):
		var col := C_GRID if x % 4 != 0 else C_GRID_HI
		draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, ROWS * CELL), col, 1.0)
	for y in range(ROWS + 1):
		var col := C_GRID if y % 4 != 0 else C_GRID_HI
		draw_line(Vector2(0, y * CELL), Vector2(COLS * CELL, y * CELL), col, 1.0)

	# 拖拽预览路径（半透明填充 + 边框 + 方向箭头）
	if not preview_path.is_empty():
		for entry in preview_path:
			var pos: Vector2i = entry["pos"]
			if pos.x < 0 or pos.x >= COLS or pos.y < 0 or pos.y >= ROWS:
				continue
			var r := Rect2(pos.x * CELL, pos.y * CELL, CELL, CELL)
			draw_rect(r, C_PREVIEW_FILL, true)
			draw_rect(r, C_PREVIEW_EDGE, false, 1.5)
			# 方向箭头
			var dir: int = entry.get("dir", Dir.RIGHT)
			_draw_dir_arrow(pos, dir)

	# 高亮悬停格（仅在非拖拽时显示，避免视觉干扰）
	if not _drag_active_check() and hover_cell.x >= 0 and hover_cell.x < COLS and hover_cell.y >= 0 and hover_cell.y < ROWS:
		var r2 := Rect2(hover_cell.x * CELL, hover_cell.y * CELL, CELL, CELL)
		draw_rect(r2, Color(1, 1, 1, 0.12), true)

# 绘制单格方向箭头（居中，朝 dir 方向）
func _draw_dir_arrow(pos: Vector2i, dir: int) -> void:
	var center := Vector2(pos.x * CELL + CELL / 2.0, pos.y * CELL + CELL / 2.0)
	var half: float = CELL * 0.28
	var vec: Vector2 = _dir_to_vec(dir)
	var tip := center + vec * half
	var base := center - vec * half
	var perp := Vector2(-vec.y, vec.x) * (CELL * 0.16)
	draw_line(base + perp, tip, C_PREVIEW_ARROW, 2.0)
	draw_line(base - perp, tip, C_PREVIEW_ARROW, 2.0)
	draw_line(base + perp, base - perp, C_PREVIEW_ARROW, 2.0)

func _dir_to_vec(d: int) -> Vector2:
	match d:
		Dir.UP:    return Vector2(0, -1)
		Dir.DOWN:  return Vector2(0, 1)
		Dir.LEFT:  return Vector2(-1, 0)
		Dir.RIGHT: return Vector2(1, 0)
	return Vector2.ZERO

# 拖拽期间隐藏普通悬停高亮（避免重复绘制）
func _drag_active_check() -> bool:
	# preview_path 非空即视为拖拽中
	return not preview_path.is_empty()
