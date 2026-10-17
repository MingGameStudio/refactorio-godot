extends Node2D

# ============================================================
# 2D 网格工厂原型 — 单脚本 (挂载在主 Node2D 上)
# ============================================================

# --- 常量 ---
const COLS: int = 12
const ROWS: int = 8
const CELL: int = 64
const TICK_INTERVAL: float = 0.5

# --- 建筑类型 ---
enum Building { EMPTY, BELT, SOURCE, SINK }

# --- 传送带方向 ---
enum Dir { UP, DOWN, LEFT, RIGHT }

# --- 颜色 ---
const C_BG       := Color(0.12, 0.12, 0.14)
const C_GRID     := Color(0.22, 0.22, 0.26)
const C_GRID_HI  := Color(0.35, 0.35, 0.40)
const C_EMPTY    := Color(0.16, 0.16, 0.18)
const C_BELT     := Color(0.30, 0.30, 0.36)
const C_BELT_HI  := Color(0.45, 0.45, 0.52)
const C_SOURCE   := Color(0.20, 0.60, 0.30)
const C_SINK     := Color(0.60, 0.25, 0.25)
const C_ITEM     := Color(1.0, 0.85, 0.25)
const C_ARROW    := Color(0.85, 0.85, 0.90)

# --- 源头 / 终点坐标 ---
const SOURCE_POS := Vector2i(1, 4)
const SINK_POS   := Vector2i(10, 4)

# --- 网格数据 ---
# buildings[x][y] = { type, dir? }
var buildings: Array = []
# 每个物品: { pos: Vector2i, prev_pos: Vector2i, progress: float(0..1) }
var items: Array = []

# --- 计时器 ---
var _tick_timer: Timer
var _time_accum: float = 0.0

# --- 得分 ---
var score: int = 0

# --- 鼠标高亮 ---
var _hover_cell: Vector2i = Vector2i(-1, -1)

# --- 字体缓存 ---
var _font: Font

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# Node2D 无法调用 get_theme_default_font()，通过临时 Control 获取默认字体
	var tmp := Control.new()
	add_child(tmp)
	_font = tmp.get_theme_default_font()
	tmp.queue_free()

	_init_grid()
	_tick_timer = Timer.new()
	_tick_timer.wait_time = TICK_INTERVAL
	_tick_timer.autostart = true
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)

func _init_grid() -> void:
	buildings.clear()
	buildings.resize(COLS)
	for x in COLS:
		var col: Array = []
		col.resize(ROWS)
		for y in ROWS:
			col[y] = { "type": Building.EMPTY }
		buildings[x] = col

	# 放置源头和终点
	buildings[SOURCE_POS.x][SOURCE_POS.y] = { "type": Building.SOURCE }
	buildings[SINK_POS.x][SINK_POS.y] = { "type": Building.SINK }

	# 放一条初始传送带作为示例（从源头到终点）
	var _initial := [Vector2i(2,4), Vector2i(3,4), Vector2i(4,4), Vector2i(5,4),
					 Vector2i(6,4), Vector2i(7,4), Vector2i(8,4), Vector2i(9,4)]
	for pos in _initial:
		buildings[pos.x][pos.y] = { "type": Building.BELT, "dir": Dir.RIGHT }

func _process(delta: float) -> void:
	# 推进所有物品的移动进度 (0..1)
	var step: float = delta / TICK_INTERVAL
	for item in items:
		if item.progress < 1.0:
			item.progress = minf(item.progress + step, 1.0)

	# 更新鼠标悬停
	var cell := world_to_cell(get_global_mouse_position())
	_hover_cell = cell
	queue_redraw()

