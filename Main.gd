extends Node2D

# ============================================================
# 2D 网格工厂原型 — Scene/Node 工作流版本
# 地板/建筑/装饰均为场景节点；物品/悬停由专用 Layer 脚本绘制
# ============================================================

# --- 常量 ---
const COLS: int = 12
const ROWS: int = 8
const CELL: int = 64
const TICK_INTERVAL: float = 0.5

# --- 建筑类型 ---
enum Building { EMPTY, BELT, SOURCE, SINK, INPUT }

# --- 传送带方向 ---
enum Dir { UP, DOWN, LEFT, RIGHT }

# --- 从关卡中的机器节点读取，不再硬编码初始位置 ---
var SOURCE_POS := Vector2i(-1, -1)
var SINK_POS := Vector2i(-1, -1)
const PlacedBuilding = preload("res://PlacedBuilding.gd")
var _source_machine: Node2D
var _input_cell := Vector2i(-1, -1)

# --- 场景节点引用（@onready 在 _ready 之前由引擎赋值） ---
@onready var _worker: Node2D = $Worker
@onready var _box: Sprite2D = $Box
@onready var _building_layer: Node2D = $BuildingLayer
@onready var _deco_layer: Node2D = $DecorationLayer
@onready var _grid_overlay: Node2D = $GridOverlay
@onready var _item_layer: Node2D = $ItemLayer
@onready var _score_label: Label = $UI/ScoreLabel
@onready var _tick_timer: Timer = $TickTimer

# --- 传送带纹理（加载一次，所有传送带节点共享） ---
const _BELT_TEX: Texture2D = preload("res://assets/TransportBelt/Belt.png")
const _BELT_SRC_SIZE: Vector2 = Vector2(451, 289)  # Belt.png 原始宽高
# --- 水平传送带结构件（左端盖 / 中段 / 右端盖）---
const _BELT_LEFT_END_TEX:   Texture2D = preload("res://assets/TransportBelt/TransportLeftEnd.png")
const _BELT_MIDDLE_TEX:    Texture2D = preload("res://assets/TransportBelt/TransportHorizontal.png")
const _BELT_RIGHT_END_TEX: Texture2D = preload("res://assets/TransportBelt/TransportRightEnd.png")
# --- 转弯圆环（BeltRing.png，箭头沿顺时针排列） ---
const _BELT_RING_TEX: Texture2D = preload("res://assets/TransportBelt/BeltRing.png")
const _BELT_CORNER_FRAME_TEX: Texture2D = preload("res://assets/TransportBelt/TransportCorner.png")
# 端盖纹理源尺寸（保持各图自身比例缩放）
const _LEFT_END_SRC_SIZE:   Vector2 = Vector2(449, 343)
const _MIDDLE_SRC_SIZE:     Vector2 = Vector2(425, 333)
const _RIGHT_END_SRC_SIZE:  Vector2 = Vector2(455, 342)
# --- 源头机器 / 终点机器纹理（替换原 ColorRect+Label） ---
const _START_MACHINE_TEX: Texture2D = preload("res://assets/Machines/StartMachine.png")
const _END_MACHINE_TEX:   Texture2D = preload("res://assets/Machines/EndMachine.png")
const _START_MACHINE_SRC_SIZE: Vector2 = Vector2(721, 896)
const _END_MACHINE_SRC_SIZE:   Vector2 = Vector2(707, 895)
# --- 传送带滚动 Shader（所有 belt Sprite 共享同一 material，offset 全局累加） ---
const _BELT_SHADER: Shader = preload("res://belt_scroll.gdshader")
var _belt_material: ShaderMaterial
# --- 转弯圆环 Shader（完整圆环旋转做流动 + 1/4 遮罩形成弯道） ---
const _RING_SHADER: Shader = preload("res://belt_ring.gdshader")
# --- 网格数据 ---
# buildings[x][y] = { type, dir?, node? }  node 为 BuildingLayer 下的可视节点
var buildings: Array = []
const GridOccupancyData = preload("res://GridOccupancy.gd")
var occupancy = GridOccupancyData.new(Vector2i(COLS, ROWS), CELL)
var navigation := AStarGrid2D.new()
const GridDepth = preload("res://GridDepth.gd")
# 每个物品: { pos: Vector2i, prev_pos: Vector2i, progress: float(0..1) }
var items: Array = []

# --- 得分 ---
var score: int = 0

