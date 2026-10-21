extends Node2D
# ItemLayer: 绘制运行时的货物（Source.png 纹理），带插值平滑移动
# 由 Main.gd 持有引用，每帧 queue_redraw

const CELL: int = 64

# 货物纹理（流水线上的物品）
const _SOURCE_TEX: Texture2D = preload("res://assets/Source.png")
const _SOURCE_SRC_SIZE: Vector2 = Vector2(133, 266)  # 原始 133×266，瘦长

# 终点位置（由 Main.gd 注入）：物品到达终点时直接不绘制
var sink_pos: Vector2i = Vector2i(-1, -1)

# items 数组由 Main.gd 注入（共享引用），元素: { pos, prev_pos, progress }
var items: Array = []

func _draw() -> void:
	# 货物按高度对齐到 CELL 的一定比例，保持原图瘦长比例
	# Source.png 是 133×266（宽:高 ≈ 1:2），按高度 = CELL * 0.4125 缩放（0.55 × 0.75）
	var scale_h: float = CELL * 0.4125 / _SOURCE_SRC_SIZE.y
	var dw: float = _SOURCE_SRC_SIZE.x * scale_h
	var dh: float = _SOURCE_SRC_SIZE.y * scale_h
	for item in items:
		var cur: Vector2i = item.pos
		# 物品到达终点：直接不绘制，让它"消失在终点机器里"
		if cur == sink_pos:
			continue
		var t: float = item.progress
		var prev: Vector2i = item.prev_pos
		var ix: float = lerp(prev.x, cur.x, t)
		var iy: float = lerp(prev.y, cur.y, t)
		var px: float = (ix + 0.5) * CELL
		var py: float = (iy + 0.5) * CELL
		# 居中绘制
		draw_texture_rect(_SOURCE_TEX, Rect2(px - dw / 2.0, py - dh / 2.0, dw, dh), false)