func _draw() -> void:
	# 背景
	draw_rect(Rect2(0, 0, COLS * CELL, ROWS * CELL), C_BG, true)

	# 绘制每一格
	for x in COLS:
		for y in ROWS:
			_draw_cell(Vector2i(x, y))

	# 绘制网格线
	for x in range(COLS + 1):
		var col := C_GRID if x % 4 != 0 else C_GRID_HI
		draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, ROWS * CELL), col, 1.0)
	for y in range(ROWS + 1):
		var col := C_GRID if y % 4 != 0 else C_GRID_HI
		draw_line(Vector2(0, y * CELL), Vector2(COLS * CELL, y * CELL), col, 1.0)

	# 高亮悬停格
	if _hover_cell.x >= 0 and _hover_cell.x < COLS and _hover_cell.y >= 0 and _hover_cell.y < ROWS:
		var r := Rect2(_hover_cell.x * CELL, _hover_cell.y * CELL, CELL, CELL)
		draw_rect(r, Color(1, 1, 1, 0.12), true)

	# 绘制物品（插值平滑移动）
	for item in items:
		var t: float = item.progress
		var ix: float = lerp(item.prev_pos.x, item.pos.x, t)
		var iy: float = lerp(item.prev_pos.y, item.pos.y, t)
		var px: float = (ix + 0.5) * CELL
		var py: float = (iy + 0.5) * CELL
		var size: float = CELL * 0.28
		draw_rect(Rect2(px - size / 2.0, py - size / 2.0, size, size), C_ITEM, true)

	# HUD 文本
	draw_string(_get_default_font(), Vector2(8, 20),
		"得分: %d   物品数: %d" % [score, items.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1))
	draw_string(_get_default_font(), Vector2(8, 38),
		"左键: 放置/旋转传送带   右键: 清除",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.7))

func _draw_cell(pos: Vector2i) -> void:
	var x: int = pos.x
	var y: int = pos.y
	var rect := Rect2(x * CELL, y * CELL, CELL, CELL)
	var b: Dictionary = buildings[x][y]

	match b.type:
		Building.EMPTY:
			draw_rect(rect, C_EMPTY, true)

		Building.BELT:
			draw_rect(rect, C_BELT, true)
			# 传送带纹理：沿方向画箭头 + 条纹
			_draw_belt_arrows(pos, b.dir)

		Building.SOURCE:
			draw_rect(rect, C_SOURCE, true)
			_draw_center_label(pos, "S")

		Building.SINK:
			draw_rect(rect, C_SINK, true)
			_draw_center_label(pos, "E")

# 在传送带上绘制方向箭头
func _draw_belt_arrows(pos: Vector2i, dir: int) -> void:
	var cx: float = (pos.x + 0.5) * CELL
	var cy: float = (pos.y + 0.5) * CELL
	var half: float = CELL * 0.35

	# 用条纹表示传送带运动方向
	var dir_vec: Vector2 = _dir_to_vector(dir)
	# 画两条条纹
	for i in [0, 1]:
		var offset: float = (i - 0.5) * CELL * 0.3
		var perp := Vector2(-dir_vec.y, dir_vec.x) * offset
		var p1 := Vector2(cx, cy) - dir_vec * half + perp
		var p2 := Vector2(cx, cy) + dir_vec * half + perp
		draw_line(p1, p2, C_BELT_HI, 2.0)

	# 画箭头头部
	var tip := Vector2(cx, cy) + dir_vec * half
	var base := Vector2(cx, cy) + dir_vec * (half - 12)
	var perp_full := Vector2(-dir_vec.y, dir_vec.x) * 7
	draw_line(base + perp_full, tip, C_ARROW, 2.0)
	draw_line(base - perp_full, tip, C_ARROW, 2.0)

func _draw_center_label(pos: Vector2i, text: String) -> void:
	var cx: float = (pos.x + 0.5) * CELL
	var cy: float = (pos.y + 0.5) * CELL
	draw_string(_get_default_font(), Vector2(cx - 6, cy + 5),
		text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 1, 1, 0.9))

func _get_default_font() -> Font:
	return _font

# ============================================================
# 坐标转换
# ============================================================

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var x: int = int(world_pos.x) / CELL
	var y: int = int(world_pos.y) / CELL
	if x < 0 or x >= COLS or y < 0 or y >= ROWS:
		return Vector2i(-1, -1)
	return Vector2i(x, y)

func _dir_to_vector(dir: int) -> Vector2:
	match dir:
		Dir.UP:    return Vector2(0, -1)
		Dir.DOWN:  return Vector2(0, 1)
		Dir.LEFT:  return Vector2(-1, 0)
		Dir.RIGHT: return Vector2(1, 0)
	return Vector2.ZERO

func _dir_offset(dir: int) -> Vector2i:
	match dir:
		Dir.UP:    return Vector2i(0, -1)
		Dir.DOWN:  return Vector2i(0, 1)
		Dir.LEFT:  return Vector2i(-1, 0)
		Dir.RIGHT: return Vector2i(1, 0)
	return Vector2i.ZERO