# --- 拖拽铺设状态 ---
# _drag_active=true 期间持续根据鼠标位置更新预览路径
var _drag_active: bool = false
var _press_world := Vector2.ZERO
var _pointer_dragged: bool = false
var _drag_can_build: bool = false
var _drag_start: Vector2i = Vector2i(-1, -1)  # 按下时的格子
var _drag_path: Array = []  # 当前预览路径：元素为 {pos, dir}

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 地板/装饰纹理由场景节点自带，无需运行时加载

	# 修正绘制层级：场景中 BuildingLayer 位于 DecorationLayer 之前，
	# 会导致装饰纹理盖住传送带。把 BuildingLayer 移到 DecorationLayer 之后，
	# 使顺序变为 Floor -> Decoration -> Building -> GridOverlay -> ItemLayer。
	_ensure_layer_order()
	_box.z_index = GridDepth.at_position(to_local(_box.global_position), GridDepth.BOX)

	# 创建共享的传送带滚动材质（所有 belt Sprite 复用同一实例）
	_belt_material = ShaderMaterial.new()
	_belt_material.shader = _BELT_SHADER
	_belt_material.set_shader_parameter("scroll_dir", Vector2(1.0, 0.0))
	_belt_material.set_shader_parameter("scroll_offset", 0.0)
	_belt_material.set_shader_parameter("scroll_speed", 0.6)

	# 初始化逻辑网格 + 初始建筑（装饰位置由用户在编辑器中布置，运行时不改动）
	_grid_overlay.occupancy = occupancy
	occupancy.changed.connect(_grid_overlay.queue_redraw)
	navigation.region = Rect2i(0, 0, COLS, ROWS)
	navigation.cell_size = Vector2.ONE * CELL
	navigation.offset = Vector2.ONE * CELL * 0.5
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	navigation.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	navigation.update()
	_worker.pathfinder = _find_worker_path
	occupancy.changed.connect(_sync_navigation)
	_init_grid()

	# 把 ItemLayer 的 items 共享引用交给它
	_item_layer.items = items
	# 注入终点位置，让物品到达终点时不再绘制（消失在机器里）
	_item_layer.sink_pos = SINK_POS
	_item_layer.position_sampler = _item_draw_position

	# Timer 已是场景节点，连接信号
	_tick_timer.timeout.connect(_on_tick)

# 保证绘制层级顺序：Floor -> Decoration -> Building -> GridOverlay -> ItemLayer
# 场景文件中 BuildingLayer 位于 DecorationLayer 之前，会让装饰纹理盖住传送带，
# 这里在运行时把 BuildingLayer 移到 DecorationLayer 之后（幂等，可重复调用）。
func _ensure_layer_order() -> void:
	var b_idx: int = get_children().find(_building_layer)
	var d_idx: int = get_children().find(_deco_layer)
	if b_idx < 0 or d_idx < 0:
		return
	if b_idx < d_idx:
		# 让 BuildingLayer 紧跟在 DecorationLayer 之后
		move_child(_building_layer, d_idx + 1)

func _init_grid() -> void:
	buildings.clear()
	buildings.resize(COLS)
	for x in COLS:
		var col: Array = []
		col.resize(ROWS)
		for y in ROWS:
			col[y] = { "type": Building.EMPTY }
		buildings[x] = col

	SOURCE_POS = Vector2i(-1, -1)
	SINK_POS = Vector2i(-1, -1)
	_source_machine = null
	_input_cell = Vector2i(-1, -1)
	# 场景节点是初始布局的唯一来源；保留节点及其机器外观。
	for node in _building_layer.get_children():
		if not node is PlacedBuilding:
			continue
		var pos := world_to_cell(node.global_position)
		if not _in_bounds(pos) or buildings[pos.x][pos.y].type != Building.EMPTY:
			push_error("建筑位置越界或重叠：%s" % node.name)
			continue
		var type: int = node.building_type
		buildings[pos.x][pos.y] = {"type": type, "node": node}
		if type == Building.BELT:
			buildings[pos.x][pos.y]["dir"] = node.direction
		else:
			node.z_index = GridDepth.at_row(pos.y)
			if type == Building.SOURCE:
				SOURCE_POS = pos
				_source_machine = node
			elif type == Building.SINK:
				SINK_POS = pos

	if is_instance_valid(_source_machine) and _source_machine.has_node("InputBelt"):
		var input: Node2D = _source_machine.get_node("InputBelt")
		_input_cell = world_to_cell(input.global_position)
		if _in_bounds(_input_cell) and buildings[_input_cell.x][_input_cell.y].type == Building.EMPTY:
			buildings[_input_cell.x][_input_cell.y] = {"type": Building.INPUT, "node": input}
			input.get_node("Surface").material = _belt_material
		else:
			push_error("机器输入带必须位于空闲的地板格上")
			_input_cell = Vector2i(-1, -1)

	# 数据齐备后绑定滚动材质，并按实际邻接关系更新端盖/转角。
	for x in COLS:
		for y in ROWS:
			var b: Dictionary = buildings[x][y]
			if b.type != Building.BELT:
				continue
			var pos := Vector2i(x, y)
			if _corner_info(pos).is_corner:
				# 编辑器改动布局后形成的转角，保留放置节点，仅替换外观。
				for child in b.node.get_children():
					b.node.remove_child(child)
					child.queue_free()
				var info := _corner_info(pos)
				b.node.add_child(_make_corner_ring(info.in_dir, info.out_dir))
			else:
				var surface: Sprite2D = b.node.get_node("Surface")
				var frame: Sprite2D = b.node.get_node("Frame")
				surface.material = _belt_material
				var angle: float = _dir_to_vector(b.dir).angle()
				surface.rotation = angle
				frame.rotation = angle
				frame.texture = _pick_overlay_tex(pos, b.dir)
				frame.scale = Vector2.ONE * (float(CELL) / _overlay_src_size(frame.texture).x)

	_refresh_occupancy()

# 只读取逻辑建筑，避免 queue_free 尚未释放的旧节点重复注册。
# 机器和传送带统一只占放置位置的一格，与图形覆盖范围无关。
func _refresh_occupancy() -> void:
	var footprints: Array = []
	for x in COLS:
		for y in ROWS:
			var b: Dictionary = buildings[x][y]
			if b.type == Building.EMPTY:
				continue
			var anchor := Vector2i(x, y)
			var rect := Rect2(Vector2(anchor) * CELL, Vector2.ONE * CELL)
			footprints.append({"anchor": anchor, "type": b.type, "rect": rect})
	occupancy.rebuild(footprints)

