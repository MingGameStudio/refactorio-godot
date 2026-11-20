extends Control
## 只读现有状态，不维护生产或交付计数。
@export_range(1, 999, 1) var target_boxes: int = 1
@export var delivered_baseline: int = 0
const DESIGN_SIZE := Vector2(460, 298)

func _ready() -> void:
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	var width := minf(clampf(size.x * 0.30, 300.0, 460.0), minf(size.x - 24.0, size.y * 0.48 * DESIGN_SIZE.x / DESIGN_SIZE.y))
	$Panel.position = Vector2(12, 12)
	$Panel.scale = Vector2.ONE * maxf(width / DESIGN_SIZE.x * 0.70, 0.01)

func bottom_edge() -> float:
	return $Panel.position.y + DESIGN_SIZE.y * $Panel.scale.y

func refresh(game: Node) -> void:
	var target := maxi(target_boxes, 1)
	var delivered := clampi(game.score - delivered_baseline, 0, target)
	var packed := false
	for box in game.packed_boxes:
		if is_instance_valid(box) and not box.is_queued_for_deletion():
			packed = true # 隐藏的手持箱子也属于尚未交付的成品。
			break
	var progress: int = game._packing_machine.battery_count if is_instance_valid(game._packing_machine) else 0
	if packed or delivered == target:
		progress = 5
	progress = clampi(progress, 0, 5)
	$Panel/DeliveryCount.text = "%d/%d" % [delivered, target]
	$Panel/Description.text = "订单已完成" if delivered == target else "生产并交付 %d 箱电池组" % target
	$Panel/PackingTitle.text = "装箱完成" if progress == 5 else "装箱进度"
	$Panel/PackingCount.text = "%d/5" % progress
	for index in 5:
		$Panel/ProgressBar.get_node("Fill%d" % (index + 1)).visible = index < progress