func _next_dir(dir: int) -> int:
	# UP -> RIGHT -> DOWN -> LEFT -> UP
	return (dir + 1) % 4

# ============================================================
# 鼠标输入
# ============================================================

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var cell := world_to_cell(event.position)
		if cell.x < 0:
			return
		var b: Dictionary = buildings[cell.x][cell.y]

		if event.button_index == MOUSE_BUTTON_LEFT:
			# 不能在源头/终点上放传送带
			if b.type == Building.SOURCE or b.type == Building.SINK:
				return
			if b.type == Building.BELT:
				# 已是传送带 → 旋转
				b.dir = _next_dir(b.dir)
			else:
				# 空地 → 放传送带 (默认朝右)
				buildings[cell.x][cell.y] = { "type": Building.BELT, "dir": Dir.RIGHT }
			queue_redraw()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 不能清除源头/终点
			if b.type == Building.SOURCE or b.type == Building.SINK:
				return
			if b.type == Building.BELT:
				# 如果格上有物品，也清除
				items = items.filter(func(it): return it.pos != cell)
				buildings[cell.x][cell.y] = { "type": Building.EMPTY }
				queue_redraw()

# ============================================================
# Tick 逻辑
# ============================================================

func _on_tick() -> void:
	# 1. 源头生成物品
	if not _has_item_at(SOURCE_POS):
		items.append({ "pos": SOURCE_POS, "prev_pos": SOURCE_POS, "progress": 1.0 })

	# 2. 尝试移动所有物品（离终点近的先移动，避免连锁阻塞）
	# sort_custom 返回 true 表示 a 排在 b 前面
	# 距离终点越近 → 曼哈顿距离越小 → 越应该先处理
	items.sort_custom(func(a, b):
		return _manhattan(a.pos, SINK_POS) < _manhattan(b.pos, SINK_POS))

	# 记录本 tick 已经移动到的目标格，防止两个物品挤进同一格
	var occupied: Dictionary = {}  # key: "x,y" -> true
	# 初始占用：所有物品当前所在格（还没移动的）
	for item in items:
		occupied[_key(item.pos)] = true

	var moved: Array = []
	var blocked: Array = []

	for item in items:
		var cur: Vector2i = item.pos
		var b: Dictionary = buildings[cur.x][cur.y]

		# 已在终点 → 加分并销毁（上 tick 刚滑入终点，现在清除）
		if cur == SINK_POS:
			score += 1
			continue  # 不加入 moved，即销毁

		# 确定移动方向
		var dir: int = -1
		if b.type == Building.BELT:
			dir = b.dir
		elif b.type == Building.SOURCE:
			# 源头：尝试朝右边移动（默认出口方向）
			dir = Dir.RIGHT

		if dir >= 0:
			var offset: Vector2i = _dir_offset(dir)
			var next_pos: Vector2i = cur + offset

			if _in_bounds(next_pos):
				# 下一格是终点且没有其他物品 → 移动到终点（平滑滑入）
				# 物品会在下一个 tick 的"已在终点"分支中被加分并销毁
				if next_pos == SINK_POS and not occupied.has(_key(next_pos)):
					occupied.erase(_key(cur))
					occupied[_key(next_pos)] = true
					item.prev_pos = cur
					item.pos = next_pos
					item.progress = 0.0
					moved.append(item)
					continue

				# 如果下一格是传送带或空地，且没有物品 → 移动
				var nb: Dictionary = buildings[next_pos.x][next_pos.y]
				if (nb.type == Building.BELT or nb.type == Building.EMPTY) and not occupied.has(_key(next_pos)):
					# 释放当前格占用，占用下一格
					occupied.erase(_key(cur))
					occupied[_key(next_pos)] = true
					# 记录插值起点，重置进度
					item.prev_pos = cur
					item.pos = next_pos
					item.progress = 0.0
					moved.append(item)
					continue

		# 无法移动 → 阻塞 (prev_pos 同步为当前格，进度保持 1)
		item.prev_pos = cur
		item.progress = 1.0
		blocked.append(item)

	# 更新物品列表（moved + blocked）
	items = moved + blocked
	queue_redraw()

func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < COLS and pos.y >= 0 and pos.y < ROWS

func _has_item_at(pos: Vector2i) -> bool:
	for item in items:
		if item.pos == pos:
			return true
	return false

func _key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