func is_cell_walkable(cell: Vector2i) -> bool:
	return occupancy.is_walkable(cell)

func _sync_navigation() -> void:
	# update() 会清除 solid 状态；这里只更新占用，不重建网格配置。
	for x in COLS:
		for y in ROWS:
			var cell := Vector2i(x, y)
			navigation.set_point_solid(cell, occupancy.is_blocked(cell))
	_worker.repath()

func _find_worker_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	var start := world_to_cell(from_world)
	var finish := world_to_cell(to_world)
	if not occupancy.is_walkable(start) or not occupancy.is_walkable(finish):
		return PackedVector2Array()
	var points := navigation.get_point_path(start, finish)
	if points.is_empty():
		return points
	# 先回到当前格中心，防止途中改目标时斜切障碍角落。
	for i in points.size():
		points[i] = to_global(points[i])
	if start == finish:
		return PackedVector2Array([to_world])
	# 已经位于下一段的水平/垂直线上时可直接前进，避免先退回格心。
	var local_start := to_local(from_world)
	var local_next := to_local(points[1])
	if is_equal_approx(local_start.x, local_next.x) or is_equal_approx(local_start.y, local_next.y):
		points.remove_at(0)
	if not points[-1].is_equal_approx(to_world):
		points.append(to_world)
	return points

# 在 (x,y) 设置建筑并同步创建/更新 BuildingLayer 下的可视节点
# 同时刷新左右邻居 belt 的端盖（运行时单格改动后让端盖重新对齐）
func _set_building(pos: Vector2i, type: int, dir: int = Dir.RIGHT) -> void:
	if not _in_bounds(pos):
		return
	if buildings[pos.x][pos.y].type == Building.INPUT:
		return
	var old: Dictionary = buildings[pos.x][pos.y]
	# 移除旧节点
	if old.has("node") and old["node"] != null:
		var old_node: Node = old["node"]
		old_node.queue_free()
	# 数据
	var entry: Dictionary = { "type": type }
	if type == Building.BELT:
		entry["dir"] = dir
	# 创建可视节点
	var node: CanvasItem = _make_building_node(pos, type, dir if type == Building.BELT else -1)
	_building_layer.add_child(node)
	node.owner = self
	entry["node"] = node
	buildings[pos.x][pos.y] = entry

	# 刷新邻居 belt 的端盖（水平/垂直方向都刷新）
	if type == Building.BELT or old.type == Building.BELT:
		_rebuild_belt_at(pos + Vector2i(-1, 0))
		_rebuild_belt_at(pos + Vector2i(1, 0))
		_rebuild_belt_at(pos + Vector2i(0, -1))
		_rebuild_belt_at(pos + Vector2i(0, 1))
		_rebuild_belt_at(pos)
	_refresh_occupancy()

# 重新创建某格子上的 belt 可视节点（仅在是 BELT 时）
func _rebuild_belt_at(pos: Vector2i) -> void:
	if pos.x < 0 or pos.x >= COLS or pos.y < 0 or pos.y >= ROWS:
		return
	var b: Dictionary = buildings[pos.x][pos.y]
	if b.type != Building.BELT:
		return
	# 移除旧节点
	if b.has("node") and b["node"] != null:
		var old_node: Node = b["node"]
		old_node.queue_free()
	# 重新创建
	var node: CanvasItem = _make_building_node(pos, Building.BELT, b.dir)
	_building_layer.add_child(node)
	node.owner = self
	b["node"] = node

# 根据建筑类型创建对应的纹理节点。
func _make_building_node(pos: Vector2i, type: int, dir: int) -> CanvasItem:
	match type:
		Building.BELT:
			var n := Node2D.new()
			n.position = Vector2(pos.x * CELL, pos.y * CELL)
			n.name = "Belt_%d_%d" % [pos.x, pos.y]
			# --- 转弯格：固定四分之一遮罩，内部纹理流动 ---
			var cinfo: Dictionary = _corner_info(pos)
			if cinfo["is_corner"]:
				n.add_child(_make_corner_ring(cinfo["in_dir"], cinfo["out_dir"]))
				return n
			# --- 直行格：Belt.png 底图 + 端盖/中段结构件 ---
			# 图本身是水平方向（朝右），RIGHT 时不旋转；其他方向按顺时针旋转
			var sprite := Sprite2D.new()
			sprite.texture = _BELT_TEX
			sprite.centered = true
			sprite.position = Vector2(CELL / 2.0, CELL / 2.0)
			# 按比例缩放：长边沿运动方向 = CELL，短边按 289/451 比例
			var scale_along: float = float(CELL) / _BELT_SRC_SIZE.x
			sprite.scale = Vector2(scale_along, scale_along)
			# 旋转角度：Belt.png 原始朝右；RIGHT=0, DOWN=90, LEFT=180, UP=270
			var deg: float = 0.0
			match dir:
				Dir.RIGHT: deg = 0.0
				Dir.DOWN:  deg = 90.0
				Dir.LEFT:  deg = 180.0
				Dir.UP:    deg = 270.0
			sprite.rotation_degrees = deg
			# 挂载共享的滚动 ShaderMaterial（所有 belt 复用同一实例）
			sprite.material = _belt_material
			n.add_child(sprite)
			# 端盖/中段结构件（上层覆盖）：水平段用原图，垂直段旋转 90°/270°
			var overlay_tex: Texture2D = _pick_overlay_tex(pos, dir)
			if overlay_tex != null:
				var overlay := Sprite2D.new()
				overlay.texture = overlay_tex
				overlay.centered = true
				overlay.position = Vector2(CELL / 2.0, CELL / 2.0)
				# 结构件与带面使用相同方向。
				overlay.rotation_degrees = deg
				# 按各自原图比例缩放，使长边接近 CELL（与底层一致）
				var src_size: Vector2 = _overlay_src_size(overlay_tex)
				var s: float = float(CELL) / src_size.x
				overlay.scale = Vector2(s, s)
				n.add_child(overlay)
			return n
		Building.SOURCE:
				var n := Node2D.new()
				n.z_index = GridDepth.at_row(pos.y)
				n.position = Vector2(pos.x * CELL, pos.y * CELL)
				n.name = "Source_%d_%d" % [pos.x, pos.y]
				var sprite := Sprite2D.new()
				sprite.texture = _START_MACHINE_TEX
				sprite.centered = true
				# 向上偏移 15px，让机器与传送带对齐
				sprite.position = Vector2(CELL / 2.0, CELL / 2.0 - 15.0)
				# 保持图像原始比例：高度方向按 1.95×CELL 显示（参考图中机器占约 2 格高）
				var s: float = float(CELL) * 1.95 / _START_MACHINE_SRC_SIZE.y
				sprite.scale = Vector2(s, s)
				n.add_child(sprite)
				return n
		Building.SINK:
				var n := Node2D.new()
				n.z_index = GridDepth.at_row(pos.y)
				n.position = Vector2(pos.x * CELL, pos.y * CELL)
				n.name = "Sink_%d_%d" % [pos.x, pos.y]
				var sprite := Sprite2D.new()
				sprite.texture = _END_MACHINE_TEX
				sprite.centered = true
				# 向上偏移 15px，让机器与传送带对齐
				sprite.position = Vector2(CELL / 2.0, CELL / 2.0 - 15.0)
				var s2: float = float(CELL) * 1.95 / _END_MACHINE_SRC_SIZE.y
				sprite.scale = Vector2(s2, s2)
				n.add_child(sprite)
				return n
	# EMPTY: 返回空 Node2D（不会被调用）
	var n2 := Node2D.new()
	return n2

# 根据 pos 在 belt 链中的位置 + 方向，选择 LeftEnd / Horizontal / RightEnd 纹理
# 水平段（RIGHT/LEFT）检查左右邻居；垂直段（DOWN/UP）检查上下邻居
# 链头（上游侧非 belt）用 LeftEnd，链尾（下游侧非 belt）用 RightEnd，中段用 Horizontal
func _pick_overlay_tex(pos: Vector2i, dir: int) -> Texture2D:
	var is_horizontal: bool = (dir == Dir.RIGHT or dir == Dir.LEFT)
	# "上游"格（链头方向）：RIGHT 看左，LEFT 看右，DOWN 看上，UP 看下
	# "下游"格（链尾方向）：对应相反方向
	var up_belt: bool
	var down_belt: bool
	if is_horizontal:
		if dir == Dir.RIGHT:
			up_belt = pos.x > 0 and buildings[pos.x - 1][pos.y].type == Building.BELT
			down_belt = pos.x < COLS - 1 and buildings[pos.x + 1][pos.y].type == Building.BELT
		else:  # LEFT
			up_belt = pos.x < COLS - 1 and buildings[pos.x + 1][pos.y].type == Building.BELT
			down_belt = pos.x > 0 and buildings[pos.x - 1][pos.y].type == Building.BELT
	else:
		if dir == Dir.DOWN:
			up_belt = pos.y > 0 and buildings[pos.x][pos.y - 1].type == Building.BELT
			down_belt = pos.y < ROWS - 1 and buildings[pos.x][pos.y + 1].type == Building.BELT
		else:  # UP
			up_belt = pos.y < ROWS - 1 and buildings[pos.x][pos.y + 1].type == Building.BELT
			down_belt = pos.y > 0 and buildings[pos.x][pos.y - 1].type == Building.BELT
	# 链头用 LeftEnd，链尾用 RightEnd，中段用 Horizontal
	# 单独一个 belt（上下游都不是）默认当左端
	if not up_belt and not down_belt:
		return _BELT_LEFT_END_TEX
	if not up_belt and down_belt:
		return _BELT_LEFT_END_TEX
	if up_belt and not down_belt:
		return _BELT_RIGHT_END_TEX
	return _BELT_MIDDLE_TEX

# 根据 overlay 纹理返回其原始尺寸，用于保持比例缩放
func _overlay_src_size(tex: Texture2D) -> Vector2:
	if tex == _BELT_LEFT_END_TEX:
		return _LEFT_END_SRC_SIZE
	if tex == _BELT_RIGHT_END_TEX:
		return _RIGHT_END_SRC_SIZE
	return _MIDDLE_SRC_SIZE

# ============================================================
# 转弯判定与圆环
# ============================================================

# 求方向的反向（180°）
# 注意 enum Dir { UP, DOWN, LEFT, RIGHT } 是两两相邻排列，
# 不能用 (d + 2) % 4，必须查表。
func _opposite_dir(dir: int) -> int:
	match dir:
		Dir.UP:    return Dir.DOWN
		Dir.DOWN:  return Dir.UP
		Dir.LEFT:  return Dir.RIGHT
		Dir.RIGHT: return Dir.LEFT
	return dir

# 判断 pos 处的 belt 是否为转弯格
# 返回 {is_corner: bool, in_dir: int, out_dir: int}
# in_dir  = 上游格所在方位（物品从这边进来）
# out_dir = 物品离开该格的方向（即该格 dir）
func _corner_info(pos: Vector2i) -> Dictionary:
	var res := { "is_corner": false, "in_dir": -1, "out_dir": -1 }
	if pos.x < 0 or pos.x >= COLS or pos.y < 0 or pos.y >= ROWS:
		return res
	var b: Dictionary = buildings[pos.x][pos.y]
	if b.type != Building.BELT:
		return res
	var out_dir: int = b.dir
	# 找出真正的上游格：四邻中「dir 指向本格」的 BELT
	# 不能用 pos - dir_offset(out_dir)，因为拐角格的 dir 已转向下游，
	# 上游格在侧面（如 RIGHT->DOWN 拐角，上游在左边）。
	var in_dir: int = -1
	for d in [_opposite_dir(out_dir), Dir.UP, Dir.DOWN, Dir.LEFT, Dir.RIGHT]:
		var nb_pos: Vector2i = pos + _dir_offset(d)
		if not _in_bounds(nb_pos):
			continue
		var nb: Dictionary = buildings[nb_pos.x][nb_pos.y]
		if d != out_dir and ((nb.type == Building.BELT and nb.dir == _opposite_dir(d)) or (nb.type == Building.SOURCE and d == Dir.LEFT)):
			in_dir = d  # 上游格所在方位
			break
	if in_dir < 0:
		# 没有上游（链头），不是转弯
		return res
	res["in_dir"] = in_dir
	res["out_dir"] = out_dir
	# 直行：上游方位与出射方向相反（物品沿同一方向穿过本格）
	# 转弯：两者垂直（方向发生 90° 转折）
	res["is_corner"] = _dir_to_vector(in_dir).dot(_dir_to_vector(out_dir)) == 0
	return res

# 圆心位于入口边和出口边共有的格子角点；中心线半径为半格。
# 遮罩朝向格子内部，角度必须相对于圆心计算，而不是直接使用入口方向。
func _make_corner_ring(in_dir: int, out_dir: int) -> Node2D:
	var ring := Node2D.new()
	ring.name = "CornerRing"
	var incoming := _dir_to_vector(in_dir)
	var outgoing := _dir_to_vector(out_dir)
	var sprite := Sprite2D.new()
	sprite.name = "RingSprite"
	sprite.texture = _BELT_RING_TEX
	sprite.position = Vector2.ONE * CELL * 0.5 + (incoming + outgoing) * CELL * 0.5
	sprite.scale = Vector2.ONE * (2.0 * CELL / _BELT_RING_TEX.get_width())
	var mat := ShaderMaterial.new()
	mat.shader = _RING_SHADER
	mat.set_shader_parameter("mask_direction", -(incoming + outgoing))
	# 屏幕 Y 向下：入口速度与出口速度的叉积为正时顺时针。
	mat.set_shader_parameter("turn_sign", (-incoming).cross(outgoing))
	mat.set_shader_parameter("belt_width", _BELT_SRC_SIZE.y / _BELT_SRC_SIZE.x * 0.5)
	sprite.material = mat
	ring.add_child(sprite)
	# 原图的两个接口朝右、朝下；框架独立于带面材质，保持静止。
	var frame := Sprite2D.new()
	frame.name = "CornerFrame"
	frame.texture = _BELT_CORNER_FRAME_TEX
	# 朝圆心（弯道内侧）微移，缩小外框以改善与直线框架的衔接。
	frame.position = Vector2.ONE * CELL * 0.5 + (incoming + outgoing).normalized() * 2.0
	frame.scale = Vector2.ONE * (float(CELL) * 0.95 / _BELT_CORNER_FRAME_TEX.get_width())
	frame.rotation = Vector2.ONE.angle_to(incoming + outgoing)
	ring.add_child(frame)
	return ring

# 货物的逻辑仍按格子推进；显示位置沿入口到出口的圆弧插值。
func _belt_path_position(pos: Vector2i, progress: float) -> Vector2:
	var center := (Vector2(pos) + Vector2.ONE * 0.5) * CELL
	var info := _corner_info(pos)
	if info.is_corner:
		var incoming := _dir_to_vector(info.in_dir)
		var outgoing := _dir_to_vector(info.out_dir)
		var pivot := center + (incoming + outgoing) * CELL * 0.5
		var radius := -outgoing * CELL * 0.5
		var turn := (-incoming).cross(outgoing)
		return pivot + radius.rotated(turn * PI * 0.5 * progress)
	if _in_bounds(pos) and buildings[pos.x][pos.y].type == Building.BELT:
		return center + _dir_to_vector(buildings[pos.x][pos.y].dir) * CELL * (progress - 0.5)
	return center

func _item_draw_position(item: Dictionary) -> Vector2:
	var previous: Vector2i = item.prev_pos
	var current: Vector2i = item.pos
	var t: float = item.progress
	if previous == current:
		return _belt_path_position(current, 0.5)
	# 两段在共同边界中点衔接，也支持连续弯道。
	var boundary := (Vector2(previous + current) * 0.5 + Vector2.ONE * 0.5) * CELL
	if t < 0.5:
		if _corner_info(previous).is_corner:
			return _belt_path_position(previous, 0.5 + t)
		return _belt_path_position(previous, 0.5).lerp(boundary, t * 2.0)
	if _corner_info(current).is_corner:
		return _belt_path_position(current, t - 0.5)
	return boundary.lerp(_belt_path_position(current, 0.5), (t - 0.5) * 2.0)

# 清除建筑（变为 EMPTY），移除节点
# 清除 belt 时刷新左右邻居的端盖
func _clear_building(pos: Vector2i) -> void:
	if not _in_bounds(pos):
		return
	var old: Dictionary = buildings[pos.x][pos.y]
	if old.type == Building.INPUT:
		return
	if old.type == Building.SOURCE and pos == SOURCE_POS and _in_bounds(_input_cell):
		buildings[_input_cell.x][_input_cell.y] = {"type": Building.EMPTY}
		_input_cell = Vector2i(-1, -1)
		_source_machine = null
	if old.has("node") and old["node"] != null:
		var old_node: Node = old["node"]
		old_node.queue_free()
	buildings[pos.x][pos.y] = { "type": Building.EMPTY }
	_refresh_occupancy()
	if old.type == Building.BELT:
		# 刷新四向邻居的端盖
		_rebuild_belt_at(pos + Vector2i(-1, 0))
		_rebuild_belt_at(pos + Vector2i(1, 0))
		_rebuild_belt_at(pos + Vector2i(0, -1))
		_rebuild_belt_at(pos + Vector2i(0, 1))

# 旋转已有传送带方向（更新数据 + 重建节点）
# 旋转后端盖类型可能改变（水平↔垂直），需重建该格及四向邻居
func _rotate_belt(pos: Vector2i) -> void:
	if not _in_bounds(pos):
		return
	var b: Dictionary = buildings[pos.x][pos.y]
	if b.type != Building.BELT:
		return
	b.dir = _next_dir(b.dir)
	# 旋转不改变传送带的单格占用，无需重新发布占用表。
	# 重建自身 + 四向邻居（端盖可能因方向变化而切换）
	_rebuild_belt_at(pos)
	_rebuild_belt_at(pos + Vector2i(-1, 0))
	_rebuild_belt_at(pos + Vector2i(1, 0))
	_rebuild_belt_at(pos + Vector2i(0, -1))
	_rebuild_belt_at(pos + Vector2i(0, 1))

func _process(delta: float) -> void:
	# 推进所有物品的移动进度 (0..1)
	var step: float = delta / TICK_INTERVAL
	for item in items:
		if item.progress < 1.0:
			item.progress = minf(item.progress + step, 1.0)

	# 推进传送带滚动（取 shader 的 scroll_speed 作为每秒滚动循环数）
	if _belt_material != null:
		var spd: float = _belt_material.get_shader_parameter("scroll_speed")
		var off: float = _belt_material.get_shader_parameter("scroll_offset")
		off = fmod(off + float(spd) * delta, 1.0)
		_belt_material.set_shader_parameter("scroll_offset", off)

	# 更新鼠标悬停（交给 GridOverlay 显示）
	var cell := world_to_cell(get_global_mouse_position())
	_grid_overlay.hover_cell = cell
	_grid_overlay.queue_redraw()

	# 物品层重绘
	_item_layer.queue_redraw()

	# 更新 HUD 文本
	_score_label.text = "得分: %d   物品数: %d" % [score, items.size()]

# ============================================================
# 坐标转换
# ============================================================

func world_to_cell(world_pos: Vector2) -> Vector2i:
	world_pos = to_local(world_pos)
	# 必须用浮点除法后再取整，不能用 int 整除（会提前截断导致偏移）
	var x: int = int(floor(world_pos.x / float(CELL)))
	var y: int = int(floor(world_pos.y / float(CELL)))
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
	return {Dir.RIGHT: Dir.DOWN, Dir.DOWN: Dir.LEFT, Dir.LEFT: Dir.UP, Dir.UP: Dir.RIGHT}[dir]

# ============================================================
# L 形路径计算（水平优先：先水平再垂直）
# ============================================================

# 根据从 from 到 to 的位移向量推断该格的传送带方向
# 用于 L 形路径中每个格子，方向指向"下一个格子"
func _dir_from_offset(off: Vector2i) -> int:
	if off.x > 0:
		return Dir.RIGHT
	if off.x < 0:
		return Dir.LEFT
	if off.y > 0:
		return Dir.DOWN
	if off.y < 0:
		return Dir.UP
	return Dir.RIGHT  # 默认

# 计算 L 形路径：从 start 到 end，先走距离更大的轴，再走另一个轴
# 当两轴距离相等时，用鼠标在当前格内的子格位置（象限）决定先走哪段：
#   往右建造（sx>0）：鼠标在右上半区先水平，左下半区先垂直
#   往左建造（sx<0）：鼠标在左上半区先水平，右下半区先垂直
# mouse_world 为当前鼠标世界坐标（用于象限判定），无意义时传 Vector2.ZERO
# 返回 [{pos, dir}, ...]，dir 指向下一个格子（最后一格沿用倒数第二格方向）
# 若 start==end，返回单格 [{start, Dir.RIGHT}]
func _compute_l_path(start: Vector2i, end: Vector2i, mouse_world: Vector2 = Vector2.ZERO) -> Array:
	var path: Array = []
	if start == end:
		path.append({ "pos": start, "dir": Dir.RIGHT })
		return path
	var cur: Vector2i = start
	var sx: int = sign(end.x - start.x)
	var sy: int = sign(end.y - start.y)
	var dx: int = abs(end.x - start.x)
	var dy: int = abs(end.y - start.y)
	# 距离大的轴先走；相等时用鼠标象限判定
	var go_horizontal_first: bool
	if dx > dy:
		go_horizontal_first = true
	elif dx < dy:
		go_horizontal_first = false
	else:
		# dx == dy：用鼠标在当前格内的子格位置判断
		go_horizontal_first = _mouse_quadrant_horizontal_first(start, end, mouse_world)
	if go_horizontal_first:
		# 水平段
		while cur.x != end.x:
			var nxt: Vector2i = cur + Vector2i(sx, 0)
			path.append({ "pos": cur, "dir": _dir_from_offset(nxt - cur) })
			cur = nxt
		# 垂直段
		while cur.y != end.y:
			var nxt2: Vector2i = cur + Vector2i(0, sy)
			path.append({ "pos": cur, "dir": _dir_from_offset(nxt2 - cur) })
			cur = nxt2
	else:
		# 垂直段
		while cur.y != end.y:
			var nxt: Vector2i = cur + Vector2i(0, sy)
			path.append({ "pos": cur, "dir": _dir_from_offset(nxt - cur) })
			cur = nxt
		# 水平段
		while cur.x != end.x:
			var nxt2: Vector2i = cur + Vector2i(sx, 0)
			path.append({ "pos": cur, "dir": _dir_from_offset(nxt2 - cur) })
			cur = nxt2
	# 终点格：沿用前一段方向（若无前段，默认 RIGHT）
	var last_dir: int = Dir.RIGHT if path.is_empty() else path.back()["dir"]
	path.append({ "pos": end, "dir": last_dir })
	return path

# 当 dx == dy 时，用鼠标在当前格内的子格位置判断先走水平还是垂直
# 当前格指鼠标所在的 end 格（拖拽终点），用其左上角为原点的局部坐标
# 往右建造（sx>0）：右上半区（local_x > local_y）→ 先水平；左下半区 → 先垂直
# 往左建造（sx<0）：左上半区（local_x + local_y < CELL）→ 先水平；右下半区 → 先垂直
# 纯垂直/纯水平（dx==dy 但其中一边为0）不会进入此函数
func _mouse_quadrant_horizontal_first(start: Vector2i, end: Vector2i, mouse_world: Vector2) -> bool:
	var sx: int = sign(end.x - start.x)
	# 鼠标在 end 格内的局部坐标 [0, CELL)
	var local_x: float = mouse_world.x - float(end.x * CELL)
	var local_y: float = mouse_world.y - float(end.y * CELL)
	if sx > 0:
		# 往右：右上半区先水平
		return local_x > local_y
	else:
		# 往左：左上半区先水平
		return local_x + local_y < float(CELL)

# ============================================================
# 鼠标输入
# ============================================================

func _input(event: InputEvent) -> void:
	# 用 get_global_mouse_position() 完成 屏幕 -> 视口 -> 世界 的转换，
	# 在 window/stretch/mode="canvas_items" + aspect="expand" 下也正确对齐格子。
	# 不能直接用 event.position（那是屏幕像素坐标，会导致点击位置偏移）。
	if event is InputEventMouseButton and event.pressed:
		var cell := world_to_cell(get_global_mouse_position())
		if cell.x < 0:
			return
		var b: Dictionary = buildings[cell.x][cell.y]

		if event.button_index == MOUSE_BUTTON_LEFT:
			_press_world = get_global_mouse_position()
			_pointer_dragged = false
			_drag_can_build = b.type not in [Building.SOURCE, Building.SINK, Building.INPUT] and not _box_contains(_press_world)
			_drag_active = true
			_drag_start = cell
			_drag_path = []
			_grid_overlay.preview_path = []
			_grid_overlay.queue_redraw()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 右键：单格删除（拖拽期间也允许）
			if b.type == Building.SOURCE or b.type == Building.SINK:
				return
			if b.type == Building.BELT:
				items = items.filter(func(it): return it.pos != cell)
				_item_layer.items = items
				_clear_building(cell)

	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _drag_active:
			_finish_left_gesture(get_global_mouse_position())

	elif event is InputEventMouseMotion and _drag_active:
		_update_left_gesture(get_global_mouse_position())

# 一旦发生拖动，回到起点也不再作为点击移动处理。
func _update_left_gesture(world: Vector2) -> void:
	var cell := world_to_cell(world)
	if world.distance_to(_press_world) > 8.0 or cell != _drag_start:
		_pointer_dragged = true
	_drag_path = []
	if _drag_can_build and _in_bounds(cell) and cell != _drag_start:
		_drag_path = _compute_l_path(_drag_start, cell, world)
	_grid_overlay.preview_path = _drag_path
	_grid_overlay.queue_redraw()

func _box_contains(world: Vector2) -> bool:
	return _box.visible and _box.get_rect().has_point(_box.to_local(world))

func _finish_left_gesture(world: Vector2) -> void:
	_update_left_gesture(world)
	if _drag_path.size() > 1:
		_place_belt_path(_drag_path)
	elif not _pointer_dragged and _in_bounds(world_to_cell(world)):
		if world_to_cell(world) == _input_cell:
			_request_box_delivery()
		elif _box_contains(world):
			_worker.request_pickup(_box)
		else:
			var cell := world_to_cell(world)
			if is_cell_walkable(cell):
				_worker.move_to(to_global((Vector2(cell) + Vector2.ONE * 0.5) * CELL))
	_drag_active = false
	_drag_start = Vector2i(-1, -1)
	_drag_path = []
	_grid_overlay.preview_path = []
	_grid_overlay.queue_redraw()

# 批量放置传送带路径（跳过源头/终点，覆盖已有 belt）
func _place_belt_path(path: Array) -> void:
	if path.is_empty():
		return
	# --- 第一阶段：只写数据，不建节点 ---
	# 拐角判定依赖上下游的 dir，若边写边建，早建的格子看不到后续数据，
	# 会把拐角误判成直线。所以先让整条路径的数据齐备。
	var touched: Array = []
	for entry in path:
		var pos: Vector2i = entry["pos"]
		var dir: int = entry["dir"]
		if not _in_bounds(pos):
			continue
		var b: Dictionary = buildings[pos.x][pos.y]
		if b.type in [Building.SOURCE, Building.SINK, Building.INPUT]:
			continue  # 不覆盖源头/终点
		var old: Dictionary = buildings[pos.x][pos.y]
		if old.has("node") and old["node"] != null:
			var old_node: Node = old["node"]
			old_node.queue_free()
		buildings[pos.x][pos.y] = { "type": Building.BELT, "dir": dir, "node": null }
		touched.append(pos)

	_refresh_occupancy()
	# --- 第二阶段：数据齐备后，刷新受影响区域（路径本身 + 四邻）的可视节点 ---
	for pos in touched:
		_rebuild_belt_at(pos)
		_rebuild_belt_at(pos + Vector2i(-1, 0))
		_rebuild_belt_at(pos + Vector2i(1, 0))
		_rebuild_belt_at(pos + Vector2i(0, -1))
		_rebuild_belt_at(pos + Vector2i(0, 1))

# ============================================================
# Tick 逻辑
# ============================================================

func _request_box_delivery() -> void:
	if not _worker.carrying_box or not is_instance_valid(_source_machine) or _source_machine.feeding:
		return
	# 只允许从输入带左侧投放；左侧不可达时保留手中的箱子。
	if not is_cell_walkable(_input_cell + Vector2i.LEFT):
		return
	_worker.request_delivery(_source_machine, _source_machine.delivery_position())

func _on_tick() -> void:
	if not _in_bounds(SOURCE_POS) or not _in_bounds(SINK_POS):
		return
	# 1. 源头生成物品（直接放在源头右侧的 belt 格上，避免在源头格凭空出现）
	var source_out_pos: Vector2i = SOURCE_POS + Vector2i(1, 0)
	if is_instance_valid(_source_machine) and _source_machine.has_method("consume_capacity") \
			and _in_bounds(source_out_pos) and buildings[source_out_pos.x][source_out_pos.y].type == Building.BELT \
			and not _has_item_at(source_out_pos) and _source_machine.consume_capacity():
		items.append({ "pos": source_out_pos, "prev_pos": source_out_pos, "progress": 1.0 })

	# 2. 尝试移动所有物品（离终点近的先移动）
	items.sort_custom(func(a, b):
		return _manhattan(a.pos, SINK_POS) < _manhattan(b.pos, SINK_POS))

	var occupied: Dictionary = {}
	for item in items:
		occupied[_key(item.pos)] = true

	var moved: Array = []
	var blocked: Array = []

	for item in items:
		var cur: Vector2i = item.pos
		var b: Dictionary = buildings[cur.x][cur.y]

		if cur == SINK_POS:
			score += 1
			continue

		var dir: int = -1
		if b.type == Building.BELT:
			dir = b.dir
		elif b.type == Building.SOURCE:
			dir = Dir.RIGHT

		if dir >= 0:
			var offset: Vector2i = _dir_offset(dir)
			var next_pos: Vector2i = cur + offset

			if _in_bounds(next_pos):
				if next_pos == SINK_POS and not occupied.has(_key(next_pos)):
					occupied.erase(_key(cur))
					occupied[_key(next_pos)] = true
					item.prev_pos = cur
					item.pos = next_pos
					item.progress = 0.0
					moved.append(item)
					continue

				var nb: Dictionary = buildings[next_pos.x][next_pos.y]
				if (nb.type == Building.BELT or nb.type == Building.EMPTY) and not occupied.has(_key(next_pos)):
					occupied.erase(_key(cur))
					occupied[_key(next_pos)] = true
					item.prev_pos = cur
					item.pos = next_pos
					item.progress = 0.0
					moved.append(item)
					continue

		item.prev_pos = cur
		item.progress = 1.0
		blocked.append(item)

	items = moved + blocked
	# ItemLayer 需要拿到最新数组引用
	_item_layer.items = items
	_item_layer.queue_redraw()

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
